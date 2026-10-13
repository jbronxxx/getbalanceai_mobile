import 'dart:async';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'insights_state.dart';

/// Загружает AI-инсайты и перезагружает их при смене валюты, языка или статуса авторизации.
class InsightsCubit extends Cubit<InsightsState> {
  final ApiService _api;
  final Connectivity _connectivity;
  CancelToken? _cancelToken;
  StreamSubscription<bool>? _authSub;
  bool _hasLoadedOnce = false;

  int _selectedMonth;
  int _selectedYear;

  /// Флаг, указывающий, была ли уже инициирована хотя бы одна загрузка инсайтов.
  bool get hasLoadedOnce => _hasLoadedOnce;

  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  InsightsCubit({
    ApiService? api,
    Connectivity? connectivity,
    int? initialMonth,
    int? initialYear,
  })  : _api = api ?? ApiService.instance,
        _connectivity = connectivity ?? Connectivity(),
        _selectedMonth = initialMonth ?? DateTime.now().month,
        _selectedYear = initialYear ?? DateTime.now().year,
        super(InsightsInitial(
          selectedMonth: initialMonth ?? DateTime.now().month,
          selectedYear: initialYear ?? DateTime.now().year,
        )) {
    CurrencyFormatter.currencyNotifier
        .addListener(_onCurrencyOrLanguageChanged);
    LanguageManager.languageNotifier.addListener(_onCurrencyOrLanguageChanged);
    _authSub = _api.authStream.listen((isAuthenticated) {
      if (isClosed) return;
      if (isAuthenticated) {
        if (_hasLoadedOnce) {
          loadInsights();
        }
      } else {
        _cancelToken?.cancel();
        emit(InsightsUnauthenticated(
          LanguageManager.l10n.insight_login_hint,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
        ));
      }
    });
  }

  void _onCurrencyOrLanguageChanged() {
    if (!_hasLoadedOnce) return;
    loadInsights();
  }

  /// Устанавливает период и перезапускает загрузку аналитики.
  void setPeriod({int? month, int? year}) {
    final newMonth = month ?? _selectedMonth;
    final newYear = year ?? _selectedYear;
    if (newMonth == _selectedMonth && newYear == _selectedYear) return;
    _selectedMonth = newMonth;
    _selectedYear = newYear;
    loadInsights();
  }

  /// Запрашивает инсайты, отменяя предыдущий незавершённый запрос.
  Future<void> loadInsights() async {
    _hasLoadedOnce = true;

    if (!_api.isAuthenticated) {
      emit(InsightsUnauthenticated(
        LanguageManager.l10n.insight_login_hint,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (isClosed) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      emit(InsightsNetworkError(
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
      return;
    }

    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    emit(InsightsLoading(
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
    ));

    try {
      if (LocalDbService.isInitialized &&
          (LocalDbService.instance.getUnsyncedTransactions().isNotEmpty ||
              LocalDbService.instance.getUnsyncedBudgets().isNotEmpty)) {
        try {
          AppLogger.d(
              '[Insights] Syncing local data to backend before loading insights');
          await _api.syncLocalDataToBackend();
        } catch (e, s) {
          AppLogger.w('[Insights] Pre-insights sync failed, continuing', e, s);
        }
      }

      if (isClosed || cancelToken.isCancelled) return;

      AppLogger.d(
          '[Insights] Loading insights for $_selectedMonth/$_selectedYear');
      final data = await _api.getInsights(
        currency: CurrencyFormatter.currentCurrency.code,
        locale: LanguageManager.code,
        month: _selectedMonth,
        year: _selectedYear,
        cancelToken: cancelToken,
      );
      if (isClosed || cancelToken.isCancelled) return;

      final parsed = InsightsModel.fromJson(data);
      emit(InsightsLoaded(
        insights: parsed.insights.isNotEmpty
            ? parsed.insights
            : [LanguageManager.l10n.insight_no_data],
        generatedAt: parsed.generatedAt,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
    } catch (e) {
      if (isClosed || (e is DioException && CancelToken.isCancel(e))) {
        return;
      }
      AppLogger.e('[Insights] Failed to load insights', e);
      emit(InsightsError(
        LanguageManager.l10n.insights_assistants_busy,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
    }
  }

  @override
  Future<void> close() {
    CurrencyFormatter.currencyNotifier
        .removeListener(_onCurrencyOrLanguageChanged);
    LanguageManager.languageNotifier
        .removeListener(_onCurrencyOrLanguageChanged);
    _authSub?.cancel();
    _cancelToken?.cancel();
    return super.close();
  }
}
