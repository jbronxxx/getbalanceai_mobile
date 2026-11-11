import 'package:getbalanceai_mobile/services/speech_input_service.dart';

/// Распознавание речи для тестов: «говорит» то, что задаст тест.
class FakeSpeechRecognizer implements SpeechRecognizer {
  /// Ошибка подготовки (нет доступа к микрофону и т. п.).
  SpeechFailure? prepareFailure;

  /// Частичный текст сразу после начала прослушивания.
  String? partialOnListen;

  /// Итоговая фраза сразу после начала прослушивания.
  String? finalOnListen;

  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  String? localeId;

  void Function(String words, bool isFinal)? _onWords;
  void Function(double level)? _onLevel;
  void Function(SpeechFailure failure)? _onFailure;

  void say(String words, {bool isFinal = false}) => _onWords!(words, isFinal);
  void level(double value) => _onLevel!(value);
  void fail(SpeechFailure failure) => _onFailure!(failure);

  @override
  Future<SpeechFailure?> prepare() async => prepareFailure;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onWords,
    required void Function(double level) onLevel,
    required void Function(SpeechFailure failure) onFailure,
  }) async {
    listenCalls++;
    this.localeId = localeId;
    _onWords = onWords;
    _onLevel = onLevel;
    _onFailure = onFailure;
    if (partialOnListen != null) onWords(partialOnListen!, false);
    if (finalOnListen != null) onWords(finalOnListen!, true);
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;
}
