import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../theme/app_colors.dart';
import '../utils/utils.dart';
import '../widgets/dashboard/day_group_widget.dart';
import '../widgets/voice_listening_sheet.dart';
import '../widgets/widgets.dart';
import 'add_transaction_sheet.dart';

/// Голосовой ввод (долгое нажатие на «+»): шторка «Говорите» → одна
/// запись — обычная форма «Новая запись», уже заполненная; несколько —
/// [VoiceDraftsSheet] со списком на подтверждение. Сам ничего не
/// записывает. Разбор фразы идёт через сервер, поэтому только после входа.
abstract final class VoiceInputFlow {
  static Future<void> start(
    BuildContext context, {
    required bool signedIn,
    VoicePhraseParser? parse,
  }) async {
    if (!signedIn) {
      AppAlerts.info(context, context.l10n.voice_sign_in_required);
      return;
    }
    if (!EntitlementService.instance.isEnabled(AppFeature.voiceInput)) return;

    final result = await VoiceListeningSheet.show(context, parse: parse);
    if (result == null || !context.mounted) return;
    if (result.drafts.length == 1) {
      await AddTransactionSheet.show(context, draft: result.drafts.single);
    } else {
      await VoiceDraftsSheet.show(context, result);
    }
  }
}

/// Записи, распознанные в одной фразе: по дням, как в ленте «Баланса».
/// Тап — форма правки черновика (без сохранения), свайп влево — убрать из
/// списка; «Сохранить все (N)» кладёт записи в базу и отправляет на сервер.
class VoiceDraftsSheet extends StatefulWidget {
  final VoiceInputResult result;

  const VoiceDraftsSheet({super.key, required this.result});

  /// `true` — записи сохранены.
  static Future<bool?> show(BuildContext context, VoiceInputResult result) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => VoiceDraftsSheet(result: result),
    );
  }

  static const _hintScreenId = 'voice_drafts';

  @override
  State<VoiceDraftsSheet> createState() => _VoiceDraftsSheetState();
}

class _VoiceDraftsSheetState extends State<VoiceDraftsSheet> {
  late List<Transaction> _drafts = List.of(widget.result.drafts);
  bool _showSwipeHint = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSwipeHint());
  }

  Future<void> _loadSwipeHint() async {
    final show = await PreferencesService.instance
        .shouldShowSwipeHint(VoiceDraftsSheet._hintScreenId);
    if (show && mounted) setState(() => _showSwipeHint = true);
  }

  Future<void> _edit(Transaction draft) async {
    final edited = await AddTransactionSheet.editDraft(context, draft);
    if (edited == null || !mounted) return;
    setState(() {
      _drafts = [
        for (final d in _drafts) d.localId == draft.localId ? edited : d,
      ];
    });
  }

  void _remove(Transaction draft) {
    setState(() {
      _drafts = [
        for (final d in _drafts)
          if (d.localId != draft.localId) d,
      ];
    });
    if (_drafts.isEmpty) Navigator.pop(context);
  }

  void _saveAll() {
    for (final d in _drafts) {
      // Курс — на момент сохранения; localId черновика — только для списка
      LocalDbService.instance.saveTransaction(Transaction.newRecord(
        type: d.type,
        category: d.category,
        amount: d.amount,
        currency: d.currency,
        date: d.date,
        description: d.description,
      ));
    }
    ApiService.instance.pushLocalChangesInBackground();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;
    final days = DayGroupWidget.groupByDay(_drafts);

    return Container(
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: SheetHandle()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WholeWordsText(
                            l10n.voice_drafts_title(_drafts.length),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          WholeWordsText(
                            '«${widget.result.phrase}»',
                            key: const ValueKey('voice_drafts_phrase'),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final (index, day) in days.entries.indexed)
                      DayGroupWidget(
                        key: ValueKey('voice_day_${day.key}'),
                        date: day.key,
                        transactions: day.value,
                        showHintOnFirstTransaction:
                            index == 0 && _showSwipeHint,
                        onHintShown: () => PreferencesService.instance
                            .recordHintShown(VoiceDraftsSheet._hintScreenId),
                        onTransactionTap: _edit,
                        onTransactionDelete: _remove,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SheetPrimaryButton(
                key: const ValueKey('voice_save_all'),
                label: l10n.voice_save_all_btn(_drafts.length),
                onPressed: _saveAll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
