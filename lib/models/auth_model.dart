class RegisterModel {
  final String email;

  /// Пароль есть только в запросе на регистрацию: в ответе бэкенд его не
  /// возвращает, поэтому поле nullable — иначе разбор ответа падал бы на
  /// приведении null к String.
  final String? password;
  final String name;

  RegisterModel({
    required this.email,
    this.password,
    required this.name,
  });

  factory RegisterModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    return RegisterModel(
      email: data['email'] as String,
      password: data['password'] as String?,
      name: data['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      if (password != null) 'password': password,
      'name': name,
    };
  }
}

class LoginModel {
  final String email;
  final String password;

  LoginModel({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class LoginResponseModel {
  final String accessToken;
  final String tokenType;
  final String? refreshToken;

  LoginResponseModel({
    required this.accessToken,
    required this.tokenType,
    this.refreshToken,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final data =
        json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    return LoginResponseModel(
      accessToken: (data['access_token'] ?? '') as String,
      tokenType: (data['token_type'] ?? 'bearer') as String,
      refreshToken: data['refresh_token'] as String?,
    );
  }
}

class LogoutResponseModel {
  final String status;
  final String message;

  LogoutResponseModel({
    required this.status,
    required this.message,
  });

  factory LogoutResponseModel.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    final inner = map['data'] is Map ? map['data'] as Map : const {};
    return LogoutResponseModel(
      status: (map['status'] ?? inner['status'] ?? 'success').toString(),
      message: (map['message'] ?? inner['message'] ?? '').toString(),
    );
  }
}

class AuthMeResponseModel {
  final String id;
  final String userEmail;
  final String userName;
  final DateTime? createdAt;
  final String? avatarUrl;
  final String? baseCurrency;

  AuthMeResponseModel({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.createdAt,
    this.avatarUrl,
    this.baseCurrency,
  });

  factory AuthMeResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    return AuthMeResponseModel(
      id: data['id'] as String,
      userEmail: data['email'] as String,
      userName: data['name'] as String,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String).toLocal()
          : null,
      avatarUrl: data['avatar_url'] as String?,
      baseCurrency: data['base_currency'] as String?,
    );
  }
}
