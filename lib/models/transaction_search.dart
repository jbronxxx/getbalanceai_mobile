import '../l10n/app_localizations.dart';
import '../utils/currency_formatter.dart';
import 'local_db_models.dart';

/// Условия поиска операций: текст, тип и валюта. Пустой текст и `null` в
/// фильтре — без ограничения.
class TransactionSearch {
  final String query;
  final TransactionType? type;
  final Currency? currency;

  const TransactionSearch({this.query = '', this.type, this.currency});

  TransactionSearch copyWith({
    String? query,
    TransactionType? Function()? type,
    Currency? Function()? currency,
  }) =>
      TransactionSearch(
        query: query ?? this.query,
        type: type != null ? type() : this.type,
        currency: currency != null ? currency() : this.currency,
      );

  /// Операции из [all], подходящие под условия, в исходном порядке.
  ///
  /// Текст ищется без учёта регистра в описании и в названии категории на
  /// языке [l10n] — «кофе» найдёт описание, «питание» — всю категорию.
  List<Transaction> apply(List<Transaction> all, AppLocalizations l10n) {
    final needle = query.trim().toLowerCase();
    final categoryMatches = needle.isEmpty
        ? const <Category>{}
        : {
            for (final c in Category.values)
              if (c.localizedIn(l10n).toLowerCase().contains(needle)) c,
          };
    return all.where((t) {
      if (type != null && t.type != type) return false;
      if (currency != null && t.currency != currency) return false;
      if (needle.isEmpty) return true;
      return t.description.toLowerCase().contains(needle) ||
          categoryMatches.contains(t.category);
    }).toList(growable: false);
  }

  /// Валюты, которые встречаются в [all], — для чипов фильтра, в порядке
  /// списка валют приложения.
  static List<Currency> currenciesOf(Iterable<Transaction> all) {
    final used = {for (final t in all) t.currency};
    return [
      for (final c in Currency.values)
        if (used.contains(c)) c
    ];
  }
}
