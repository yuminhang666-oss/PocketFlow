import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/core/domain/calendar_month.dart';
import 'package:pocketflow/core/domain/ledger_entry.dart';
import 'package:pocketflow/core/domain/money.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';

LedgerEntry expense(String date, int fen, {String id = 'a',
    EntryKind kind = EntryKind.expense}) => LedgerEntry(
      id: id, amount: Money.fromFen(fen), localDate: date,
      categoryId: 'food', kind: kind,
      occurredAtUtcMs: parseCalendarDay(date).millisecondsSinceEpoch,
      createdAtUtcMs: 1792195200000,
      updatedAtUtcMs: 1792195200000,
    );

void main() {
  const calculator = BudgetCalculator();
  BudgetSnapshot compute({CalendarMonth? month, DateTime? day,
      Money? budget = const Money.fromFen(150000),
      List<LedgerEntry> entries = const []}) => calculator.calculate(
        month: month ?? CalendarMonth(2026, 10),
        today: day ?? DateTime(2026, 10, 17, 23, 59),
        budget: budget, entries: entries,
      );

  test('user example counts today and produces 60 yuan per day', () {
    final state = compute(entries: [expense('2026-10-17', 60000)]);
    expect(state.remainingDays, 15);
    expect(state.remaining?.fen, 90000);
    expect(state.dailyAllowance?.fen, 6000);
  });

  test('one-fen expense floors allowance rather than overspending', () {
    final state = compute(entries: [expense('2026-10-01', 60001)]);
    expect(state.remaining?.fen, 89999);
    expect(state.dailyAllowance?.fen, 5999);
  });

  test('last day and leap/nonleap February have correct denominators', () {
    expect(compute(day: DateTime(2026, 10, 31)).remainingDays, 1);
    expect(compute(month: CalendarMonth(2028, 2),
        day: DateTime(2028, 2, 28)).remainingDays, 2);
    expect(compute(month: CalendarMonth(2027, 2),
        day: DateTime(2027, 2, 28)).remainingDays, 1);
    expect(CalendarMonth(2000, 2).days, 29);
    expect(CalendarMonth(1900, 2).days, 28);
  });

  test('overspending remains visible with zero suggested allowance', () {
    final state = compute(entries: [expense('2026-10-17', 150001)]);
    expect(state.isOverspent, true);
    expect(state.remaining?.fen, -1);
    expect(state.dailyAllowance?.fen, 0);
  });

  test('unset and explicit zero budgets are distinct', () {
    final unset = compute(budget: null, entries: [expense('2026-10-17', 1)]);
    expect(unset.spent.fen, 1);
    expect(unset.remaining, isNull);
    expect(unset.dailyAllowance, isNull);
    expect(compute(budget: const Money.fromFen(0)).dailyAllowance?.fen, 0);
  });

  test('historical month totals all its days without a daily allowance', () {
    final state = compute(month: CalendarMonth(2026, 9), entries: [
      expense('2026-09-30', 1000), expense('2026-10-01', 2000, id: 'b'),
    ]);
    expect(state.spent.fen, 1000);
    expect(state.remainingDays, 0);
    expect(state.dailyAllowance, isNull);
  });

  test('future month shows plan and does not consume future records', () {
    final state = compute(month: CalendarMonth(2026, 11),
        entries: [expense('2026-11-01', 5000)]);
    expect(state.period, MonthPeriod.future);
    expect(state.remainingDays, 30);
    expect(state.spent.fen, 0);
    expect(state.dailyAllowance?.fen, 5000);
  });

  test('current month excludes future dates and income', () {
    final state = compute(entries: [
      expense('2026-10-17', 100), expense('2026-10-18', 200, id: 'b'),
      expense('2026-10-01', 300, id: 'c', kind: EntryKind.income),
      expense('2026-09-01', 400, id: 'd'),
    ]);
    expect(state.spent.fen, 100);
  });

  test('recomputing after edit, deletion, and month move updates totals', () {
    expect(compute(entries: [expense('2026-10-01', 61000)])
        .remaining?.fen, 89000);
    expect(compute().remaining?.fen, 150000);
    expect(compute(entries: [expense('2026-09-01', 60000)])
        .spent.fen, 0);
  });

  test('midnight and year rollover use the new local calendar day', () {
    expect(compute(day: DateTime(2026, 10, 18)).remainingDays, 14);
    final january = compute(month: CalendarMonth(2027, 1),
        day: DateTime(2027, 1, 1));
    expect(january.remainingDays, 31);
  });

  test('invalid dates and zero transactions are rejected', () {
    expect(() => parseCalendarDay('2026-02-29'), throwsFormatException);
    expect(() => parseCalendarDay('2026-13-01'), throwsFormatException);
    expect(() => expense('2026-10-17', 0), throwsArgumentError);
    expect(() => compute(budget: const Money.fromFen(-1)), throwsArgumentError);
  });
}
