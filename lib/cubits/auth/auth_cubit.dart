import 'package:getbalanceai_mobile/services/services.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final ApiService _apiService;
  StreamSubscription<bool>? _authSubscription;

  AuthCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(AuthInitial()) {
    _init();
  }

  void _init() {
    _updateState(_apiService.isAuthenticated);

    _authSubscription = _apiService.authStream.listen((isAuthenticated) {
      _updateState(isAuthenticated);
    });
  }

  void _updateState(bool isAuthenticated) {
    if (isAuthenticated) {
      emit(Authenticated(
        email: _apiService.email ?? '',
        name: _apiService.userName ?? '',
        avatarUrl: _apiService.avatarUrl,
      ));
    } else {
      emit(Unauthenticated());
    }
  }

  /// Обновить текущее состояние из сервиса авторизации
  void refresh() {
    _updateState(_apiService.isAuthenticated);
  }

  void logout() {
    _apiService.performLogout();
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
