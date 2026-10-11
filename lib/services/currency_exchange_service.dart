import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';
import 'preferences_service.dart';

/// Сервис конвертации и актуализации курсов валют.
///
/// Реализует трёхуровневую отказоустойчивость:
/// 1. Приоритетная загрузка свежих котировок с собственного бэкенда [ApiConfig.currencyRates].
/// 2. Graceful Fallback на открытый шлюз https://open.er-api.com/v6/latest/USD при недоступности бэкенда.
/// 3. Локальное кэширование в защищённом хранилище и вшитая оффлайн-таблица средних кросс-курсов.
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

  Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  Dio get dio => _dio;

  @visibleForTesting
  set dio(Dio customDio) => _dio = customDio;

  @visibleForTesting
  void resetForTesting() {
    _ratesToUsd.clear();
    _ratesToUsd.addAll(_fallbackRatesToUsd);
    _lastUpdated = null;
  }

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

  /// Загружает актуальные котировки валют.
  ///
  /// Порядок обращения (Graceful Fallback):
  /// 1. Приоритетно запрашивает котировки с собственного бэкенда: [ApiConfig.currencyRates].
  /// 2. При ошибке или недоступности бэкенда обращается к открытому шлюзу https://open.er-api.com/v6/latest/USD.
  /// 3. В оффлайн-режиме опирается на сохраненный локальный кэш либо встроенную таблицу [_fallbackRatesToUsd].
  Future<bool> fetchLatestRates({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastUpdated != null) {
      final diff = now.difference(_lastUpdated!);
      if (diff.inHours < 12) {
        return true;
      }
    }

    // 1. Приоритетный запрос к собственному бэкенду
    try {
      final backendUrl = '${ApiConfig.baseUrl}${ApiConfig.currencyRates}';
      final response = await _dio.get(backendUrl);

      if (response.statusCode == 200 && response.data is Map) {
        final payload = response.data as Map<String, dynamic>;
        final data = payload['data'] is Map
            ? payload['data'] as Map<String, dynamic>
            : payload;
        final rates =
            data['rates'] is Map ? data['rates'] as Map<String, dynamic> : null;

        if (rates != null && rates.isNotEmpty) {
          for (final currency in Currency.values) {
            final val =
                rates[currency.code] ?? rates[currency.code.toLowerCase()];
            if (val is num) {
              _ratesToUsd[currency.code] = val.toDouble();
            } else if (val is String) {
              final parsed = double.tryParse(val);
              if (parsed != null) _ratesToUsd[currency.code] = parsed;
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
            '[CurrencyExchangeService] Exchange rates successfully updated from backend',
          );
          return true;
        }
      }
    } catch (e) {
      AppLogger.w(
        '[CurrencyExchangeService] Could not refresh rates from backend, falling back to open gateway: $e',
      );
    }

    // 2. Graceful Fallback на открытый внешний шлюз
    try {
      final response = await _dio.get('https://open.er-api.com/v6/latest/USD');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;

        if (rates != null && rates.isNotEmpty) {
          for (final currency in Currency.values) {
            final val = rates[currency.code];
            if (val is num) {
              _ratesToUsd[currency.code] = val.toDouble();
            } else if (val is String) {
              final parsed = double.tryParse(val);
              if (parsed != null) _ratesToUsd[currency.code] = parsed;
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
            '[CurrencyExchangeService] Exchange rates successfully updated from fallback gateway',
          );
          return true;
        }
      }
    } catch (e) {
      AppLogger.w(
        '[CurrencyExchangeService] Could not refresh rates from fallback gateway, using cached/fallback rates: $e',
      );
    }

    // 3. При недоступности сети используется кэш из PreferencesService или _fallbackRatesToUsd
    return false;
  }
}
