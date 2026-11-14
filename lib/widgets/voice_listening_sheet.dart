import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../services/speech_input_service.dart';
import '../theme/app_colors.dart';
import '../utils/utils.dart';
import 'ai_sparkles_loader.dart';
import 'insights/insight_card.dart';
import 'app_sheet.dart';
import 'sheet_buttons.dart';
import 'whole_words_text.dart';

/// Разбор фразы на черновики записей (по умолчанию — запрос к серверу).
typedef VoicePhraseParser = Future<List<Transaction>> Function(String phrase);

/// Итог голосового ввода: услышанная фраза и черновики записей из неё.
class VoiceInputResult {
  final String phrase;
  final List<Transaction> drafts;

  const VoiceInputResult({required this.phrase, required this.drafts});
}

enum _Phase { listening, parsing, error }

/// Шторка голосового ввода: «Говорите» с примером, распознанный текст
/// вживую и индикатор громкости; после паузы в речи или «Готово» —
/// «Разбираю фразу…». Ошибки показываются в самой шторке, с «Сказать ещё
/// раз», где повтор имеет смысл. Возвращает [VoiceInputResult] с хотя бы
/// одним черновиком или `null`, если шторку закрыли.
class VoiceListeningSheet extends StatefulWidget {
  final VoicePhraseParser? parse;

  /// Лимит голоса на Free исчерпан (`403 PLAN_LIMIT_REACHED`): шторка
  /// закрывается, и вызывается он с корневым навигатором (пейволл). Без него
  /// и на Pro — сообщение в шторке.
  final void Function(NavigatorState navigator)? onFreeLimitReached;

  const VoiceListeningSheet({
    super.key,
    this.parse,
    this.onFreeLimitReached,
  });

  static Future<VoiceInputResult?> show(
    BuildContext context, {
    VoicePhraseParser? parse,
    void Function(NavigatorState navigator)? onFreeLimitReached,
  }) {
    return showModalBottomSheet<VoiceInputResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => VoiceListeningSheet(
        parse: parse,
        onFreeLimitReached: onFreeLimitReached,
      ),
    );
  }

  /// Сколько ждать итоговый текст после «Готово», прежде чем взять
  /// распознанное по ходу речи.
  static const finalResultWait = Duration(seconds: 3);

  @override
  State<VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<VoiceListeningSheet> {
  final SpeechRecognizer _recognizer = SpeechInput.recognizer;
  _Phase _phase = _Phase.listening;
  String _words = '';
  double _level = 0;

  /// Сообщения ошибки — карточками, как на «Аналитике».
  List<String> _errors = const [];
  bool _canRetry = true;
  Timer? _finalWait;
  CancelToken? _parseToken;

  /// Номер попытки: ответы прошлой попытки (после «Сказать ещё раз») и
  /// после закрытия шторки игнорируются.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_listen());
  }

  @override
  void dispose() {
    _attempt++;
    _finalWait?.cancel();
    _parseToken?.cancel();
    if (_phase == _Phase.listening) unawaited(_recognizer.cancel());
    super.dispose();
  }

  Future<void> _listen() async {
    final attempt = ++_attempt;
    setState(() {
      _phase = _Phase.listening;
      _words = '';
      _level = 0;
      _errors = const [];
    });
    final failure = await _recognizer.prepare();
    if (!_isCurrent(attempt)) return;
    if (failure != null) return _fail(failure);
    await _recognizer.listen(
      localeId: SpeechInput.localeIdFor(LanguageManager.code),
      onWords: (words, isFinal) {
        if (!_isCurrent(attempt) || _phase != _Phase.listening) return;
        if (isFinal) {
          unawaited(_finish(words));
        } else {
          setState(() => _words = words);
        }
      },
      onLevel: (level) {
        if (_isCurrent(attempt) && _phase == _Phase.listening) {
          setState(() => _level = level);
        }
      },
      onFailure: (failure) {
        if (_isCurrent(attempt) && _phase == _Phase.listening) {
          _fail(failure);
        }
      },
    );
  }

  bool _isCurrent(int attempt) => mounted && attempt == _attempt;

  /// «Готово»: итоговый текст придёт от сервиса; если он не пришёл —
  /// берётся распознанное по ходу речи.
  void _done() {
    unawaited(_recognizer.stop());
    final attempt = _attempt;
    _finalWait?.cancel();
    _finalWait = Timer(VoiceListeningSheet.finalResultWait, () {
      if (_isCurrent(attempt) && _phase == _Phase.listening) _finish(_words);
    });
  }

  void _fail(SpeechFailure failure) {
    final l10n = context.l10n;
    _showError(
      [
        switch (failure) {
          SpeechFailure.permissionDenied => l10n.voice_error_mic_permission,
          SpeechFailure.unavailable => l10n.voice_error_unavailable,
          SpeechFailure.nothingHeard => l10n.voice_error_nothing_heard,
          SpeechFailure.failed => l10n.voice_error_recognition,
        },
      ],
      canRetry: failure == SpeechFailure.nothingHeard ||
          failure == SpeechFailure.failed,
    );
  }

  void _showError(List<String> messages, {bool canRetry = true}) {
    _finalWait?.cancel();
    setState(() {
      _phase = _Phase.error;
      _errors = messages;
      _canRetry = canRetry;
    });
  }

  Future<void> _finish(String words) async {
    _finalWait?.cancel();
    final phrase = words.trim();
    if (phrase.isEmpty) return _fail(SpeechFailure.nothingHeard);
    final attempt = _attempt;
    setState(() {
      _phase = _Phase.parsing;
      _words = phrase;
    });
    try {
      final drafts = await (widget.parse ?? _parseOnServer)(phrase);
      if (!mounted || attempt != _attempt) return;
      if (drafts.isEmpty) {
        return _showError([context.l10n.voice_error_no_amount]);
      }
      Navigator.pop(context, VoiceInputResult(phrase: phrase, drafts: drafts));
    } catch (e) {
      if (!mounted || attempt != _attempt) return;
      _showParseError(e);
    }
  }

  Future<List<Transaction>> _parseOnServer(String phrase) {
    _parseToken = CancelToken();
    return ApiService.instance.parseVoice(
      text: phrase,
      locale: LanguageManager.code,
      currency: CurrencyFormatter.currentCurrency,
      cancelToken: _parseToken,
    );
  }

  /// Лимит тарифа: Free — пейволл, Pro — до завтра, без повтора; сбой ИИ
  /// на сервере (5xx) и
  /// неразборчивый ответ — «помощники заняты», как на «Аналитике»; сеть и
  /// прочие ответы сервера — общие тексты ошибок приложения.
  void _showParseError(Object error) {
    final l10n = context.l10n;
    final busy = [
      l10n.insights_assistants_busy_msg1,
      l10n.insights_assistants_busy_msg2,
    ];
    if (error is! DioException) return _showError(busy);
    final response = error.response;
    final data = response?.data;
    final reached = PlanLimitReached.fromResponse(response?.statusCode, data);
    if (reached != null) {
      final onFreeLimit = widget.onFreeLimitReached;
      if (reached.plan == PlanCode.free && onFreeLimit != null) {
        final navigator = Navigator.of(context, rootNavigator: true);
        Navigator.pop(context);
        return onFreeLimit(navigator);
      }
      return _showError([l10n.voice_error_quota], canRetry: false);
    }
    if ((response?.statusCode ?? 0) >= 500) return _showError(busy);
    _showError([AppErrorHandler.getMessage(error)]);
  }

  void _close() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    final title = switch (_phase) {
      _Phase.listening => l10n.voice_listening_title,
      _Phase.parsing => l10n.voice_parsing,
      _Phase.error => l10n.voice_input_title,
    };

    return Container(
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: Column(
            // Шторка собрана вокруг индикатора: текст — по центру
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              WholeWordsText(
                title,
                key: const ValueKey('voice_title'),
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              // Пример фразы — только пока слушаем
              if (_phase == _Phase.listening) ...[
                const SizedBox(height: 8),
                WholeWordsText(
                  l10n.voice_listening_example,
                  key: const ValueKey('voice_example'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_phase != _Phase.error || _words.isNotEmpty)
                // Высота под две строки текста: шторка не прыгает, пока
                // распознанная фраза растёт
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: _words.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : WholeWordsText(
                          _words,
                          key: const ValueKey('voice_words'),
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(height: 1.4),
                        ),
                ),
              if (_phase == _Phase.error) ...[
                if (_words.isNotEmpty) const SizedBox(height: 12),
                for (final message in _errors) InsightCard(text: message),
              ] else ...[
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    height: 96,
                    child: _phase == _Phase.listening
                        ? _LevelIndicator(level: _level)
                        : const AiSparklesLoader(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buttons(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buttons(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.listening:
        return Row(
          children: [
            Expanded(
              child: SheetOutlinedButton(
                key: const ValueKey('voice_cancel'),
                label: l10n.cancel,
                onPressed: _close,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SheetPrimaryButton(
                key: const ValueKey('voice_done'),
                label: l10n.done_btn,
                onPressed: _done,
              ),
            ),
          ],
        );
      case _Phase.parsing:
        return SheetOutlinedButton(
          key: const ValueKey('voice_cancel'),
          label: l10n.cancel,
          onPressed: _close,
        );
      case _Phase.error:
        if (!_canRetry) {
          return SheetPrimaryButton(
            key: const ValueKey('voice_close'),
            label: l10n.voice_close_btn,
            onPressed: _close,
          );
        }
        return Row(
          children: [
            Expanded(
              child: SheetOutlinedButton(
                key: const ValueKey('voice_close'),
                label: l10n.voice_close_btn,
                onPressed: _close,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SheetPrimaryButton(
                key: const ValueKey('voice_retry'),
                label: l10n.voice_retry_btn,
                onPressed: () => unawaited(_listen()),
              ),
            ),
          ],
        );
    }
  }
}

/// Пульсирующий круг: растёт с громкостью голоса.
class _LevelIndicator extends StatelessWidget {
  final double level;

  const _LevelIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      key: const ValueKey('voice_level'),
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          scale: 0.7 + 0.3 * level,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.18),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: primary),
        ),
      ],
    );
  }
}
