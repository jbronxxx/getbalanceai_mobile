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
}

class Unauthenticated extends AuthState {}
