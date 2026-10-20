import 'calendar_month.dart';
import 'ledger_entry.dart';
import 'money.dart';
import 'range_models.dart';

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
    this.totalIncome = const Money.fromFen(0),
    Iterable<DailyExpense> dailyIncome = const [],
    Iterable<CategoryExpense> incomeCategoryTotals = const [],
    Iterable<CategoryBreakdown> breakdown = const [],
    Map<String, String> entryCategoryNames = const {},
  }) : asOf = parseCalendarDay(asOfLocalDate),
       daily = List.unmodifiable(daily),
       categoryTotals = List.unmodifiable(categoryTotals),
       entries = List.unmodifiable(entries),
       dailyIncome = List.unmodifiable(dailyIncome),
       incomeCategoryTotals = List.unmodifiable(incomeCategoryTotals),
       breakdown = List.unmodifiable(breakdown),
       entryCategoryNames = Map.unmodifiable(entryCategoryNames);
  final CalendarMonth month;
  final DateTime asOf;
  final Money? budget;
  final Money totalExpense;
  final Money? remaining;
  final List<DailyExpense> daily;
  final List<CategoryExpense> categoryTotals;
  final List<LedgerEntry> entries;
  final Money totalIncome;
  final List<DailyExpense> dailyIncome;
  final List<CategoryExpense> incomeCategoryTotals;
  final List<CategoryBreakdown> breakdown;
  final Map<String, String> entryCategoryNames;
  Money get netFlow => totalIncome - totalExpense;
  String get asOfLocalDate => calendarDayKey(asOf);
}
