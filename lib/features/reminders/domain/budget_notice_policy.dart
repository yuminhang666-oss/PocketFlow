import '../../../contracts/contracts.dart';

enum BudgetNoticeKind { fast, over, zero }

/// Versioned engineering defaults; integer comparisons, never a forecast.
class BudgetNoticePolicy {
  const BudgetNoticePolicy();
  static const version = 1,
      minimumDay = 5,
      minimumPercent = 35,
      speedPercent = 130;
  BudgetNoticeKind? qualify({
    required CalendarMonth month,
    required DateTime now,
    required Money? budget,
    required int spentFen,
  }) {
    if (month != CalendarMonth.fromDate(now) ||
        budget == null ||
        spentFen <= 0) {
      return null;
    }
    final b = budget.fen;
    if (b == 0) return BudgetNoticeKind.zero;
    if (spentFen > b) return BudgetNoticeKind.over;
    final s = BigInt.from(spentFen), base = BigInt.from(b);
    return now.day >= minimumDay &&
            s * BigInt.from(100) >= base * BigInt.from(minimumPercent) &&
            s * BigInt.from(month.days * 100) >=
                base * BigInt.from(now.day * speedPercent)
        ? BudgetNoticeKind.fast
        : null;
  }

  bool canReserve({
    required DateTime now,
    required int budgetFen,
    required int spentFen,
    required int count,
    String? lastDate,
    int? lastUtcMs,
    int lastSpentFen = 0,
    bool muted = false,
  }) {
    if (muted || count >= 2) return false;
    if (count == 0) return true;
    if (lastDate == null ||
        lastUtcMs == null ||
        now.millisecondsSinceEpoch < lastUtcMs ||
        calendarDay(now).difference(parseCalendarDay(lastDate)).inDays < 7) {
      return false;
    }
    final tenth = (budgetFen + 9) ~/ 10, growth = tenth > 1000 ? tenth : 1000;
    return spentFen - lastSpentFen >= growth;
  }
}
