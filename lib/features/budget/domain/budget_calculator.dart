import '../../../core/domain/calendar_month.dart';
import '../../../core/domain/ledger_entry.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/budget_snapshot.dart';

export '../../../core/domain/budget_snapshot.dart';

final class BudgetCalculator {
  const BudgetCalculator();

  BudgetSnapshot calculate({
    required CalendarMonth month,
    required DateTime today,
    required Money? budget,
    required Iterable<LedgerEntry> entries,
  }) {
    if (budget != null && (budget.fen < 0 || budget.fen > Money.maxInputFen)) {
      throw ArgumentError('预算金额不在允许范围内');
    }
    final comparison = month.compareTo(CalendarMonth.fromDate(today));
    final period = comparison < 0
        ? MonthPeriod.past
        : comparison > 0
            ? MonthPeriod.future
            : MonthPeriod.current;
    final cutoff = calendarDay(today);
    var spentFen = 0;
    for (final entry in entries) {
      if (entry.kind != EntryKind.expense ||
          CalendarMonth.fromDate(entry.date) != month ||
          period == MonthPeriod.future ||
          (period == MonthPeriod.current && entry.date.isAfter(cutoff))) {
        continue;
      }
      spentFen += entry.amount.fen;
    }
    final remaining = budget == null ? null : budget - Money.fromFen(spentFen);
    final days = switch (period) {
      MonthPeriod.past => 0,
      MonthPeriod.current => month.days - today.day + 1,
      MonthPeriod.future => month.days,
    };
    final allowance = remaining == null || days == 0
        ? null
        : Money.fromFen((remaining.fen > 0 ? remaining.fen : 0) ~/ days);
    return BudgetSnapshot(
      month: month,
      period: period,
      budget: budget,
      spent: Money.fromFen(spentFen),
      remaining: remaining,
      remainingDays: days,
      dailyAllowance: allowance,
    );
  }
}
