import '../../../contracts/contracts.dart';
import '../../../core/domain/category_catalog.dart';
import 'report_arithmetic.dart';
import '../../reports/domain/range_report_service.dart';

/// Pure aggregation of one repository snapshot. Never caches running totals.
final class DefaultMonthlyReportService implements MonthlyReportService {
  const DefaultMonthlyReportService({this._clock = const SystemClock()});

  final Clock _clock;

  /// Historical months end at month end; the current month ends today.
  String defaultCutoff(CalendarMonth month) {
    final today = calendarDay(_clock.now());
    final current = CalendarMonth.fromDate(today);
    if (month.compareTo(current) > 0) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidDate);
    }
    return calendarDayKey(
      month == current
          ? today
          : DateTime.utc(month.year, month.month, month.days),
    );
  }

  @override
  MonthlyReport build(LedgerMonthData data, {required String asOfLocalDate}) {
    final DateTime cutoff;
    try {
      cutoff = parseCalendarDay(asOfLocalDate);
      if (CalendarMonth.fromDate(cutoff) != data.month ||
          cutoff.isAfter(calendarDay(_clock.now()))) {
        throw const FormatException('Invalid report cutoff');
      }
    } catch (_) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidDate);
    }

    final categories = <String, Category>{};
    for (final category in data.categories) {
      if (categories.containsKey(category.id)) {
        throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
      }
      categories[category.id] = category;
    }
    final ids = <String>{};
    for (final entry in data.entries) {
      if (!ids.add(entry.id) ||
          !categories.containsKey(entry.categoryId) ||
          CalendarMonth.fromDate(entry.date) != data.month ||
          !_validTimestamp(entry.occurredAtUtcMs) ||
          !_validTimestamp(entry.createdAtUtcMs) ||
          !_validTimestamp(entry.updatedAtUtcMs)) {
        throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
      }
    }

    // Preserve income in the complete transaction table; it never offsets spend.
    final entries = data.entries.where((e) => !e.date.isAfter(cutoff)).toList()
      ..sort((a, b) {
        final time = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    final dailyFen = List<BigInt>.filled(cutoff.day, BigInt.zero);
    final categoryFen = <String, BigInt>{};
    final incomeDailyFen = List<BigInt>.filled(cutoff.day, BigInt.zero);
    final incomeCategoryFen = <String, BigInt>{};
    for (final entry in entries) {
      if (entry.kind == EntryKind.income) {
        final fen = BigInt.from(entry.amount.fen);
        incomeDailyFen[entry.date.day - 1] += fen;
        incomeCategoryFen.update(
          categories[entry.categoryId]!.parentId ?? entry.categoryId,
          (v) => v + fen,
          ifAbsent: () => fen,
        );
        continue;
      }
      final fen = BigInt.from(entry.amount.fen);
      dailyFen[entry.date.day - 1] += fen;
      categoryFen.update(
        entry.categoryId,
        (old) => old + fen,
        ifAbsent: () => fen,
      );
    }
    final daily = [
      for (var i = 0; i < dailyFen.length; i++)
        DailyExpense(
          localDate: calendarDayKey(
            DateTime.utc(data.month.year, data.month.month, i + 1),
          ),
          amount: Money.fromFen(checkedReportInt(dailyFen[i])),
        ),
    ];
    final sortedCategories = data.categories.toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    final spent = sumReportFen(daily.map((d) => d.amount.fen));
    final budget = data.budget?.amount;
    return MonthlyReport(
      month: data.month,
      asOfLocalDate: asOfLocalDate,
      budget: budget,
      totalExpense: Money.fromFen(spent),
      remaining: budget == null
          ? null
          : Money.fromFen(
              checkedReportInt(BigInt.from(budget.fen) - BigInt.from(spent)),
            ),
      daily: daily,
      categoryTotals: [
        for (final c in rootBreakdown(entries, data.categories))
          CategoryExpense(
            categoryId: c.categoryId,
            categoryName: c.name,
            amount: c.amount,
          ),
      ],
      breakdown: rootBreakdown(entries, data.categories),
      entryCategoryNames: {
        for (final c in data.categories) c.id: categoryPath(c, data.categories),
      },
      entries: entries,
      totalIncome: Money.fromFen(
        checkedReportInt(incomeDailyFen.fold(BigInt.zero, (a, b) => a + b)),
      ),
      dailyIncome: [
        for (var i = 0; i < incomeDailyFen.length; i++)
          DailyExpense(
            localDate: calendarDayKey(
              DateTime.utc(data.month.year, data.month.month, i + 1),
            ),
            amount: Money.fromFen(checkedReportInt(incomeDailyFen[i])),
          ),
      ],
      incomeCategoryTotals: [
        for (final c in sortedCategories.where(
          (c) =>
              c.parentId == null &&
              (incomeCategoryFen[c.id] ?? BigInt.zero) > BigInt.zero,
        ))
          CategoryExpense(
            categoryId: c.id,
            categoryName: categoryPath(c, data.categories),
            amount: Money.fromFen(
              checkedReportInt(incomeCategoryFen[c.id] ?? BigInt.zero),
            ),
          ),
      ],
    );
  }

  bool _validTimestamp(int value) =>
      value >= -8640000000000000 && value <= 8640000000000000;
}
