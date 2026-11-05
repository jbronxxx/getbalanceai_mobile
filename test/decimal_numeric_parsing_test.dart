import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';

void main() {
  group('Decimal / Numeric(12, 2) Safe Parsing & Compatibility Tests', () {
    group('parseAmount helper', () {
      test('correctly parses numbers (int and double)', () {
        expect(parseAmount(100), 100.0);
        expect(parseAmount(123.45), 123.45);
        expect(parseAmount(0), 0.0);
        expect(parseAmount(-50.25), -50.25);
      });

      test('correctly parses Decimal string representations', () {
        expect(parseAmount('100.00'), 100.0);
        expect(parseAmount('123.45'), 123.45);
        expect(parseAmount('0.00'), 0.0);
        expect(parseAmount('  567.89  '), 567.89);
        expect(parseAmount('-12.50'), -12.50);
      });

      test(
          'handles null, invalid strings, and unexpected types safely with fallback',
          () {
        expect(parseAmount(null), 0.0);
        expect(parseAmount(null, 10.0), 10.0);
        expect(parseAmount('invalid_number'), 0.0);
        expect(parseAmount('invalid_number', 5.5), 5.5);
        expect(parseAmount([]), 0.0);
        expect(parseAmount({}), 0.0);
        expect(parseAmount(true), 0.0);
      });
    });

    group('parseInteger helper', () {
      test('correctly parses integers and doubles as int', () {
        expect(parseInteger(10), 10);
        expect(parseInteger(2026), 2026);
        expect(parseInteger(5.8), 5);
      });

      test('correctly parses integer string representations', () {
        expect(parseInteger('10'), 10);
        expect(parseInteger(' 2026 '), 2026);
        expect(parseInteger('5.0'), 5);
      });

      test(
          'handles null, invalid strings, and unexpected types safely with fallback',
          () {
        expect(parseInteger(null), 0);
        expect(parseInteger(null, 1), 1);
        expect(parseInteger('invalid'), 0);
        expect(parseInteger('invalid', 12), 12);
        expect(parseInteger([]), 0);
      });
    });

    group('Transaction entity deserialization with Decimal fields', () {
      test('parses Transaction when amount is Decimal string', () {
        final json = {
          'id': 'tx-decimal-1',
          'amount': '1500.50',
          'description': 'Freelance income',
          'category': 'salary',
          'type': 'income',
          'date': '2026-10-03T10:00:00Z',
          'date_created': '2026-10-03T10:00:00Z',
        };

        final tx = Transaction.fromJson(json);
        expect(tx.serverId, 'tx-decimal-1');
        expect(tx.amount, 1500.50);
        expect(tx.category, Category.salary);
        expect(tx.type, TransactionType.income);
        expect(tx.description, 'Freelance income');
      });

      test('parses Transaction when amount is num (int or double)', () {
        final json = {
          'id': 'tx-num-1',
          'amount': 250.75,
          'description': 'Supermarket',
          'category': 'food',
          'type': 'expense',
          'date': '2026-10-03T11:00:00Z',
        };

        final tx = Transaction.fromJson(json);
        expect(tx.serverId, 'tx-num-1');
        expect(tx.amount, 250.75);
        expect(tx.category, Category.food);
        expect(tx.type, TransactionType.expense);
      });

      test('parses Transaction with missing amount safely defaulting to 0.0',
          () {
        final json = {
          'id': 'tx-empty-amount',
          'description': 'No amount',
          'date': '2026-10-03T11:00:00Z',
        };

        final tx = Transaction.fromJson(json);
        expect(tx.amount, 0.0);
      });
    });

    group('Budget entity deserialization with Decimal fields', () {
      test(
          'parses Budget with Decimal string amount fields (limit_amount, spent, remaining)',
          () {
        final json = {
          'id': 'b-decimal-1',
          'category': 'food',
          'limit_amount': '3000.00',
          'spent': '1250.75',
          'remaining': '1749.25',
          'month': '10',
          'year': '2026',
        };

        final budget = Budget.fromJson(json);
        expect(budget.serverId, 'b-decimal-1');
        expect(budget.category, Category.food);
        expect(budget.limitAmount, 3000.00);
        expect(budget.spent, 1250.75);
        expect(budget.remaining, 1749.25);
        expect(budget.month, 10);
        expect(budget.year, 2026);
        expect(budget.isValidPeriod, isTrue);
      });

      test('parses Budget with numeric fields', () {
        final json = {
          'id': 'b-num-1',
          'category': 'transport',
          'limit_amount': 500.0,
          'spent': 100.0,
          'remaining': 400.0,
          'month': 10,
          'year': 2026,
        };

        final budget = Budget.fromJson(json);
        expect(budget.limitAmount, 500.0);
        expect(budget.spent, 100.0);
        expect(budget.remaining, 400.0);
      });

      test(
          'parses Budget with missing/null amount fields safely defaulting to 0.0',
          () {
        final json = {
          'id': 'b-nulls',
          'category': 'other',
        };

        final budget = Budget.fromJson(json);
        expect(budget.limitAmount, 0.0);
        expect(budget.spent, 0.0);
        expect(budget.remaining, 0.0);
        expect(budget.month, 0);
        expect(budget.year, 0);
        expect(budget.isValidPeriod, isFalse);
      });
    });
  });
}
