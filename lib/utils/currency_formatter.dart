import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поддерживаемые валюты с их параметрами.
enum Currency {
  uzs('UZS', 'сум', 'Узбекский сум', false, 0, 100000000000), // Лимит 100 млрд
  kzt('KZT', '₸', 'Казахстанский тенге', false, 0,
      10000000000), // Лимит 10 млрд
  rub('RUB', '₽', 'Российский рубль', false, 2, 1000000000), // Лимит 1 млрд
  eur('EUR', '€', 'Евро', true, 2, 100000000), // Лимит 100 млн
  usd('USD', r'$', 'Доллар США', true, 2, 100000000); // Лимит 100 млн

  final String code; // Код валюты (ISO)
  final String symbol; // Символ валюты
  final String readableName; // Читаемое название валюты (на русском)
  final bool symbolBefore; // Ставить ли символ перед числом ($100 vs 100 руб)
  final int defaultDecimalDigits; // Сколько знаков после запятой отображать
  final double maxAmount; // Максимально допустимая сумма для ввода

  const Currency(this.code, this.symbol, this.readableName, this.symbolBefore,
      this.defaultDecimalDigits, this.maxAmount);

  String get localizedSymbol {
    if (this == Currency.uzs) {
      return LanguageManager.l10n.uzs_symbol;
    }
    return symbol;
  }

  String get localizedName => this == Currency.uzs
      ? LanguageManager.l10n.uzs_name
      : this == Currency.kzt
          ? LanguageManager.l10n.kzt_name
          : this == Currency.rub
              ? LanguageManager.l10n.rub_name
              : this == Currency.eur
                  ? LanguageManager.l10n.eur_name
                  : LanguageManager.l10n.usd_name;
}

/// Специализированный ValueNotifier с поддержкой принудительного уведомления слушателей.
class CurrencyValueNotifier extends ValueNotifier<Currency> {
  CurrencyValueNotifier(super.value);

  /// Принудительно оповещает слушателей, даже если значение валюты не изменилось.
  void forceNotify() => notifyListeners();
}

/// Утилита для форматирования и валидации денежных сумм.
class CurrencyFormatter {
  static Currency _currentCurrency = Currency.rub;

  /// Уведомляет слушателей (UI) об изменении выбранной валюты.
  static final CurrencyValueNotifier currencyNotifier =
      CurrencyValueNotifier(Currency.rub);

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
      LocalDbService.instance.convertBudgetsCurrency(oldCurrency, currency);
    }

    // Сохраняем выбор в постоянное хранилище
    await PreferencesService.instance.saveCurrency(currency.code);

    currencyNotifier.value = currency;
  }

  /// Загружает сохраненную валюту из хранилища.
  static Future<void> loadSavedCurrency() async {
    final code = await PreferencesService.instance.getCurrency();
    if (code != null) {
      try {
        final saved = Currency.values.firstWhere((c) => c.code == code);
        _currentCurrency = saved;
        currencyNotifier.value = saved;
      } catch (_) {
        // Если сохраненный код не найден, оставляем дефолтную (RUB)
      }
    }
  }

  static Currency get currentCurrency => _currentCurrency;

  /// Превращает строку из поля ввода в число.
  /// Удаляет пробелы-разделители и заменяет запятые на точки.
  static double? parseInput(String input) {
    if (input.isEmpty) return null;
    final sanitized = input.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(sanitized);
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

  /// Основной метод форматирования суммы в строку.
  /// Добавляет разделители тысяч (пробелы) и символ валюты.
  static String format(
    double amount, {
    bool showSymbol = true,
    int? decimalDigits,
    bool showSign = false,
    Currency? currency,
  }) {
    final targetCurrency = currency ?? _currentCurrency;
    final digits = decimalDigits ?? targetCurrency.defaultDecimalDigits;
    String sign = '';

    // Добавление знака + или - если требуется
    if (showSign) {
      if (amount > 0) sign = '+';
      if (amount < 0) sign = '-';
    }

    final absAmount = amount.abs();
    String formatted = absAmount.toStringAsFixed(digits);

    // Добавление пробелов как разделителей тысяч (регулярное выражение)
    final parts = formatted.split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]} ');
    formatted = parts.join(digits > 0 ? ',' : '');

    if (!showSymbol) return '$sign$formatted';

    // Позиционирование символа валюты
    if (targetCurrency.symbolBefore) {
      return '$sign${targetCurrency.localizedSymbol}$formatted';
    } else {
      return '$sign$formatted ${targetCurrency.localizedSymbol}';
    }
  }

  /// Виджет для безопасного отображения текста суммы.
  /// Использует FittedBox или ellipsis, чтобы длинные числа (UZS/KZT) не ломали верстку.
  static Widget formatText(
    double amount, {
    TextStyle? style,
    bool showSymbol = true,
    int? decimalDigits,
    bool useFittedBox = false,
    TextAlign textAlign = TextAlign.start,
    bool showSign = false,
    Currency? currency,
  }) {
    final text = Text(
      format(
        amount,
        showSymbol: showSymbol,
        decimalDigits: decimalDigits,
        showSign: showSign,
        currency: currency,
      ),
      style: style,
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

class CurrencyInputFormatter extends TextInputFormatter {
  final Currency? currency;

  CurrencyInputFormatter({this.currency});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Оставляем только цифры, точку и запятую
    final text = newValue.text.replaceAll(' ', '').replaceAll(',', '.');

    // Разрешаем только цифры и максимум одну точку. Никаких e, E, +, -, NaN, Infinity.
    final validRegex = RegExp(r'^\d*\.?\d*$');
    if (!validRegex.hasMatch(text)) {
      return oldValue;
    }

    if (text == '.') {
      return const TextEditingValue(
        text: '0,',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    final parts = text.split('.');
    String intPart = parts[0];

    // Убираем ведущие нули (например, "005" -> "5", но "0" -> "0")
    if (intPart.length > 1 && intPart.startsWith('0')) {
      intPart = int.parse(intPart).toString();
    }

    final targetCurrency = currency ?? CurrencyFormatter.currentCurrency;
    final digitsLimit = targetCurrency.defaultDecimalDigits;

    // Если валюта не поддерживает копейки (UZS, KZT), запрещаем точку
    if (digitsLimit == 0 && parts.length > 1) {
      return oldValue;
    }

    // Ограничиваем количество знаков после запятой
    if (parts.length > 1 && parts[1].length > digitsLimit) {
      return oldValue;
    }

    // Форматируем целую часть с пробелами
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formattedInt =
        intPart.replaceAllMapped(reg, (Match m) => '${m[1]} ');

    String finalString = formattedInt;
    if (parts.length > 1 || text.endsWith('.')) {
      finalString += ',${parts.length > 1 ? parts[1] : ''}';
    }

    // Сохраняем позицию курсора, ориентируясь на количество введенных "не-пробелов"
    int nonSpaceCharsBeforeCursor = 0;
    for (int i = 0; i < newValue.selection.baseOffset; i++) {
      if (i < newValue.text.length && newValue.text[i] != ' ') {
        nonSpaceCharsBeforeCursor++;
      }
    }

    int newCursorOffset = 0;
    int nonSpaceCount = 0;
    for (int i = 0; i < finalString.length; i++) {
      if (nonSpaceCount == nonSpaceCharsBeforeCursor) {
        break;
      }
      if (finalString[i] != ' ') {
        nonSpaceCount++;
      }
      newCursorOffset++;
    }

    // Если курсор был в самом конце исходной строки, переносим его в конец новой
    if (newValue.selection.baseOffset >= newValue.text.length) {
      newCursorOffset = finalString.length;
    }

    return TextEditingValue(
      text: finalString,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }
}
