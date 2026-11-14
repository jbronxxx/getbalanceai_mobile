import 'legal_model.dart';
import 'plan_model.dart';

class AuthMeResponseModel {
  final String id;
  final String userEmail;
  final String userName;
  final String? avatarUrl;
  final String? baseCurrency;

  /// Статус соглашения и политики; `null` — сервер его не прислал.
  final LegalStatus? legal;

  /// Тариф и лимиты; `null` — сервер их не прислал (ответ входа).
  final PlanStatus? plan;

  AuthMeResponseModel({
    required this.id,
    required this.userEmail,
    required this.userName,
    this.avatarUrl,
    this.baseCurrency,
    this.legal,
    this.plan,
  });

  factory AuthMeResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    return AuthMeResponseModel(
      id: data['id'] as String,
      userEmail: data['email'] as String,
      userName: data['name'] as String,
      avatarUrl: data['avatar_url'] as String?,
      baseCurrency: data['base_currency'] as String?,
      legal: data['legal'] is Map<String, dynamic>
          ? LegalStatus.fromJson(data['legal'] as Map<String, dynamic>)
          : null,
      plan: PlanStatus.fromProfile(data as Map<String, dynamic>),
    );
  }
}
