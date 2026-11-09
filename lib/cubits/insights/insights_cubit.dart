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
/// * будущий месяц и месяц, где операций меньше [minTransactions],
///   определяются локально — без запроса ([InsightsUnavailable]);
/// * текущий месяц запрашивается с генерацией: бэкенд сам отдаёт сохранённый
///   отчёт, пока данные месяца почти не менялись;
/// * прошлые месяцы и смена валюты/языка — только сохранённый отчёт
///   (`generate=false`), в том числе по pull-to-refresh ([refresh]); если
///   его нет — [InsightsAwaitingRequest] с кнопкой;
/// * полученные отчёты кэшируются на сессию (очищается при выходе);
/// * изменение операций или лимитов (в том числе загрузка с сервера при
///   синхронизации) сбрасывает кэш сессии: видимая вкладка сразу
///   запрашивает отчёт заново, скрытая — при следующем открытии. Бэкенд
///   перегенерирует отчёт текущего месяца, а сохранённый устаревший отдаёт
///   с пометкой [InsightsLoaded.isOutdated], чтобы суммы в тексте не
///   выдавались за актуальные.
class InsightsCubit extends Cubit<InsightsState> {
  /// Меньше операций за месяц — советам не на чем строиться, а генерация
  /// тратит суточную квоту. Тот же порог на бэкенде
  /// (`MIN_TRANSACTIONS_FOR_INSIGHTS`).
  static const minTransactions = 7;

  final ApiService _api;
  final Connectivity _connectivity;
  CancelToken? _cancelToken;
  StreamSubscription<bool>? _authSub;
  bool _hasLoadedOnce = false;

  /// Вошёл ли пользователь по последнему событию [ApiService.authStream].
  bool _wasAuthenticated;

  /// Вкладка аналитики видна пользователю ([setActive]).
  bool _isActive = false;

  /// Данные менялись, пока вкладка была скрыта.
  bool _dataChangedWhileHidden = false;

  /// Несколько изменений подряд (сохранение операции и синхронизация) —
  /// один запрос отчёта.
  Timer? _dataChangeDebounce;
  static const _dataChangeDelay = Duration(milliseconds: 400);

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
        _wasAuthenticated = (api ?? ApiService.instance).isAuthenticated,
        super(InsightsInitial(
          selectedMonth: initialMonth ?? DateTime.now().month,
          selectedYear: initialYear ?? DateTime.now().year,
        )) {
    CurrencyFormatter.currencyNotifier
        .addListener(_onCurrencyOrLanguageChanged);
    LanguageManager.languageNotifier.addListener(_onCurrencyOrLanguageChanged);
    LocalDbService.transactionsChanged.addListener(_onDataChanged);
    LocalDbService.budgetsChanged.addListener(_onDataChanged);
    _authSub = _api.authStream.listen(_onAuthChanged);
  }

  /// Вход шлёт в [ApiService.authStream] несколько `true` подряд (токены,
  /// имя, аватар), а каждый запрос текущего месяца может стоить генерации.
  /// Поэтому отчёт запрашивается только на переход «не вошёл» → «вошёл» и
  /// только на видимой вкладке; скрытая запросит его при открытии.
  void _onAuthChanged(bool isAuthenticated) {
    if (isClosed) return;
    final signedIn = isAuthenticated && !_wasAuthenticated;
    _wasAuthenticated = isAuthenticated;

    if (!isAuthenticated) {
      _cancelToken?.cancel();
      // Отчёты принадлежат вышедшему пользователю.
      _cache.clear();
      emit(InsightsUnauthenticated(
        LanguageManager.l10n.insight_login_hint,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      ));
      return;
    }

    if (!signedIn || !_hasLoadedOnce) return;
    if (_isActive) {
      resolvePeriod();
    } else {
      _dataChangedWhileHidden = true;
    }
  }

  String get _cacheKey => '$_selectedYear-$_selectedMonth-'
      '${CurrencyFormatter.currentCurrency.code}-${LanguageManager.code}';

  MonthPeriod get _period => MonthPeriod(_selectedYear, _selectedMonth);

  bool get _isCurrentMonth => _period == MonthPeriod.current();

  /// Состояние «анализировать нечего» для периода или `null`.
  InsightsUnavailable? _unavailableState(int month, int year) {
    InsightsUnavailable unavailable(InsightsUnavailableReason reason) =>
        InsightsUnavailable(
          reason,
          selectedMonth: month,
          selectedYear: year,
        );

    if (_period.isAfter(MonthPeriod.current())) {
      return unavailable(InsightsUnavailableReason.futureMonth);
    }
    if (!LocalDbService.isInitialized) return null;
    final count = LocalDbService.instance
        .getTransactionsForPeriod(month, year, limit: minTransactions)
        .length;
    if (count == 0) {
      return unavailable(InsightsUnavailableReason.noTransactions);
    }
    if (count < minTransactions) {
      return unavailable(InsightsUnavailableReason.notEnoughTransactions);
    }
    return null;
  }

  /// Вкладка аналитики показана или скрыта.
  void setActive(bool active) => _isActive = active;

  /// Данные или аккаунт менялись, пока вкладка была скрыта, — показанный
  /// отчёт нужно запросить заново.
  bool get hasDataChangedWhileHidden => _dataChangedWhileHidden;

  /// Операции или лимиты изменились: отчёты сессии больше не соответствуют
  /// данным.
  void _onDataChanged() {
    _cache.clear();
    if (!_hasLoadedOnce) return;
    if (!_isActive) {
      _dataChangedWhileHidden = true;
      return;
    }
    _dataChangeDebounce?.cancel();
    _dataChangeDebounce = Timer(_dataChangeDelay, () {
      if (!isClosed) resolvePeriod();
    });
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

  /// Pull-to-refresh: запрос мимо кэша сессии по тем же правилам, что и
  /// открытие периода. Прошлый месяц только перечитывает сохранённый отчёт;
  /// генерация за него — лишь по кнопке «Сформировать анализ».
  Future<void> refresh() =>
      loadInsights(force: true, generate: _isCurrentMonth);

  /// Запрашивает отчёт, отменяя предыдущий незавершённый запрос.
  ///
  /// [generate] — разрешить генерацию через LLM (кнопка, текущий месяц);
  /// [force] — не брать отчёт из кэша сессии (pull-to-refresh).
  Future<void> loadInsights({bool force = false, bool generate = true}) async {
    _hasLoadedOnce = true;
    _dataChangedWhileHidden = false;
    _dataChangeDebounce?.cancel();
    _cancelToken?.cancel();

    // Запрос фиксируется до первого await: пока проверяется сеть и
    // выгружаются операции, пользователь может переключить месяц, и
    // генерация не должна уйти (и лечь в кэш) за другой период. Токен
    // создаётся тут же, чтобы следующий вызов отменил и этот запрос.
    final month = _selectedMonth;
    final year = _selectedYear;
    final currency = CurrencyFormatter.currentCurrency.code;
    final locale = LanguageManager.code;
    final requestKey = _cacheKey;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    bool superseded() => isClosed || cancelToken.isCancelled;

    if (!_api.isAuthenticated) {
      emit(InsightsUnauthenticated(
        LanguageManager.l10n.insight_login_hint,
        selectedMonth: month,
        selectedYear: year,
      ));
      return;
    }

    final unavailable = _unavailableState(month, year);
    if (unavailable != null) {
      emit(unavailable);
      return;
    }

    final cached = _cache[requestKey];
    if (!force && cached != null) {
      emit(cached);
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (superseded()) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      emit(InsightsNetworkError(selectedMonth: month, selectedYear: year));
      return;
    }

    emit(InsightsLoading(selectedMonth: month, selectedYear: year));

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

      if (superseded()) return;

      AppLogger.d('[Insights] Loading insights for '
          '$month/$year (generate: $generate)');
      final data = await _api.getInsights(
        currency: currency,
        locale: locale,
        month: month,
        year: year,
        generate: generate,
        cancelToken: cancelToken,
      );
      if (superseded()) return;

      emit(_stateFromResponse(
        InsightsModel.fromJson(data),
        requestKey,
        month: month,
        year: year,
      ));
    } catch (e) {
      if (superseded() || (e is DioException && CancelToken.isCancel(e))) {
        return;
      }
      AppLogger.e('[Insights] Failed to load insights', e);
      emit(_errorState(e, month: month, year: year));
    }
  }

  /// Связь с сервером не установилась — экран «нет сети». Любой другой
  /// сбой (таймаут ответа, 429, 5xx) — «помощники заняты»: сервер на связи,
  /// не справился ИИ или бэкенд. Повтор — pull-to-refresh.
  static InsightsState _errorState(
    Object error, {
    required int month,
    required int year,
  }) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout)) {
      return InsightsNetworkError(selectedMonth: month, selectedYear: year);
    }
    return InsightsError(selectedMonth: month, selectedYear: year);
  }

  InsightsState _stateFromResponse(
    InsightsModel parsed,
    String requestKey, {
    required int month,
    required int year,
  }) {
    switch (parsed.state) {
      case InsightsReportState.notGenerated:
        return InsightsAwaitingRequest(
            selectedMonth: month, selectedYear: year);
      case InsightsReportState.noData:
        return InsightsUnavailable(
          InsightsUnavailableReason.noTransactions,
          selectedMonth: month,
          selectedYear: year,
        );
      case InsightsReportState.notEnoughData:
        // Локально операций хватает, а на сервер дошли не все.
        return InsightsUnavailable(
          InsightsUnavailableReason.notEnoughTransactions,
          selectedMonth: month,
          selectedYear: year,
        );
      case InsightsReportState.busy:
        // Не кэшируется: повторное открытие или pull-to-refresh запросят
        // отчёт снова.
        return InsightsError(
          selectedMonth: month,
          selectedYear: year,
        );
      case InsightsReportState.ready:
      case InsightsReportState.quotaExceeded:
        final loaded = InsightsLoaded(
          insights: parsed.insights.isNotEmpty
              ? parsed.insights
              : [LanguageManager.l10n.insight_no_data],
          generatedAt: parsed.generatedAt,
          isOutdated: parsed.isOutdated,
          canRefresh: parsed.state != InsightsReportState.quotaExceeded,
          selectedMonth: month,
          selectedYear: year,
        );
        // Сообщение о квоте и устаревший отчёт — не актуальный отчёт: в кэш
        // не кладём, следующее открытие спросит бэкенд снова.
        if (parsed.state == InsightsReportState.ready &&
            !parsed.isOutdated &&
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
    LocalDbService.transactionsChanged.removeListener(_onDataChanged);
    LocalDbService.budgetsChanged.removeListener(_onDataChanged);
    _dataChangeDebounce?.cancel();
    _authSub?.cancel();
    _cancelToken?.cancel();
    return super.close();
  }
}
