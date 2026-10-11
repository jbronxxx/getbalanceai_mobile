import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';
import 'preferences_service.dart';

/// Сервис конвертации и актуализации курсов валют.
///
/// Реализует трёхуровневую отказоустойчивость:
/// 1. Фоновая загрузка свежих котировок из открытого шлюза курсов валют при наличии сети.
/// 2. Локальное кэширование курсов в защищённом хранилище.
/// 3. Вшитая оффлайн-таблица средних кросс-курсов на случай полного отсутствия сети.
class CurrencyExchangeService {
  CurrencyExchangeService._internal();

  /// Единственный экземпляр сервиса (синглтон).
  static final CurrencyExchangeService instance =
      CurrencyExchangeService._internal();

  /// Вшитая таблица курсов относительно USD (доллара США) на случай первого запуска без сети.
  /// Значение указывает, сколько единиц валюты содержится в 1 USD.
  static const Map<String, double> _fallbackRatesToUsd = {
    'USD': 1.0,
    'EUR': 0.92,
    'RUB': 96.0,
    'UZS': 12800.0,
    'KZT': 495.0,
  };

  /// Текущие актуальные курсы к USD в оперативной памяти.
  final Map<String, double> _ratesToUsd = Map.from(_fallbackRatesToUsd);

  /// Временная метка последнего обновления курсов.
  DateTime? _lastUpdated;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  /// Инициализирует сервис: загружает сохраненные курсы из кэша.
  Future<void> init() async {
    try {
      final cachedJson = await PreferencesService.instance.getExchangeRates();
      final updatedMs =
          await PreferencesService.instance.getExchangeRatesUpdated();

      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is num) {
            _ratesToUsd[entry.key] = (entry.value as num).toDouble();
          }
        }
      }

      if (updatedMs != null) {
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(updatedMs);
      }
    } catch (e, stack) {
      AppLogger.w(
        '[CurrencyExchangeService] Failed to restore cached rates',
        e,
        stack,
      );
    }
  }

  /// Возвращает дату последнего обновления курсов.
  DateTime? get lastUpdated => _lastUpdated;

  /// Рассчитывает кросс-курс конвертации одной единицы валюты [from] в валюту [to].
  ///
  /// Формула пересчета через USD:
  /// rate = rateToUSD(to) / rateToUSD(from)
  double getRate({required Currency from, required Currency to}) {
    if (from == to) return 1.0;

    final fromRate =
        _ratesToUsd[from.code] ?? _fallbackRatesToUsd[from.code] ?? 1.0;
    final toRate = _ratesToUsd[to.code] ?? _fallbackRatesToUsd[to.code] ?? 1.0;

    if (fromRate <= 0) return 1.0;

    return toRate / fromRate;
  }

  /// Конвертирует денежную сумму [amount] из валюты [from] в валюту [to].
  double convert(
    double amount, {
    required Currency from,
    required Currency to,
  }) {
    if (from == to) return amount;
    final rate = getRate(from: from, to: to);
    return amount * rate;
  }

  /// Формирует читаемую строку курса для отображения в интерфейсе.
  /// Например: `1 UZS ≈ 0.0075 ₽` или `1 ₽ ≈ 133.3 сум`.
  String formatRateDescription({
    required Currency from,
    required Currency to,
  }) {
    final rate = getRate(from: from, to: to);
    if (rate >= 1) {
      return '1 ${from.localizedSymbol} ≈ ${rate.toStringAsFixed(2)} ${to.localizedSymbol}';
    } else {
      // Для мелких значений (например, 1 UZS в RUB) выводим больше знаков
      return '1 ${from.localizedSymbol} ≈ ${rate.toStringAsFixed(4)} ${to.localizedSymbol}';
    }
  }

  /// Загружает актуальные курсы валют из открытого API.
  ///
  /// По умолчанию обновляет курсы не чаще 1 раза в 12 часов, если не передан флаг [force].
  Future<bool> fetchLatestRates({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastUpdated != null) {
      final diff = now.difference(_lastUpdated!);
      if (diff.inHours < 12) {
        return true;
      }
    }

    try {
      final response = await _dio.get('https://open.er-api.com/v6/latest/USD');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;

        if (rates != null) {
          for (final currency in Currency.values) {
            final val = rates[currency.code];
            if (val is num) {
              _ratesToUsd[currency.code] = val.toDouble();
            }
          }

          _lastUpdated = now;
          await PreferencesService.instance.saveExchangeRates(
            jsonEncode(_ratesToUsd),
          );
          await PreferencesService.instance.saveExchangeRatesUpdated(
            now.millisecondsSinceEpoch,
          );

          AppLogger.i(
            '[CurrencyExchangeService] Exchange rates successfully updated from network',
          );
          return true;
        }
      }
    } catch (e) {
      AppLogger.w(
        '[CurrencyExchangeService] Could not refresh rates from network, using cache/fallback',
        e,
      );
    }
    return false;
  }
}
