import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';

void main() {
  group('Transaction.fromJson', () {
    test('Transaction entity in local_db_models parses created_at correctly',
        () {
      final json = {
        'id': 'tx-local-1',
        'amount': 500.0,
        'description': 'Gift',
        'category': 'other',
        'type': 'income',
        'date': '2026-09-12T10:00:00Z',
        'created_at': '2026-09-12T10:15:00Z',
      };

      final tx = Transaction.fromJson(json);
      expect(tx.serverId, 'tx-local-1');
      expect(
        DateTime.fromMillisecondsSinceEpoch(tx.dateCreatedMilliseconds)
            .toUtc()
            .toIso8601String(),
        '2026-09-12T10:15:00.000Z',
      );
    });
  });
}
