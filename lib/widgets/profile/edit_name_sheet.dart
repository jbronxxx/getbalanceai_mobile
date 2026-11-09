import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../keyboard_inset_padding.dart';
import '../sheet_buttons.dart';
import '../whole_words_text.dart';

/// Шторка смены имени. Имя сохраняется на сервере; на устройстве оно
/// меняется только после ответа сервера, при ошибке шторка остаётся открытой.
class EditNameSheet extends StatefulWidget {
  final String name;

  const EditNameSheet({super.key, required this.name});

  static Future<void> show(BuildContext context, {required String name}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => EditNameSheet(name: name),
    );
  }

  @override
  State<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<EditNameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.name);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final name = _controller.text.trim();
    return !_saving && name.isNotEmpty && name != widget.name.trim();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateUserName(_controller.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppErrorHandler.show(context, e, title: context.l10n.edit_name_error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return KeyboardInsetPadding(
      child: Container(
        padding:
            const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
        decoration: AppSheet.decoration(context),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SheetHandle()),
                WholeWordsText(
                  context.l10n.edit_name_title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('edit_name_field'),
                  controller: _controller,
                  autofocus: true,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                        AuthApiService.userNameMaxLength),
                  ],
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: context.l10n.edit_name_label,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SheetPrimaryButton(
                  key: const ValueKey('edit_name_save'),
                  label: context.l10n.save_btn,
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        )
                      : null,
                  onPressed: _canSave ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
