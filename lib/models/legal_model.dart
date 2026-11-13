/// Статус юридических документов из профиля (`user.legal` в ответах
/// `/auth/*` и `/legal/accept`): текущие версии и приняты ли они.
class LegalStatus {
  final String termsVersion;
  final bool termsAccepted;
  final String privacyVersion;
  final bool privacyAccepted;

  const LegalStatus({
    required this.termsVersion,
    required this.termsAccepted,
    required this.privacyVersion,
    required this.privacyAccepted,
  });

  factory LegalStatus.fromJson(Map<String, dynamic> json) => LegalStatus(
        termsVersion: json['terms_version'] as String,
        termsAccepted: json['terms_accepted'] as bool,
        privacyVersion: json['privacy_version'] as String,
        privacyAccepted: json['privacy_accepted'] as bool,
      );

  /// Сервер ответил `403 TERMS_NOT_ACCEPTED`, а версии неизвестны: экран
  /// новой версии возьмёт их из `GET /legal`.
  static const termsRequired = LegalStatus(
    termsVersion: '',
    termsAccepted: false,
    privacyVersion: '',
    privacyAccepted: true,
  );

  @override
  bool operator ==(Object other) =>
      other is LegalStatus &&
      other.termsVersion == termsVersion &&
      other.termsAccepted == termsAccepted &&
      other.privacyVersion == privacyVersion &&
      other.privacyAccepted == privacyAccepted;

  @override
  int get hashCode =>
      Object.hash(termsVersion, termsAccepted, privacyVersion, privacyAccepted);
}

/// Текущая версия документа и пункты «Что изменилось» на языке интерфейса.
class LegalDocumentInfo {
  final String version;
  final DateTime effectiveDate;
  final List<String> changes;

  const LegalDocumentInfo({
    required this.version,
    required this.effectiveDate,
    required this.changes,
  });

  factory LegalDocumentInfo.fromJson(Map<String, dynamic> json) =>
      LegalDocumentInfo(
        version: json['version'] as String,
        effectiveDate: DateTime.parse(json['effective_date'] as String),
        changes: (json['changes'] as List).cast<String>(),
      );
}

/// Ответ `GET /legal`: текущие версии соглашения и политики.
class LegalVersions {
  final LegalDocumentInfo terms;
  final LegalDocumentInfo privacy;

  const LegalVersions({required this.terms, required this.privacy});

  factory LegalVersions.fromJson(Map<String, dynamic> json) => LegalVersions(
        terms:
            LegalDocumentInfo.fromJson(json['terms'] as Map<String, dynamic>),
        privacy:
            LegalDocumentInfo.fromJson(json['privacy'] as Map<String, dynamic>),
      );
}
