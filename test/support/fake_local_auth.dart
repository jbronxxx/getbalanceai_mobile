import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Системная проверка отпечатка/PIN без платформы: [result] — ответ на
/// следующие проверки (`true`, `false` или исключение).
class FakeLocalAuth extends Fake implements LocalAuthentication {
  FakeLocalAuth({this.supported = true, this.result = true});

  /// На телефоне есть блокировка экрана.
  bool supported;
  Object result;
  int calls = 0;
  String? lastReason;
  bool? lastSensitiveTransaction;
  Iterable<AuthMessages> lastMessages = const [];

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    calls++;
    lastReason = localizedReason;
    lastSensitiveTransaction = sensitiveTransaction;
    lastMessages = authMessages;
    final result = this.result;
    if (result is Exception) throw result;
    return result as bool;
  }
}
