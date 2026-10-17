import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/core/domain/calendar_month.dart';
import 'package:pocketflow/core/domain/ledger_entry.dart';
import 'package:pocketflow/core/domain/money.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';

LedgerEntry expense(String id, int amount) => LedgerEntry(
  id: id,
  amount: Money.fromFen(amount),
  localDate: '2026-10-17',
  categoryId: 'food',
  occurredAtUtcMs: 100,
  createdAtUtcMs: 100,
  updatedAtUtcMs: 100,
);

void main() {
  test('MVP example changes daily allowance from 60 to 58.80 after 18', () {
    const calculator = BudgetCalculator();
    final entries = [expense('previous', 60000)];
    BudgetSnapshot calculate() => calculator.calculate(
      month: CalendarMonth(2026, 10),
      today: DateTime(2026, 10, 17),
      budget: const Money.fromFen(150000),
      entries: entries,
    );
    expect(calculate().dailyAllowance?.decimal, '60.00');
    entries.add(expense('lunch', 1800));
    expect(calculate().dailyAllowance?.decimal, '58.80');
    entries.removeLast();
    expect(calculate().dailyAllowance?.decimal, '60.00');
  });

  test('each current day keeps a nonnegative conservative fen allowance', () {
    const calculator = BudgetCalculator();
    for (final month in [CalendarMonth(2026, 4), CalendarMonth(2028, 2)]) {
      for (var day = 1; day <= month.days; day++) {
        for (final fen in [0, 1, 29, 100, Money.maxInputFen]) {
          final state = calculator.calculate(
            month: month,
            today: DateTime(month.year, month.month, day),
            budget: Money.fromFen(fen),
            entries: const [],
          );
          final days = month.days - day + 1;
          final allocated = state.dailyAllowance!.fen * days;
          expect(state.remainingDays, days);
          expect(allocated, lessThanOrEqualTo(fen));
          expect(fen - allocated, lessThan(days));
        }
      }
    }
  });
}
