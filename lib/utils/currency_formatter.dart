import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поддерживаемые валюты с их параметрами.
enum Currency {
  eur('EUR', '€', true, 2, 100000000), // Лимит 100 млн
  usd('USD', r'$', true, 2, 100000000); // Лимит 100 млн

  final String code; // Код валюты (ISO)
  final String symbol; // Символ валюты
  final bool symbolBefore; // Ставить ли символ перед числом ($100 vs 100 руб)
  final int defaultDecimalDigits; // Сколько знаков после запятой отображать
  final double maxAmount; // Максимально допустимая сумма для ввода

  const Currency(this.code, this.symbol, this.symbolBefore,
      this.defaultDecimalDigits, this.maxAmount);

  /// Валюта по коду ISO без учёта регистра; `null` — код неизвестен.
  static Currency? fromCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    return values.where((c) => c.code == normalized).firstOrNull;
  }

  String get localizedName => switch (this) {
        Currency.eur => LanguageManager.l10n.eur_name,
        Currency.usd => LanguageManager.l10n.usd_name,
      };
}

/// Специализированный ValueNotifier с поддержкой принудительного уведомления слушателей.
class CurrencyValueNotifier extends ValueNotifier<Currency> {
  CurrencyValueNotifier(super.value);

  /// Принудительно оповещает слушателей, даже если значение валюты не изменилось.
  void forceNotify() => notifyListeners();
}

/// Утилита для форматирования и валидации денежных сумм.
class CurrencyFormatter {
  static Currency _currentCurrency = Currency.usd;

  /// Уведомляет слушателей (UI) об изменении выбранной валюты.
  static final CurrencyValueNotifier currencyNotifier =
      CurrencyValueNotifier(Currency.usd);

  /// Принудительно уведомляет слушателей о необходимости обновить отображение валюты.
  static void notifyCurrencyChanged() {
    currencyNotifier.forceNotify();
  }

  /// Устанавливает текущую базовую валюту аккаунта и уведомляет слушателей.
  /// Все экраны и виджеты динамически пересчитывают отображение на лету без мутации БД.
  static Future<void> setCurrency(Currency currency) async {
    if (_currentCurrency == currency) return;
    final oldCurrency = _currentCurrency;
    _currentCurrency = currency;

    if (LocalDbService.isInitialized) {
      LocalDbService.instance.pinLegacyBudgetsCurrency(oldCurrency);
    }

    // Сохраняем выбор в постоянное хранилище
    await PreferencesService.instance.saveCurrency(currency.code);

    currencyNotifier.value = currency;
  }

  /// Загружает сохраненную валюту из хранилища.
  static Future<void> loadSavedCurrency() async {
    final code = await PreferencesService.instance.getCurrency();
    final saved = Currency.fromCode(code);
    if (saved == null) return;
    _currentCurrency = saved;
    currencyNotifier.value = saved;
  }

  static Currency get currentCurrency => _currentCurrency;

  /// Сумма, округлённая до знаков валюты [currency] (по умолчанию — базовой);
  /// «−0» становится 0.
  ///
  /// Сравнивать суммы и выбирать знак — только по округлённому значению:
  /// погрешность сложения double (100 − 99.99 − 0.01 ≠ 0) иначе даёт
  /// «Превышен на $0.00» и «−$0.00».
  static double roundToCurrency(double amount, [Currency? currency]) {
    final digits = (currency ?? _currentCurrency).defaultDecimalDigits;
    final rounded = double.parse(amount.toStringAsFixed(digits));
    return rounded == 0 ? 0 : rounded;
  }

  /// Превращает строку из поля ввода в число.
  /// Удаляет разделители тысяч и нормализует десятичный разделитель.
  static double? parseInput(String input) {
    if (input.isEmpty) return null;
    var cleaned = input.replaceAll(RegExp(r'\s'), '');
    if (cleaned.contains(',') && cleaned.contains('.')) {
      if (cleaned.lastIndexOf('.') > cleaned.lastIndexOf(',')) {
        cleaned = cleaned.replaceAll(',', '');
      } else {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }
    return double.tryParse(cleaned);
  }

  /// Проверяет корректность введенной суммы и соблюдение лимитов.
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return LanguageManager.l10n.enter_amount;
    }
    final amount = parseInput(value);
    if (amount == null || amount <= 0) {
      return LanguageManager.l10n.invalid_amount;
    }
    if (amount > _currentCurrency.maxAmount) {
      return '${LanguageManager.l10n.max_amount_prefix}: ${format(_currentCurrency.maxAmount)}';
    }
    return null;
  }

  /// Сумма для подстановки в поле ввода: формат [CurrencyInputFormatter]
  /// (пробел между тысячами, запятая перед копейками) независимо от языка,
  /// число знаков — по валюте [currency], а не по базовой.
  ///
  /// [format] для этого не годится: в EN он даёт «1,500», и `parseInput`
  /// читает запятую как десятичную — сумма делится на 1000.
  static String formatForInput(double amount, Currency currency) {
    final fixed = amount.abs().toStringAsFixed(currency.defaultDecimalDigits);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
  }

  /// Основной метод форматирования суммы в строку.
  /// Добавляет разделители тысяч и символ валюты с учетом выбранной локали.
  static String format(
    double amount, {
    bool showSymbol = true,
    int? decimalDigits,
    bool showSign = false,
    Currency? currency,
    String? locale,
  }) {
    final targetCurrency = currency ?? _currentCurrency;
    final digits = decimalDigits ?? targetCurrency.defaultDecimalDigits;
    final langCode =
        (locale ?? LanguageManager.currentLanguage.code).toLowerCase();
    final isEn = langCode.startsWith('en');

    final thousandsSeparator = isEn ? ',' : ' ';
    final decimalSeparator = isEn ? '.' : ',';

    // Знак — по сумме, округлённой до показываемых знаков: −0.001 → «0.00».
    final formatted = amount.abs().toStringAsFixed(digits);
    final isZero = double.parse(formatted) == 0;

    String sign = '';
    if (showSign && !isZero) {
      sign = amount > 0 ? '+' : '-';
    }

    // Добавление разделителей тысяч (регулярное выражение)
    final parts = formatted.split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0]
        .replaceAllMapped(reg, (Match m) => '${m[1]}$thousandsSeparator');
    final formattedNumber = parts.length > 1 && digits > 0
        ? '${parts[0]}$decimalSeparator${parts[1]}'
        : parts[0];

    if (!showSymbol) return '$sign$formattedNumber';

    // Позиционирование символа валюты
    if (targetCurrency.symbolBefore) {
      return '$sign${targetCurrency.symbol}$formattedNumber';
    } else {
      return '$sign$formattedNumber ${targetCurrency.symbol}';
    }
  }

  /// Типографский минус для отображения сумм.
  static const String typographicMinus = '\u2212';

  /// Сумма, скрытая «глазком» на карточке баланса (SEC-08).
  static const String hiddenAmount = '\u2022\u2022\u2022\u2022\u2022';

  /// Виджет для безопасного отображения текста суммы.
  /// Использует FittedBox или ellipsis, чтобы длинные числа не ломали верстку.
  ///
  /// Только для экрана: минус заменяется типографским «−» (ширина как у «+»),
  /// цифры моноширинные, чтобы суммы в колонках не «прыгали». Для файлов
  /// и полей ввода используйте [format].
  static Widget formatText(
    double amount, {
    TextStyle? style,
    bool showSymbol = true,
    int? decimalDigits,
    bool useFittedBox = false,
    TextAlign textAlign = TextAlign.start,
    bool showSign = false,
    Currency? currency,
    String? locale,
    String prefix = '',
  }) {
    final formatted = format(
      amount,
      showSymbol: showSymbol,
      decimalDigits: decimalDigits,
      showSign: showSign,
      currency: currency,
      locale: locale,
    ).replaceAll('-', typographicMinus);
    final text = Text(
      '$prefix$formatted',
      style: (style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (useFittedBox) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: text,
      );
    }
    return text;
  }
}

/// Форматирует ввод суммы на лету: пробел между тысячами, запятая перед
/// копейками, число знаков — по валюте поля.
///
/// Вставку из буфера нормализует: убирает пробелы любой ширины (в том числе
/// неразрывные из отформатированных сумм) и символы/коды валют, распознаёт
/// разделители тысяч «1,500,000» и «1.500,00». Неоднозначный ввод
/// отклоняется, а не угадывается.
class CurrencyInputFormatter extends TextInputFormatter {
  final Currency? currency;

  CurrencyInputFormatter({this.currency});

  static final RegExp _whitespace = RegExp(r'\s');
  static final RegExp _thousands = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

  static List<String>? _currencyMarks;

  /// Символы и коды валют, которые могут прийти вместе с суммой при
  /// вставке; длинные — первыми, чтобы код не разбирался по частям.
  static List<String> get _marks => _currencyMarks ??= () {
        final marks = <String>{
          for (final c in Currency.values) ...[c.code, c.symbol],
        };
        return marks.map((m) => m.toLowerCase()).toSet().toList()
          ..sort((a, b) => b.length.compareTo(a.length));
      }();

  /// Длина символа или кода валюты, начинающегося в [input] с [index];
  /// 0 — валюты здесь нет.
  static int _markLengthAt(String input, int index) {
    for (final mark in _marks) {
      final end = index + mark.length;
      if (end <= input.length &&
          input.substring(index, end).toLowerCase() == mark) {
        return mark.length;
      }
    }
    return 0;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final targetCurrency = currency ?? CurrencyFormatter.currentCurrency;
    final parsed = _parse(newValue.text, targetCurrency.defaultDecimalDigits);
    if (parsed == null) return oldValue;

    var intPart = parsed.intPart;
    final fraction = parsed.fraction;
    if (intPart.isEmpty && fraction == null) return TextEditingValue.empty;

    // Ведущие нули убираются на строке, без int.parse: длинная вставка
    // не переполняет int
    final withoutZeros = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final removedZeros = intPart.length - withoutZeros.length;
    intPart = withoutZeros;
    final addedZero = intPart.isEmpty;
    if (addedZero) intPart = '0';

    final maxIntDigits = targetCurrency.maxAmount.toStringAsFixed(0).length;
    if (intPart.length > maxIntDigits) return oldValue;

    var text = intPart.replaceAllMapped(_thousands, (m) => '${m[1]} ');
    if (fraction != null) text += ',$fraction';

    final cursor = newValue.selection.baseOffset;
    if (cursor < 0 || cursor >= newValue.text.length) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    // Курсор встаёт после того же числа цифр (и десятичной запятой),
    // что стояли перед ним во введённом тексте
    final decimalBefore =
        parsed.decimalIndex != null && parsed.decimalIndex! < cursor;
    var digitsBefore = 0;
    for (var i = 0; i < cursor; i++) {
      if (_isDigit(newValue.text, i)) digitsBefore++;
    }
    digitsBefore = (digitsBefore - removedZeros).clamp(0, digitsBefore);
    if (addedZero && decimalBefore) digitsBefore++;

    var offset = 0;
    var seenDigits = 0;
    var passedDecimal = false;
    while (offset < text.length) {
      if (seenDigits >= digitsBefore && (!decimalBefore || passedDecimal)) {
        break;
      }
      if (text[offset] == ',') {
        passedDecimal = true;
      } else if (_isDigit(text, offset)) {
        seenDigits++;
      }
      offset++;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static bool _isDigit(String text, int index) {
    final unit = text.codeUnitAt(index);
    return unit >= 0x30 && unit <= 0x39;
  }

  /// Разбирает ввод на целую часть и копейки; `null` — ввод недопустим.
  static _ParsedAmount? _parse(String input, int digitsLimit) {
    // Значимые символы и их позиции в исходном тексте
    final chars = <String>[];
    final positions = <int>[];
    var i = 0;
    while (i < input.length) {
      if (_whitespace.hasMatch(input[i])) {
        i++;
        continue;
      }
      final markLength = _markLengthAt(input, i);
      if (markLength > 0) {
        i += markLength;
        continue;
      }
      final ch = input[i];
      if (!_isDigit(input, i) && ch != ',' && ch != '.') return null;
      chars.add(ch);
      positions.add(i);
      i++;
    }

    final separators = [
      for (var k = 0; k < chars.length; k++)
        if (chars[k] == ',' || chars[k] == '.') k,
    ];

    int? decimalAt;
    if (separators.isNotEmpty) {
      final last = separators.last;
      final kinds = separators.map((k) => chars[k]).toSet();
      if (kinds.length > 1) {
        // «1,500.00» / «1.500,00»: последний разделитель — десятичный,
        // второй вид — только тысячи
        if (separators.where((k) => chars[k] == chars[last]).length > 1) {
          return null;
        }
        decimalAt = last;
      } else if (separators.length == 1) {
        if (digitsLimit > 0) {
          decimalAt = last;
        } else if (last == chars.length - 1) {
          // У валют без копеек запятая в конце просто не ставится
          chars.removeLast();
          positions.removeLast();
        }
      }
    }

    final intEnd = decimalAt ?? chars.length;
    final intRaw = chars.sublist(0, intEnd).join();
    final fraction =
        decimalAt == null ? null : chars.sublist(decimalAt + 1).join();

    // Разделители в целой части допустимы только как тысячи: «1,500,000»
    String intPart = intRaw;
    if (intRaw.contains(RegExp(r'[.,]'))) {
      final groupChar = intRaw.contains(',') ? ',' : '.';
      final grouped = RegExp('^\\d{1,3}(\\$groupChar\\d{3})+\$');
      if (intRaw.contains(groupChar == ',' ? '.' : ',') ||
          !grouped.hasMatch(intRaw)) {
        return null;
      }
      intPart = intRaw.replaceAll(groupChar, '');
    }

    if (fraction != null &&
        (fraction.contains(RegExp(r'[.,]')) || fraction.length > digitsLimit)) {
      return null;
    }

    return _ParsedAmount(
      intPart: intPart,
      fraction: fraction,
      decimalIndex: decimalAt == null ? null : positions[decimalAt],
    );
  }
}

/// Разобранный ввод суммы: цифры целой части, копейки (`null` — без
/// десятичного разделителя) и позиция разделителя во введённом тексте.
class _ParsedAmount {
  final String intPart;
  final String? fraction;
  final int? decimalIndex;

  const _ParsedAmount({
    required this.intPart,
    required this.fraction,
    required this.decimalIndex,
  });
}
