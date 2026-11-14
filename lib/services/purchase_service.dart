import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../utils/app_logger.dart';

/// Период подписки Pro в пейволле.
enum ProPeriod { month, year }

/// Вариант подписки Pro из магазина: цены и пробный период — из стора через
/// RevenueCat, не из кода.
class ProOption {
  final ProPeriod period;

  /// Цена за период в валюте магазина («€29,99»).
  final String priceString;

  /// Цена за период числом — для скидки годового варианта.
  final double price;

  /// Длительность бесплатного пробного периода в днях; `null` — пробного нет
  /// (уже был на этом аккаунте Google Play или не настроен).
  final int? trialDays;

  /// Пакет RevenueCat для покупки.
  final Object package;

  const ProOption({
    required this.period,
    required this.priceString,
    required this.price,
    required this.package,
    this.trialDays,
  });
}

/// Чем закончилась покупка или восстановление в магазине.
enum StoreOutcome {
  /// Магазин подтвердил покупку или нашёл покупки — статус берётся с сервера.
  completed,

  /// Пользователь закрыл окно оплаты.
  cancelled,

  /// Платёж ждёт подтверждения (оплата наличными, родительский контроль).
  pending,

  /// Подписка этого аккаунта Google Play привязана к другому аккаунту
  /// приложения (режим RevenueCat «оставлять покупку за исходным аккаунтом»).
  otherAccount,

  /// Сеть, магазин или сбой RevenueCat.
  failed,
}

/// Покупки через RevenueCat. Покупатель RevenueCat — id аккаунта бэкенда:
/// [logIn] после входа и при запуске с сессией, [logOut] при выходе. Гость
/// SDK не настраивает.
abstract interface class PurchaseService {
  static PurchaseService instance = RevenueCatPurchaseService();

  /// Ключ RevenueCat задан и платформа поддерживается.
  bool get isAvailable;

  Future<void> logIn(String userId);

  Future<void> logOut();

  /// Месяц и год из текущего предложения RevenueCat; пустой список —
  /// предложения нет.
  Future<List<ProOption>> loadOptions();

  Future<StoreOutcome> purchase(ProOption option);

  Future<StoreOutcome> restore();

  /// Страница управления подписками в магазине.
  Future<Uri> managementUrl();
}

class RevenueCatPurchaseService implements PurchaseService {
  /// Публичный SDK-ключ проекта RevenueCat (`goog_…` или ключ тестового
  /// магазина `test_…`): вшивается в сборку через `--dart-define`.
  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');

  /// Запасная ссылка, если RevenueCat не прислал свою.
  static final _playSubscriptions =
      Uri.parse('https://play.google.com/store/account/subscriptions');

  Future<void>? _configured;
  String? _userId;

  @override
  bool get isAvailable =>
      _apiKey.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> logIn(String userId) async {
    if (!isAvailable || _userId == userId) return;
    try {
      final configured = _configured;
      if (configured == null) {
        _userId = userId;
        await (_configured = Purchases.configure(
            PurchasesConfiguration(_apiKey)..appUserID = userId));
      } else {
        await configured;
        _userId = userId;
        await Purchases.logIn(userId);
      }
    } catch (e) {
      _userId = null;
      AppLogger.w('[Purchases] Не удалось войти в RevenueCat: $e');
    }
  }

  @override
  Future<void> logOut() async {
    final configured = _configured;
    if (configured == null || _userId == null) return;
    _userId = null;
    try {
      await configured;
      if (!await Purchases.isAnonymous) await Purchases.logOut();
    } catch (e) {
      AppLogger.w('[Purchases] Не удалось выйти из RevenueCat: $e');
    }
  }

  /// SDK настроен на вошедшего пользователя; иначе покупки недоступны.
  Future<void> _ready() async {
    final configured = _configured;
    if (configured == null || _userId == null) {
      throw StateError('RevenueCat не настроен');
    }
    await configured;
  }

  @override
  Future<List<ProOption>> loadOptions() async {
    await _ready();
    final offering = (await Purchases.getOfferings()).current;
    if (offering == null) return const [];
    return [
      for (final (period, package) in [
        (ProPeriod.month, offering.monthly),
        (ProPeriod.year, offering.annual),
      ])
        if (package != null) _option(period, package),
    ];
  }

  static ProOption _option(ProPeriod period, Package package) {
    final product = package.storeProduct;
    // Google Play отдаёт бесплатную фазу, только если пробный ещё доступен
    final trial = product.defaultOption?.freePhase?.billingPeriod;
    return ProOption(
      period: period,
      priceString: product.priceString,
      price: product.price,
      trialDays: trial == null ? null : _days(trial),
      package: package,
    );
  }

  static int _days(Period period) => switch (period.unit) {
        PeriodUnit.day => period.value,
        PeriodUnit.week => period.value * 7,
        PeriodUnit.month => period.value * 30,
        PeriodUnit.year => period.value * 365,
        _ => period.value,
      };

  @override
  Future<StoreOutcome> purchase(ProOption option) => _run(() async {
        await _ready();
        await Purchases.purchase(
            PurchaseParams.package(option.package as Package));
      });

  @override
  Future<StoreOutcome> restore() => _run(() async {
        await _ready();
        await Purchases.restorePurchases();
      });

  Future<StoreOutcome> _run(Future<void> Function() action) async {
    try {
      await action();
      return StoreOutcome.completed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      AppLogger.w('[Purchases] Магазин вернул ошибку: $code');
      return switch (code) {
        PurchasesErrorCode.purchaseCancelledError => StoreOutcome.cancelled,
        PurchasesErrorCode.paymentPendingError => StoreOutcome.pending,
        PurchasesErrorCode.receiptAlreadyInUseError ||
        PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
        PurchasesErrorCode.productAlreadyPurchasedError =>
          StoreOutcome.otherAccount,
        _ => StoreOutcome.failed,
      };
    } catch (e) {
      AppLogger.w('[Purchases] Сбой покупки: $e');
      return StoreOutcome.failed;
    }
  }

  @override
  Future<Uri> managementUrl() async {
    try {
      await _ready();
      final url = (await Purchases.getCustomerInfo()).managementURL;
      if (url != null) return Uri.parse(url);
    } catch (e) {
      AppLogger.w('[Purchases] Нет ссылки управления подпиской: $e');
    }
    return _playSubscriptions;
  }
}
