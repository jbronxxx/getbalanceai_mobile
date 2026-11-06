import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Выполняется перед каждым тестовым файлом.
///
/// Настройки (язык, валюта, тема) хранятся в `shared_preferences`: без мока
/// любой тест, меняющий язык или валюту, упал бы на отсутствующем плагине.
/// Тесты со своими значениями вызывают `setMockInitialValues` сами.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
