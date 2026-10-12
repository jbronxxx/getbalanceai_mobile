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

  InsightsCubit({ApiService? api, Connectivity? connectivity})
      : _api = api ?? ApiService.instance,
        _connectivity = connectivity ?? Connectivity(),
        super(InsightsInitial()) {
    CurrencyFormatter.currencyNotifier.addListener(loadInsights);
    LanguageManager.languageNotifier.addListener(loadInsights);
    _authSub = _api.authStream.listen((isAuthenticated) {
      if (isClosed) return;
      if (isAuthenticated) {
        loadInsights();
      } else {
        _cancelToken?.cancel();
        emit(InsightsUnauthenticated(LanguageManager.l10n.insight_login_hint));
      }
    });
  }

  /// Запрашивает инсайты, отменяя предыдущий незавершённый запрос.
  Future<void> loadInsights() async {
    if (!_api.isAuthenticated) {
      emit(InsightsUnauthenticated(LanguageManager.l10n.insight_login_hint));
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (isClosed) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      emit(InsightsNetworkError());
      return;
    }

    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    emit(InsightsLoading());

    try {
      AppLogger.d('[Insights] Loading insights');
      final data = await _api.getInsights(
        currency: CurrencyFormatter.currentCurrency.code,
        locale: LanguageManager.code,
        cancelToken: cancelToken,
      );
      if (isClosed || cancelToken.isCancelled) return;

      final parsed = InsightsModel.fromJson(data);
      emit(InsightsLoaded(
        insights: parsed.insights.isNotEmpty
            ? parsed.insights
            : [LanguageManager.l10n.insight_no_data],
        generatedAt: parsed.generatedAt,
      ));
    } catch (e) {
      if (isClosed || (e is DioException && CancelToken.isCancel(e))) {
        return;
      }
      AppLogger.e('[Insights] Failed to load insights', e);
      emit(InsightsError(LanguageManager.l10n.insights_assistants_busy));
    }
  }

  @override
  Future<void> close() {
    CurrencyFormatter.currencyNotifier.removeListener(loadInsights);
    LanguageManager.languageNotifier.removeListener(loadInsights);
    _authSub?.cancel();
    _cancelToken?.cancel();
    return super.close();
  }
}
