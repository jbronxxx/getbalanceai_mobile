import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CurrencyInputFormatter Tests', () {
    late CurrencyInputFormatter formatter;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async => null,
      );
      formatter = CurrencyInputFormatter();
      CurrencyFormatter.setCurrency(Currency.usd); // 2 decimal places
    });

    TextEditingValue formatValue(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length)),
      );
    }

    test('replaces spaces and commas with periods internally', () {
      final result = formatValue('', '1 234,56');
      expect(result.text, '1 234,56');
    });

    test('rejects letters, NaN, Infinity, e, E, +, -', () {
      expect(formatValue('10', '10a').text, '10');
      expect(formatValue('10', 'NaN').text, '10');
      expect(formatValue('10', 'Infinity').text, '10');
      expect(formatValue('10', '1e5').text, '10');
      expect(formatValue('10', '+5').text, '10');
      expect(formatValue('10', '-5').text, '10');
    });

    test('removes leading zeros', () {
      expect(formatValue('', '005').text, '5');
      expect(formatValue('', '000').text, '0');
      expect(formatValue('', '0').text, '0');
    });

    test('limits decimal places based on currency', () {
      CurrencyFormatter.setCurrency(Currency.usd); // 2 decimal places
      expect(formatValue('10,0', '10,00').text, '10,00');
      expect(formatValue('10,00', '10,005').text,
          '10,00'); // should reject 3rd decimal place
    });

    test('adds spaces as thousand separators', () {
      expect(formatValue('100', '1000').text, '1 000');
      expect(formatValue('1 000', '10000').text, '10 000');
      expect(formatValue('10 000', '100000').text, '100 000');
      expect(formatValue('100 000', '1000000').text, '1 000 000');
      expect(formatValue('1 000 000', '1000000,50').text, '1 000 000,50');
    });

    test('handles decimal point correctly', () {
      expect(formatValue('', '.').text, '0,');
      expect(formatValue('0', '0,').text, '0,');
      expect(formatValue('0,', '0,5').text, '0,5');
    });

    test(
        'E3/A5: paste string with >19 digits and leading zeroes without FormatException',
        () {
      // 24 leading zeroes and '1'
      const longInput = '0000000000000000000000001';
      expect(longInput.length, 25);
      final result = formatValue('', longInput);
      expect(result.text, '1');
    });

    test('A5: input exceeding maxAmount integer length is rejected', () {
      // Currency.usd maxAmount is 100,000,000 (9 digits)
      final usdFormatter = CurrencyInputFormatter(currency: Currency.usd);
      final update = usdFormatter.formatEditUpdate(
        const TextEditingValue(text: '1000'),
        const TextEditingValue(text: '99999999999999999999'), // 20 digits
      );
      expect(update.text, '1000'); // rejected, oldValue retained
    });

    test(
        'A7: CurrencyFormatter.format respects locale for thousands and decimal separators',
        () {
      // English locale: comma as thousand separator, period as decimal separator
      final enResult = CurrencyFormatter.format(
        1234.56,
        currency: Currency.usd,
        locale: 'en',
      );
      expect(enResult, r'$1,234.56');

      // Russian locale: space as thousand separator, comma as decimal separator
      final ruResult = CurrencyFormatter.format(
        1234.56,
        currency: Currency.usd,
        locale: 'ru',
      );
      expect(ruResult, r'$1 234,56');
    });

    test(
        'A7: CurrencyFormatter.parseInput supports both English and Russian formats',
        () {
      expect(CurrencyFormatter.parseInput('1,234.56'), 1234.56);
      expect(CurrencyFormatter.parseInput('1 234,56'), 1234.56);
      expect(CurrencyFormatter.parseInput('1234.56'), 1234.56);
      expect(CurrencyFormatter.parseInput('1234,56'), 1234.56);
    });
  });

  group('CurrencyFormatter.formatForInput', () {
    tearDown(() => LanguageManager.setLanguage(AppLanguage.ru, save: false));

    test('знаки — по валюте суммы, а не по базовой', () {
      expect(CurrencyFormatter.formatForInput(19.99, Currency.usd), '19,99');
      expect(CurrencyFormatter.formatForInput(0.45, Currency.eur), '0,45');
      expect(CurrencyFormatter.formatForInput(1500000, Currency.eur),
          '1 500 000,00');
    });

    test('не зависит от языка и читается обратно без потерь', () {
      LanguageManager.setLanguage(AppLanguage.en, save: false);

      for (final (amount, currency) in [
        (1500000.0, Currency.eur),
        (1500.0, Currency.usd),
        (1234567.89, Currency.eur),
      ]) {
        final text = CurrencyFormatter.formatForInput(amount, currency);
        expect(CurrencyFormatter.parseInput(text), amount, reason: text);
      }
      expect(CurrencyFormatter.formatForInput(1500, Currency.usd), '1 500,00');
    });

    test('совпадает с тем, что оставляет поле ввода', () {
      final formatter = CurrencyInputFormatter(currency: Currency.usd);
      const text = '1 234 567,80';
      expect(CurrencyFormatter.formatForInput(1234567.8, Currency.usd), text);
      expect(
        formatter
            .formatEditUpdate(
                TextEditingValue.empty, const TextEditingValue(text: text))
            .text,
        text,
      );
    });

    test('parseInput понимает неразрывные пробелы', () {
      expect(CurrencyFormatter.parseInput('15\u00A0000'), 15000);
      expect(CurrencyFormatter.parseInput('15\u202F000,5'), 15000.5);
    });
  });

  group('CurrencyInputFormatter: вставка из буфера', () {
    TextEditingValue paste(Currency currency, String text, {String old = ''}) {
      return CurrencyInputFormatter(currency: currency).formatEditUpdate(
        TextEditingValue(text: old),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }

    test('неразрывный и узкий пробел, символ валюты', () {
      expect(paste(Currency.eur, '15\u00A0000 €').text, '15 000');
      expect(paste(Currency.eur, '15\u202F000\u00A0€').text, '15 000');
      expect(paste(Currency.eur, '15 000 EUR').text, '15 000');
      expect(paste(Currency.usd, '2 500 USD').text, '2 500');
      expect(paste(Currency.usd, r'$19.99').text, '19,99');
      expect(paste(Currency.eur, '€12,5').text, '12,5');
    });

    test('разделители тысяч EN и европейский формат', () {
      expect(paste(Currency.eur, '1,500,000').text, '1 500 000');
      expect(paste(Currency.eur, '1.500,00').text, '1 500,00');
      expect(paste(Currency.usd, r'$1,500.00').text, '1 500,00');
      expect(paste(Currency.usd, '1.500,50').text, '1 500,50');
      expect(paste(Currency.usd, '12,345,678.9').text, '12 345 678,9');
    });

    test('неоднозначный ввод отклоняется, а не угадывается', () {
      // У доллара «1,500» — это 1,5 с лишним знаком, а не 1500
      expect(paste(Currency.usd, '1,500', old: '7').text, '7');
      expect(paste(Currency.usd, '1,50,0', old: '7').text, '7');
      expect(paste(Currency.usd, '15 abc', old: '7').text, '7');
    });

    test('копейки без целой части получают ведущий ноль', () {
      expect(paste(Currency.usd, ',5').text, '0,5');
      expect(paste(Currency.usd, '.').text, '0,');
    });

    test('точка после копеек не превращает их в тысячи', () {
      expect(paste(Currency.usd, '1 500,5.', old: '1 500,5').text, '1 500,5');
    });
  });

  group('CurrencyInputFormatter: курсор', () {
    TextEditingValue edit(String oldText, String newText, int cursor) {
      return CurrencyInputFormatter(currency: Currency.usd).formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        ),
      );
    }

    test('цифра в середине: курсор остаётся после неё', () {
      final result = edit('1 000', '1 0500', 4);
      expect(result.text, '10 500');
      expect(result.selection.baseOffset, 4);
    });

    test('запятая в середине: курсор после запятой', () {
      final result = edit('1 500', '1 5,00', 4);
      expect(result.text, '15,00');
      expect(result.selection.baseOffset, 3);
    });

    test('ввод в конце — курсор в конце', () {
      final result = edit('100', '1000', 4);
      expect(result.text, '1 000');
      expect(result.selection.baseOffset, 5);
    });
  });
}
