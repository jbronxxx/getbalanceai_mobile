import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/services/auth_api_service.dart';
import 'package:getbalanceai_mobile/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  final prefs = PreferencesService.instance;

  final session = jsonEncode({'access_token': 'a', 'refresh_token': 'r'});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Перенос настроек из защищённого хранилища', () {
    test('все настройки переезжают, в хранилище остаётся только сессия',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        AuthApiService.sessionStorageKey: session,
        'selected_currency': 'UZS',
        'selected_language': 'uz',
        'onboarding_setup_completed': 'true',
        'settings_theme_mode': 'light',
        'settings_dark_mode': 'false',
        'settings_notifications': 'true',
        'cached_exchange_rates': '{"UZS":12500}',
        'cached_exchange_rates_updated': '1730000000000',
        'ux_hint_sessions_completed': '3',
      });

      await prefs.init();

      expect(await prefs.getCurrency(), 'UZS');
      expect(await prefs.getLanguage(), 'uz');
      expect(await prefs.loadSavedOnboardingStatus(), isTrue);
      expect(await prefs.getThemeMode(), ThemeMode.light);
      expect(await prefs.getExchangeRates(), '{"UZS":12500}');
      expect(await prefs.getExchangeRatesUpdated(), 1730000000000);
      expect(await prefs.shouldShowSwipeHint('dashboard'), isFalse);
      expect(
          (await storage.readAll()).keys, [AuthApiService.sessionStorageKey]);
    });

    for (final (legacy, mode) in [
      ('true', ThemeMode.dark),
      ('false', ThemeMode.light),
    ]) {
      test('прежний флаг тёмной темы $legacy → ${mode.name}', () async {
        FlutterSecureStorage.setMockInitialValues(
            {'settings_dark_mode': legacy});

        await prefs.init();
        await prefs.loadSavedThemeMode();

        expect(prefs.themeModeNotifier.value, mode);
        expect(await storage.readAll(), isEmpty);
      });
    }

    test('выполняется один раз', () async {
      FlutterSecureStorage.setMockInitialValues({'selected_currency': 'UZS'});
      await prefs.init();

      await storage.write(key: 'selected_currency', value: 'KZT');
      await prefs.init();

      expect(await prefs.getCurrency(), 'UZS');
    });

    test('не перезаписывает значение, уже сохранённое в настройках', () async {
      SharedPreferences.setMockInitialValues({'selected_currency': 'KZT'});
      FlutterSecureStorage.setMockInitialValues({'selected_currency': 'UZS'});

      await prefs.init();

      expect(await prefs.getCurrency(), 'KZT');
      expect(await storage.readAll(), isEmpty);
    });

    test('чистая установка: онбординг не пройден', () async {
      await prefs.init();

      expect(await prefs.loadSavedOnboardingStatus(), isFalse);
      expect(await prefs.getThemeMode(), ThemeMode.system);
    });
  });

  group('Онбординг', () {
    test('без отметки считается пройденным, если язык уже выбран', () async {
      SharedPreferences.setMockInitialValues({'selected_language': 'kk'});

      expect(await prefs.loadSavedOnboardingStatus(), isTrue);
    });

    test('отметка сохраняется и читается после перезапуска', () async {
      await prefs.setOnboardingCompleted();

      expect(await prefs.loadSavedOnboardingStatus(), isTrue);
    });
  });

  group('Миграция старых операций', () {
    test('флаг выполнения сохраняется', () async {
      expect(await prefs.isLegacyTransactionsMigrated(), isFalse);

      await prefs.setLegacyTransactionsMigrated();

      expect(await prefs.isLegacyTransactionsMigrated(), isTrue);
    });
  });

  group('Сессия из одного readAll()', () {
    test('AuthApiService восстанавливает сессию и профиль из переданных данных',
        () async {
      final auth = AuthApiService(dio: Dio(), storage: storage);

      await auth.init({
        AuthApiService.sessionStorageKey: session,
        'auth_user_id': 'u1',
        'auth_user': 'Аня',
        'auth_email': 'a@example.com',
        'auth_avatar_url': 'https://example.com/a.png',
      });

      expect(auth.token, 'a');
      expect(auth.refreshToken, 'r');
      expect(auth.userId, 'u1');
      expect(auth.userName, 'Аня');
      expect(auth.email, 'a@example.com');
      expect(auth.avatarUrl, 'https://example.com/a.png');
    });

    test('прежние два ключа токенов переносятся в один', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'auth_token': 'old-a', 'refresh_token': 'old-r'});
      final auth = AuthApiService(dio: Dio(), storage: storage);

      await auth.init(await storage.readAll());

      expect(auth.token, 'old-a');
      expect(auth.refreshToken, 'old-r');
      expect(
          (await storage.readAll()).keys, [AuthApiService.sessionStorageKey]);
    });
  });
}
