import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/reminders/domain/budget_notice_policy.dart';
import 'package:pocketflow/features/reports/domain/range_report_service.dart';

LedgerEntry entry(
  String id,
  int fen, {
  EntryKind kind = EntryKind.expense,
  String category = 'food',
  String date = '2026-10-18',
  int time = 100,
}) => LedgerEntry(
  id: id,
  amount: Money.fromFen(fen),
  localDate: date,
  categoryId: category,
  kind: kind,
  note: 'SYNTHETIC',
  occurredAtUtcMs: time,
  createdAtUtcMs: 100,
  updatedAtUtcMs: 100,
);
void main() {
  const policy = BudgetNoticePolicy(), reports = RangeReportService();
  final month = CalendarMonth(2026, 10);
  test(
    'specified integer speed thresholds, zero/null and over-budget day two',
    () {
      BudgetNoticeKind? qualify(
        int day,
        int spent, {
        Money? budget = const Money.fromFen(150000),
      }) => policy.qualify(
        month: month,
        now: DateTime(2026, 10, day),
        budget: budget,
        spentFen: spent,
      );
      expect(qualify(10, 80000), BudgetNoticeKind.fast);
      expect(qualify(10, 45000), isNull);
      expect(qualify(2, 80000), isNull);
      expect(qualify(2, 150001), BudgetNoticeKind.over);
      expect(
        qualify(10, 1, budget: const Money.fromFen(0)),
        BudgetNoticeKind.zero,
      );
      expect(qualify(10, 1, budget: null), isNull);
      expect(
        policy.qualify(
          month: CalendarMonth(2026, 9),
          now: DateTime(2026, 10, 10),
          budget: const Money.fromFen(1),
          spentFen: 100,
        ),
        isNull,
      );
      expect(
        policy.qualify(
          month: CalendarMonth(2028, 2),
          now: DateTime(2028, 2, 10),
          budget: const Money.fromFen(150000),
          spentFen: 80000,
        ),
        BudgetNoticeKind.fast,
      );
    },
  );
  test(
    'second slot requires seven calendar days and minimum growth, never a third',
    () {
      bool eligible(int day, int spent, {int count = 1, bool mute = false}) =>
          policy.canReserve(
            now: DateTime(2026, 10, day, 12),
            budgetFen: 150000,
            spentFen: spent,
            count: count,
            lastDate: '2026-10-10',
            lastUtcMs: DateTime(2026, 10, 10, 12).millisecondsSinceEpoch,
            lastSpentFen: 80000,
            muted: mute,
          );
      expect(eligible(16, 120000), isFalse);
      expect(eligible(17, 94999), isFalse);
      expect(eligible(17, 95000), isTrue);
      expect(eligible(24, 999999, count: 2), isFalse);
      expect(eligible(17, 120000, mute: true), isFalse);
      expect(eligible(9, 120000), isFalse);
    },
  );
  test('weekly 08:00, cross-month/year and exact thirty-day expiry', () {
    expect(reports.latestWeeklyRange(DateTime(2026, 10, 19, 7, 59)), isNull);
    expect(reports.latestWeeklyRange(DateTime(2026, 10, 19, 8)), (
      '2026-10-12',
      '2026-10-18',
    ));
    expect(reports.latestWeeklyRange(DateTime(2026, 10, 21)), (
      '2026-10-12',
      '2026-10-18',
    ));
    expect(reports.latestWeeklyRange(DateTime(2026, 11, 2, 8)), (
      '2026-10-26',
      '2026-11-01',
    ));
    expect(reports.latestWeeklyRange(DateTime(2027, 1, 4, 8)), (
      '2026-12-28',
      '2027-01-03',
    ));
    expect(reports.retained('2026-10-18', DateTime(2026, 11, 17)), isTrue);
    expect(reports.retained('2026-10-18', DateTime(2026, 11, 18)), isFalse);
  });
  test(
    'complete daily totals precede five-entry preview and separate income',
    () {
      final entries = [
        for (var i = 0; i < 6; i++) entry('expense$i', i == 5 ? 5000 : 1000),
        entry(
          'income1',
          10000,
          kind: EntryKind.income,
          category: 'income_family',
        ),
        entry(
          'income2',
          10000,
          kind: EntryKind.income,
          category: 'income_family',
        ),
      ];
      final total = fullDailyTotals(entries).single;
      expect(total.expense.fen, 10000);
      expect(total.income.fen, 20000);
      expect(total.count, 8);
      expect(entries.take(5).length, 5);
    },
  );
  test(
    'root direct and child amounts sum once; ties use time then stable ID',
    () {
      final entries = [
        entry('b', 12000, time: 200),
        entry('a', 12000, time: 200),
        entry('child', 8000, category: 'food_canteen', date: '2026-10-17'),
        entry(
          'income',
          100000,
          kind: EntryKind.income,
          category: 'income_family',
        ),
      ];
      final report = reports.build(
        LedgerRangeData(
          start: '2026-10-12',
          end: '2026-10-18',
          entries: entries,
          categories: generalRecommendedCategories(),
          revision: 'synthetic',
        ),
        now: DateTime(2026, 10, 19),
      );
      expect(report.expense.fen, 32000);
      expect(report.income.fen, 100000);
      expect(report.categories.single.amount.fen, 32000);
      expect(report.categories.single.directAmount.fen, 24000);
      expect(report.categories.single.children['food_canteen']!.fen, 8000);
      expect(report.largestExpense!.id, 'a');
      expect(report.largestTieCount, 2);
      expect(report.daily.fold<int>(0, (a, b) => a + b.expense.fen), 32000);
    },
  );
  test(
    'income-only and empty reports remain inspectable without invented spending',
    () {
      for (final records in [
        <LedgerEntry>[],
        [
          entry(
            'income',
            10000,
            kind: EntryKind.income,
            category: 'income_family',
            date: '2026-10-01',
          ),
        ],
      ]) {
        final report = reports.build(
          LedgerRangeData(
            start: '2026-09-28',
            end: '2026-10-04',
            entries: records,
            categories: generalRecommendedCategories(),
            revision: 'synthetic',
          ),
          now: DateTime(2026, 10, 19),
        );
        expect(report.expense.fen, 0);
        expect(report.categories, isEmpty);
        expect(report.largestExpense, isNull);
        expect(report.daily.length, 7);
      }
    },
  );
}
