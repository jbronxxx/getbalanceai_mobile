import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/services/undoable_deletions.dart';

void main() {
  late List<int> committed;
  late UndoableDeletions<int> deletions;
  late int notifications;

  setUp(() {
    committed = [];
    notifications = 0;
    deletions = UndoableDeletions<int>(
      idOf: (id) => id,
      commit: (id) async => committed.add(id),
    )..addListener(() => notifications++);
  });

  group('UndoableDeletions', () {
    testWidgets('удаляет запись только по истечении задержки', (tester) async {
      deletions.schedule(1);
      expect(deletions.isPending(1), isTrue);
      expect(notifications, 1);

      await tester.pump(const Duration(seconds: 4));
      expect(committed, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(committed, [1]);
      expect(deletions.isPending(1), isFalse);
      expect(notifications, 2);
      deletions.dispose();
    });

    testWidgets('отмена возвращает запись и не удаляет её', (tester) async {
      deletions.schedule(1);
      expect(deletions.undo(1), isTrue);
      expect(deletions.isPending(1), isFalse);
      expect(notifications, 2);

      await tester.pump(const Duration(seconds: 10));
      expect(committed, isEmpty);
      deletions.dispose();
    });

    testWidgets('после удаления отменить уже нельзя', (tester) async {
      deletions.schedule(1);
      await tester.pump(const Duration(seconds: 5));
      expect(deletions.undo(1), isFalse);
      deletions.dispose();
    });

    testWidgets('у каждой записи свой отсчёт', (tester) async {
      deletions.schedule(1);
      await tester.pump(const Duration(seconds: 3));
      deletions.schedule(2);
      deletions.undo(1);

      await tester.pump(const Duration(seconds: 5));
      expect(committed, [2]);
      deletions.dispose();
    });

    testWidgets('dispose сразу удаляет ожидающие записи', (tester) async {
      deletions
        ..schedule(1)
        ..schedule(2);
      deletions.dispose();
      expect(committed, [1, 2]);

      await tester.pump(const Duration(seconds: 10));
      expect(committed, [1, 2]);
    });

    testWidgets('ошибка удаления не роняет приложение', (tester) async {
      final failing = UndoableDeletions<int>(
        idOf: (id) => id,
        commit: (_) async => throw Exception('network'),
      );
      failing.schedule(1);
      await tester.pump(const Duration(seconds: 5));
      expect(failing.isPending(1), isFalse);
      failing.dispose();
    });
  });
}
