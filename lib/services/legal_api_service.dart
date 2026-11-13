import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/models.dart';

/// Принятие пользовательского соглашения и политики конфиденциальности.
///
/// [status] — последний известный статус документов вошедшего пользователя:
/// приходит с профилем (вход, `GET /auth/me`), обновляется после принятия и
/// по ответу `403 TERMS_NOT_ACCEPTED` на любой запрос. `null` — статус
/// неизвестен (гость, нет сети при запуске): приложение работает как обычно,
/// данные на сервере всё равно закрыты до принятия.
class LegalApiService {
  final Dio _dio;
  final Options Function([String? explicitToken]) _authOptions;

  final ValueNotifier<LegalStatus?> status = ValueNotifier(null);

  LegalApiService({
    required Dio dio,
    required Options Function([String? explicitToken]) authOptions,
  })  : _dio = dio,
        _authOptions = authOptions;

  /// Текущая версия соглашения не принята: показать экран новой версии.
  bool get termsRequired => status.value?.termsAccepted == false;

  /// Соглашение принято, а с новой политикой пользователь не ознакомлен:
  /// показать уведомление (доступ к данным не закрыт).
  bool get privacyNoticePending {
    final value = status.value;
    return value != null && value.termsAccepted && !value.privacyAccepted;
  }

  void update(LegalStatus? value) => status.value = value;

  /// Ответ `403 TERMS_NOT_ACCEPTED`: версия вышла, пока приложение работало.
  void markTermsRequired() {
    if (!termsRequired) status.value = LegalStatus.termsRequired;
  }

  /// Текущие версии и «Что изменилось» на языке [languageCode].
  Future<LegalVersions> fetchVersions(String languageCode) async {
    final response = await _dio.get(
      ApiConfig.legal,
      queryParameters: {'lang': languageCode},
    );
    return LegalVersions.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  /// Принимает показанные версии. Ошибки пробрасываются: `409
  /// LEGAL_VERSION_OUTDATED` — пока экран был открыт, вышла новая версия.
  Future<void> accept({String? termsVersion, String? privacyVersion}) async {
    final response = await _dio.post(
      ApiConfig.legalAccept,
      data: {
        if (termsVersion != null) 'terms_version': termsVersion,
        if (privacyVersion != null) 'privacy_version': privacyVersion,
      },
      options: _authOptions(),
    );
    final legal = response.data['data']['legal'];
    update(LegalStatus.fromJson(legal as Map<String, dynamic>));
  }
}
