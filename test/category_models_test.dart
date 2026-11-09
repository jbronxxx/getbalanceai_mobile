import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';

void main() {
  group('Category Enum & Grouping Tests', () {
    test('Category.fromString correctly parses all new income categories', () {
      expect(Category.fromString('freelance'), Category.freelance);
      expect(Category.fromString('investments'), Category.investments);
      expect(Category.fromString('transfers'), Category.transfers);
      expect(Category.fromString('cashback'), Category.cashback);
      expect(Category.fromString('sales'), Category.sales);
      expect(Category.fromString('salary'), Category.salary);
      expect(Category.fromString('food'), Category.food);
      expect(Category.fromString('unknown_category'), Category.other);
    });

    test('Category.incomeCategories contains only expected categories', () {
      expect(Category.incomeCategories, contains(Category.salary));
      expect(Category.incomeCategories, contains(Category.freelance));
      expect(Category.incomeCategories, contains(Category.investments));
      expect(Category.incomeCategories, contains(Category.transfers));
      expect(Category.incomeCategories, contains(Category.cashback));
      expect(Category.incomeCategories, contains(Category.sales));
      expect(Category.incomeCategories, contains(Category.other));

      expect(Category.incomeCategories, isNot(contains(Category.food)));
      expect(Category.incomeCategories, isNot(contains(Category.transport)));
      expect(
          Category.incomeCategories, isNot(contains(Category.subscriptions)));
    });

    test('Category.expenseCategories contains only expected categories', () {
      expect(Category.expenseCategories, contains(Category.food));
      expect(Category.expenseCategories, contains(Category.transport));
      expect(Category.expenseCategories, contains(Category.entertainment));
      expect(Category.expenseCategories, contains(Category.health));
      expect(Category.expenseCategories, contains(Category.subscriptions));
      expect(Category.expenseCategories, contains(Category.shopping));
      expect(Category.expenseCategories, contains(Category.other));
      // Последней остаётся «Другое»
      expect(Category.expenseCategories.last, Category.other);

      expect(Category.expenseCategories, isNot(contains(Category.salary)));
      expect(Category.expenseCategories, isNot(contains(Category.freelance)));
      expect(Category.expenseCategories, isNot(contains(Category.investments)));
      expect(Category.expenseCategories, isNot(contains(Category.transfers)));
      expect(Category.expenseCategories, isNot(contains(Category.cashback)));
      expect(Category.expenseCategories, isNot(contains(Category.sales)));
    });

    test('новые категории расходов (USAB-03): разбор с сервера и только расход',
        () {
      const added = [
        Category.housing,
        Category.communication,
        Category.education,
        Category.family,
        Category.car,
        Category.gifts,
        Category.travel,
        Category.beauty,
      ];
      for (final c in added) {
        expect(Category.fromString(c.name), c);
        expect(Category.expenseCategories, contains(c));
        expect(Category.incomeCategories, isNot(contains(c)));
      }
      expect(Category.expenseCategories, hasLength(15));
    });

    test('getLocalizedName returns translated name for every category', () {
      for (final cat in Category.values) {
        final name = cat.getLocalizedName();
        expect(name, isNotEmpty);
        expect(name, isNot(startsWith('category_')));
      }
    });
  });
}
