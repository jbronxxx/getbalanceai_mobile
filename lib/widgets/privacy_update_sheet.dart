import 'package:flutter/material.dart';
import '../config/legal_links.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/utils.dart';
import 'app_sheet.dart';
import 'legal_changes.dart';
import 'sheet_buttons.dart';
import 'whole_words_text.dart';

/// Шторка о новой версии политики конфиденциальности: доступ к данным она
/// не закрывает. «Понятно» отмечает, что пользователь ознакомлен; смахнутая
/// шторка покажется снова при следующем запуске.
class PrivacyUpdateSheet extends StatelessWidget {
  final LegalDocumentInfo info;

  const PrivacyUpdateSheet({super.key, required this.info});

  /// Открывает шторку; `true` — нажато «Понятно».
  static Future<bool> show(BuildContext context, LegalDocumentInfo info) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => PrivacyUpdateSheet(info: info),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              WholeWordsText(
                context.l10n.privacy_update_title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              LegalChanges(info: info, page: LegalPage.privacy),
              const SizedBox(height: 16),
              SheetPrimaryButton(
                key: const ValueKey('privacy_update_ok_button'),
                label: context.l10n.legal_got_it_btn,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
