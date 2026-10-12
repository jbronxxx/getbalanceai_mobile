import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:getbalanceai_mobile/utils/currency_formatter.dart';

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
      CurrencyFormatter.setCurrency(Currency.rub); // 2 decimal places
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
      CurrencyFormatter.setCurrency(Currency.rub); // 2 decimal places
      expect(formatValue('10,0', '10,00').text, '10,00');
      expect(formatValue('10,00', '10,005').text,
          '10,00'); // should reject 3rd decimal place

      CurrencyFormatter.setCurrency(Currency.uzs); // 0 decimal places
      expect(formatValue('10', '10,').text, '10'); // should reject comma
      expect(formatValue('10', '10,5').text, '10'); // should reject decimal
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
        currency: Currency.rub,
        locale: 'ru',
      );
      expect(ruResult, '1 234,56 ₽');
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
}
