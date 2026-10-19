import 'ledger_entry.dart';
import 'money.dart';

final class LedgerFilter {
  const LedgerFilter({
    this.query = '',
    this.kind,
    this.categoryId,
    this.fromDate,
    this.toDate,
    this.minFen,
    this.maxFen,
  });
  final String query;
  final EntryKind? kind;
  final String? categoryId, fromDate, toDate;
  final int? minFen, maxFen;
}

final class DayTotals {
  const DayTotals({
    required this.expense,
    required this.income,
    required this.count,
  });
  final Money expense, income;
  final int count;
}

final class LedgerView {
  LedgerView({
    required Iterable<LedgerEntry> entries,
    required this.expense,
    required this.income,
    required Map<String, DayTotals> days,
  }) : entries = List.unmodifiable(entries),
       days = Map.unmodifiable(days);
  final List<LedgerEntry> entries;
  final Money expense, income;
  final Map<String, DayTotals> days;
  Money get netFlow => income - expense;
}
