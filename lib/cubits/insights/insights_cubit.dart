import 'dart:async';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'insights_state.dart';

/// Загружает AI-отчёт за выбранный месяц.
///
/// Генерация — платный запрос к LLM, поэтому:
/// * будущий месяц и месяц без операций определяются локально — без запроса
///   ([InsightsUnavailable]);
/// * текущий месяц запрашивается с генерацией: бэкенд сам отдаёт сохранённый
///   отчёт, пока данные месяца почти не менялись;
/// * прошлые месяцы и смена валюты/языка — только сохранённый отчёт
///   (`generate=false`); если его нет — [InsightsAwaitingRequest] с кнопкой;
/// * полученные отчёты кэшируются на сессию (очищается при выходе).
class InsightsCubit extends Cubit<InsightsState> {
  final ApiService _api;
  final Connectivity _connectivity;
  CancelToken? _cancelToken;
  StreamSubscription<bool>? _authSub;
  bool _hasLoadedOnce = false;

  /// Отчёты, полученные за сессию: ключ — период, валюта и язык.
  final Map<String, InsightsLoaded> _cache = {};

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
          resolvePeriod();
        }
      } else {
        _cancelToken?.cancel();
        // Отчёты принадлежат вышедшему пользователю.
        _cache.clear();
        emit(InsightsUnauthenticated(
          LanguageManager.l10n.insight_login_hint,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
        ));
      }
    });
  }

  String get _cacheKey => '$_selectedYear-$_selectedMonth-'
      '${CurrencyFormatter.currentCurrency.code}-${LanguageManager.code}';

  MonthPeriod get _period => MonthPeriod(_selectedYear, _selectedMonth);

  bool get _isCurrentMonth => _period == MonthPeriod.current();

  /// Причина, по которой анализировать период нечего, или `null`.
  InsightsUnavailableReason? _unavailableReason() {
    if (_period.isAfter(MonthPeriod.current())) {
      return InsightsUnavailableReason.futureMonth;
    }
    if (LocalDbService.isInitialized &&
        LocalDbService.instance
            .getTransactionsForPeriod(_selectedMonth, _selectedYear, limit: 1)
            .isEmpty) {
      return InsightsUnavailableReason.noTransactions;
    }
    return null;
  }

  /// Валюта или язык сменились: только сохранённые отчёты, без генерации
  /// (событие приходит и при неактивной вкладке).
  void _onCurrencyOrLanguageChanged() {
    if (!_hasLoadedOnce) return;
    resolvePeriod(allowGenerate: false);
  }

  /// Устанавливает период и показывает отчёт за него по правилам класса.
  void setPeriod({int? month, int? year}) {
    final newMonth = month ?? _selectedMonth;
    final newYear = year ?? _selectedYear;
    if (newMonth == _selectedMonth && newYear == _selectedYear) return;
    _selectedMonth = newMonth;
    _selectedYear = newYear;
    resolvePeriod();
  }

  /// Показывает отчёт за выбранный период: генерация разрешена только для
  /// текущего месяца (и если [allowGenerate]).
  Future<void> resolvePeriod({bool allowGenerate = true}) {
    return loadInsights(generate: allowGenerate && _isCurrentMonth);
  }

  /// Запрашивает отчёт, отменяя предыдущий незавершённый запрос.
  ///
  /// [generate] — разрешить генерацию через LLM (кнопка, текущий месяц);
  /// [force] — не брать отчёт из кэша сессии (pull-to-refresh).
  Future<void> loadInsights({bool force = false, bool generate = true}) async {
    _hasLoadedOnce = true;
    _cancelToken?.cancel();

    if (!_api.isAuthenticated) {
      emit(InsightsUnauthenticated(
        LanguageManager.l10n.insight_login_hint,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
      return;
    }

    final unavailable = _unavailableReason();
    if (unavailable != null) {
      emit(InsightsUnavailable(
        unavailable,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
      return;
    }

    final cached = _cache[_cacheKey];
    if (!force && cached != null) {
      emit(cached);
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

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final requestKey = _cacheKey;

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

      AppLogger.d('[Insights] Loading insights for '
          '$_selectedMonth/$_selectedYear (generate: $generate)');
      final data = await _api.getInsights(
        currency: CurrencyFormatter.currentCurrency.code,
        locale: LanguageManager.code,
        month: _selectedMonth,
        year: _selectedYear,
        generate: generate,
        cancelToken: cancelToken,
      );
      if (isClosed || cancelToken.isCancelled) return;

      emit(_stateFromResponse(InsightsModel.fromJson(data), requestKey));
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

  InsightsState _stateFromResponse(InsightsModel parsed, String requestKey) {
    switch (parsed.state) {
      case InsightsReportState.notGenerated:
        return InsightsAwaitingRequest(
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
        );
      case InsightsReportState.noData:
        return InsightsUnavailable(
          InsightsUnavailableReason.noTransactions,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
        );
      case InsightsReportState.ready:
      case InsightsReportState.quotaExceeded:
        final loaded = InsightsLoaded(
          insights: parsed.insights.isNotEmpty
              ? parsed.insights
              : [LanguageManager.l10n.insight_no_data],
          generatedAt: parsed.generatedAt,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
        );
        // Сообщение о квоте — не отчёт: в кэш не кладём.
        if (parsed.state == InsightsReportState.ready &&
            parsed.insights.isNotEmpty) {
          _cache[requestKey] = loaded;
        }
        return loaded;
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
