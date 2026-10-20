import '../../../contracts/contracts.dart';
import '../../statistics/domain/report_arithmetic.dart';

List<DailyTotals> fullDailyTotals(Iterable<LedgerEntry> entries) {
  final days = <String, List<LedgerEntry>>{};
  for (final e in entries) {
    (days[e.localDate] ??= []).add(e);
  }
  return [
    for (final day in (days.keys.toList()..sort((a, b) => b.compareTo(a))))
      DailyTotals(
        localDate: day,
        expense: Money.fromFen(
          sumReportFen(
            days[day]!
                .where((e) => e.kind == EntryKind.expense)
                .map((e) => e.amount.fen),
          ),
        ),
        income: Money.fromFen(
          sumReportFen(
            days[day]!
                .where((e) => e.kind == EntryKind.income)
                .map((e) => e.amount.fen),
          ),
        ),
        count: days[day]!.length,
      ),
  ];
}

List<CategoryBreakdown> rootBreakdown(
  Iterable<LedgerEntry> entries,
  List<Category> categories,
) {
  final byId = {for (final c in categories) c.id: c},
      totals = <String, List<LedgerEntry>>{};
  for (final e in entries.where((e) => e.kind == EntryKind.expense)) {
    final c = byId[e.categoryId];
    if (c == null) {
      throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
    }
    (totals[c.parentId ?? c.id] ??= []).add(e);
  }
  return [
    for (final id in totals.keys)
      CategoryBreakdown(
        categoryId: id,
        name: byId[id]!.name,
        amount: Money.fromFen(
          sumReportFen(totals[id]!.map((e) => e.amount.fen)),
        ),
        directAmount: Money.fromFen(
          sumReportFen(
            totals[id]!
                .where((e) => e.categoryId == id)
                .map((e) => e.amount.fen),
          ),
        ),
        children: {
          for (final child in categories.where((c) => c.parentId == id))
            child.id: Money.fromFen(
              sumReportFen(
                totals[id]!
                    .where((e) => e.categoryId == child.id)
                    .map((e) => e.amount.fen),
              ),
            ),
        },
      ),
  ]..sort((a, b) {
    final amount = b.amount.fen.compareTo(a.amount.fen);
    return amount == 0 ? a.categoryId.compareTo(b.categoryId) : amount;
  });
}

class RangeReportService {
  const RangeReportService();
  (String, String)? latestWeeklyRange(DateTime now) {
    if (now.weekday == DateTime.monday && now.hour < 8) return null;
    final monday = calendarDay(now).subtract(Duration(days: now.weekday - 1));
    return (
      calendarDayKey(monday.subtract(const Duration(days: 7))),
      calendarDayKey(monday.subtract(const Duration(days: 1))),
    );
  }

  bool retained(String end, DateTime now) {
    final age = calendarDay(now).difference(parseCalendarDay(end)).inDays;
    return age >= 0 && age <= 30;
  }

  WeeklyReport build(LedgerRangeData data, {required DateTime now}) {
    final expenses =
        data.entries.where((e) => e.kind == EntryKind.expense).toList()
          ..sort((a, b) {
            final amount = b.amount.fen.compareTo(a.amount.fen);
            if (amount != 0) return amount;
            final time = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
    final categories = rootBreakdown(data.entries, data.categories);
    final byDate = {
          for (final d in fullDailyTotals(data.entries)) d.localDate: d,
        },
        complete = <DailyTotals>[];
    for (
      var day = parseCalendarDay(data.start);
      !day.isAfter(parseCalendarDay(data.end));
      day = day.add(const Duration(days: 1))
    ) {
      final key = calendarDayKey(day);
      complete.add(
        byDate[key] ??
            DailyTotals(
              localDate: key,
              expense: const Money.fromFen(0),
              income: const Money.fromFen(0),
              count: 0,
            ),
      );
    }
    return WeeklyReport(
      data: data,
      expense: Money.fromFen(sumReportFen(expenses.map((e) => e.amount.fen))),
      income: Money.fromFen(
        sumReportFen(
          data.entries
              .where((e) => e.kind == EntryKind.income)
              .map((e) => e.amount.fen),
        ),
      ),
      daily: complete,
      categories: categories,
      largestExpense: expenses.firstOrNull,
      largestTieCount: expenses.isEmpty
          ? 0
          : expenses.where((e) => e.amount == expenses.first.amount).length,
      categoryTieCount: categories.isEmpty
          ? 0
          : categories.where((c) => c.amount == categories.first.amount).length,
      updatedAtUtcMs: now.millisecondsSinceEpoch,
    );
  }
}
