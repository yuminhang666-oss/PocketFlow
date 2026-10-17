import 'calendar_month.dart';
import 'money.dart';

enum MonthPeriod { past, current, future }

final class BudgetSnapshot {
  const BudgetSnapshot({
    required this.month,
    required this.period,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.remainingDays,
    required this.dailyAllowance,
  });

  final CalendarMonth month;
  final MonthPeriod period;
  final Money? budget;
  final Money spent;
  final Money? remaining;
  final int remainingDays;
  final Money? dailyAllowance;
  bool get isOverspent => (remaining?.fen ?? 0) < 0;
}
