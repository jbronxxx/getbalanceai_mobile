part of 'auth_cubit.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class Authenticated extends AuthState {
  final String email;
  final String name;
  final String? avatarUrl;

  Authenticated({
    required this.email,
    required this.name,
    this.avatarUrl,
  });

  /// Вход шлёт несколько событий подряд с теми же данными: равные состояния
  /// [AuthCubit] не эмитит, и подписчики не перестраиваются впустую.
  @override
  bool operator ==(Object other) =>
      other is Authenticated &&
      other.email == email &&
      other.name == name &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(email, name, avatarUrl);
}

class Unauthenticated extends AuthState {}
