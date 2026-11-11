import 'dart:ui';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/app_logger.dart';

/// Почему распознавание речи не дало текста.
enum SpeechFailure {
  /// Пользователь не дал доступ к микрофону.
  permissionDenied,

  /// На телефоне нет сервиса распознавания речи.
  unavailable,

  /// Речь не услышана или не разобрана.
  nothingHeard,

  /// Сбой сервиса распознавания (часто — нет интернета).
  failed,
}

/// Распознавание речи на телефоне: интерфейс, чтобы подменять его в тестах.
abstract interface class SpeechRecognizer {
  /// Готовит распознавание; при первом вызове система спрашивает доступ к
  /// микрофону. `null` — можно слушать.
  Future<SpeechFailure?> prepare();

  /// Слушает фразу на языке [localeId] (`ru_RU`, `en_US`). [onWords] —
  /// распознанный текст по ходу речи и в конце (`isFinal`); [onLevel] —
  /// громкость 0…1; [onFailure] — ошибка вместо итогового текста.
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onWords,
    required void Function(double level) onLevel,
    required void Function(SpeechFailure failure) onFailure,
  });

  /// Заканчивает слушать: итоговый текст придёт в `onWords`.
  Future<void> stop();

  /// Прерывает распознавание без результата.
  Future<void> cancel();
}

/// Точка доступа к распознаванию речи; в тестах подменяется фейком.
abstract final class SpeechInput {
  static SpeechRecognizer recognizer = DeviceSpeechRecognizer();

  /// Локаль распознавания для языка интерфейса [languageCode]: страна —
  /// из системной локали, если язык совпадает (en_GB, а не en_US), иначе —
  /// основная страна языка.
  static String localeIdFor(String languageCode, {Locale? systemLocale}) {
    final system = systemLocale ?? PlatformDispatcher.instance.locale;
    final country = system.languageCode == languageCode &&
            (system.countryCode?.isNotEmpty ?? false)
        ? system.countryCode!
        : _defaultCountries[languageCode] ?? 'US';
    return '${languageCode}_$country';
  }

  static const _defaultCountries = {'ru': 'RU', 'en': 'US'};
}

/// [SpeechRecognizer] на системном сервисе распознавания (`speech_to_text`).
class DeviceSpeechRecognizer implements SpeechRecognizer {
  final SpeechToText _speech = SpeechToText();

  /// Пауза в речи, после которой фраза считается законченной.
  static const pauseFor = Duration(seconds: 3);

  /// Самая длинная фраза.
  static const listenFor = Duration(seconds: 30);

  void Function(SpeechFailure failure)? _onFailure;

  @override
  Future<SpeechFailure?> prepare() async {
    try {
      final ready = await _speech.initialize(
        onError: _handleError,
        // Bluetooth-гарнитуры не нужны: без них нет запроса прав на Bluetooth
        options: [SpeechToText.androidNoBluetooth],
      );
      if (ready) return null;
      return await _speech.hasPermission
          ? SpeechFailure.unavailable
          : SpeechFailure.permissionDenied;
    } catch (e, s) {
      AppLogger.w('[Speech] Initialize failed', e, s);
      return SpeechFailure.unavailable;
    }
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onWords,
    required void Function(double level) onLevel,
    required void Function(SpeechFailure failure) onFailure,
  }) async {
    _onFailure = onFailure;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) =>
            onWords(result.recognizedWords, result.finalResult),
        // Громкость на Android — примерно от −2 до 10 дБ
        onSoundLevelChange: (level) =>
            onLevel(((level + 2) / 12).clamp(0.0, 1.0)),
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e, s) {
      AppLogger.w('[Speech] Listen failed', e, s);
      onFailure(SpeechFailure.failed);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    // Текст ошибки — код сервиса, без слов пользователя
    AppLogger.w('[Speech] ${error.errorMsg}');
    if (!error.permanent) return;
    _onFailure?.call(switch (error.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => SpeechFailure.nothingHeard,
      'error_permission' => SpeechFailure.permissionDenied,
      'error_language_not_supported' ||
      'error_language_unavailable' =>
        SpeechFailure.unavailable,
      _ => SpeechFailure.failed,
    });
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    _onFailure = null;
    await _speech.cancel();
  }
}
