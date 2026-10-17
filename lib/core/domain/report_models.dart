import 'calendar_month.dart';
import 'ledger_entry.dart';
import 'money.dart';

final class DailyExpense {
  DailyExpense({required String localDate, required this.amount})
    : date = parseCalendarDay(localDate);
  final DateTime date;
  final Money amount;
  String get localDate => calendarDayKey(date);
}

final class CategoryExpense {
  const CategoryExpense({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });
  final String categoryId;
  final String categoryName;
  final Money amount;
}

final class MonthlyReport {
  MonthlyReport({
    required this.month,
    required String asOfLocalDate,
    required this.budget,
    required this.totalExpense,
    required this.remaining,
    required Iterable<DailyExpense> daily,
    required Iterable<CategoryExpense> categoryTotals,
    required Iterable<LedgerEntry> entries,
  }) : asOf = parseCalendarDay(asOfLocalDate),
       daily = List.unmodifiable(daily),
       categoryTotals = List.unmodifiable(categoryTotals),
       entries = List.unmodifiable(entries);
  final CalendarMonth month;
  final DateTime asOf;
  final Money? budget;
  final Money totalExpense;
  final Money? remaining;
  final List<DailyExpense> daily;
  final List<CategoryExpense> categoryTotals;
  final List<LedgerEntry> entries;
  String get asOfLocalDate => calendarDayKey(asOf);
}
