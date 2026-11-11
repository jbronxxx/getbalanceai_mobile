import '../utils/utils.dart';
import 'local_db_models.dart';

/// Черновики записей из ответа `POST /voice/parse`.
///
/// Черновик — несохранённая [Transaction] с временным `localId` (1, 2, …):
/// по нему строки списка и форма правки находят свой черновик. В базу
/// черновик кладётся заново через [Transaction.newRecord] с `localId = 0`.
abstract final class VoiceDrafts {
  /// Разбирает `data` ответа. День записи сервер отдаёт без времени — время
  /// берётся текущее, как у записи из формы, чтобы порядок в дне не ломался.
  /// Запись без суммы пропускается; неизвестная валюта — валюта приложения.
  static List<Transaction> fromJson(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final records = data['records'];
    if (records is! List) return const [];
    final drafts = <Transaction>[];
    for (final item in records.whereType<Map<String, dynamic>>()) {
      final amount = parseAmount(item['amount']);
      if (amount <= 0) continue;
      final day = DateTime.tryParse(item['date'] as String? ?? '');
      drafts.add(Transaction.newRecord(
        localId: drafts.length + 1,
        type: TransactionType.fromString(item['type'] as String? ?? ''),
        category: Category.fromString(item['category'] as String? ?? ''),
        amount: amount,
        currency: Currency.fromCode(item['currency'] as String?) ??
            CurrencyFormatter.currentCurrency,
        date: day == null
            ? clock
            : DateTime(day.year, day.month, day.day, clock.hour, clock.minute,
                clock.second),
        description: (item['description'] as String? ?? '').trim(),
      ));
    }
    return drafts;
  }
}
