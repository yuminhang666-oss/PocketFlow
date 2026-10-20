import 'calendar_month.dart';
import 'ledger_entry.dart';
import 'ledger_models.dart';
import 'money.dart';

final class LedgerRangeData {
  LedgerRangeData({
    required this.start,
    required this.end,
    required Iterable<LedgerEntry> entries,
    required Iterable<Category> categories,
    Iterable<String> zeroExpenseDays = const [],
    required this.revision,
  }) : entries = List.unmodifiable(entries),
       categories = List.unmodifiable(categories),
       zeroExpenseDays = List.unmodifiable(zeroExpenseDays) {
    if (parseCalendarDay(start).isAfter(parseCalendarDay(end)) ||
        this.entries.any(
          (e) =>
              e.localDate.compareTo(start) < 0 ||
              e.localDate.compareTo(end) > 0,
        )) {
      throw const FormatException('范围快照日期无效');
    }
  }
  final String start, end, revision;
  final List<LedgerEntry> entries;
  final List<Category> categories;
  final List<String> zeroExpenseDays;
}

final class DailyTotals {
  const DailyTotals({
    required this.localDate,
    required this.expense,
    required this.income,
    required this.count,
  });
  final String localDate;
  final Money expense, income;
  final int count;
}

final class CategoryBreakdown {
  CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.directAmount,
    required Map<String, Money> children,
  }) : children = Map.unmodifiable(children);
  final String categoryId, name;
  final Money amount, directAmount;
  final Map<String, Money> children;
}

final class WeeklyReport {
  WeeklyReport({
    required this.data,
    required this.expense,
    required this.income,
    required Iterable<DailyTotals> daily,
    required Iterable<CategoryBreakdown> categories,
    required this.largestExpense,
    required this.largestTieCount,
    required this.categoryTieCount,
    required this.updatedAtUtcMs,
  }) : daily = List.unmodifiable(daily),
       categories = List.unmodifiable(categories);
  final LedgerRangeData data;
  final Money expense, income;
  Money get net => income - expense;
  final List<DailyTotals> daily;
  final List<CategoryBreakdown> categories;
  final LedgerEntry? largestExpense;
  final int largestTieCount, categoryTieCount, updatedAtUtcMs;
}
