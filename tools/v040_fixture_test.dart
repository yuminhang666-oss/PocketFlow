// Explicit synthetic design fixture. Never part of normal test discovery.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';

class _Clock implements Clock {
  DateTime value = DateTime(2026, 9, 1, 12);
  @override
  DateTime now() => value;
}

void main() {
  test('write explicitly synthetic v040 design ledger', () async {
    final path = Platform.environment['PF040_FIXTURE'];
    if (path == null || File(path).existsSync()) {
      throw StateError('Provide a new PF040_FIXTURE file.');
    }
    File(path).parent.createSync(recursive: true);
    final db = AppDatabase(NativeDatabase(File(path))), clock = _Clock();
    var serial = 0;
    final ledger = DriftLedgerRepository(
      db,
      clock: clock,
      idGenerator: () => 'pf040-synthetic-${serial++}',
    );
    final plans = DriftPlanningStore(db, clock: clock);
    try {
      await ledger.watchMonth(CalendarMonth(2026, 9)).first;
      await plans.saveRuleVersion(
        RecurringVersion(
          id: 'pf040-synthetic-version',
          ruleId: 'pf040-synthetic-rule',
          effectiveMonth: CalendarMonth(2026, 9),
          startMonth: CalendarMonth(2026, 9),
          kind: EntryKind.expense,
          categoryId: 'digital',
          amount: const Money.fromFen(3900),
          day: 5,
          note: 'SYNTHETIC 周期示例，未入账',
        ),
      );
      clock.value = DateTime(2026, 10, 26, 12);
      for (final m in [9, 10]) {
        await ledger.saveBudget(
          CalendarMonth(2026, m),
          const Money.fromFen(300000),
        );
      }
      final expenses = [
        ('2026-10-01', 10000, 'shopping', 'SYNTHETIC 日用品'),
        ('2026-10-05', 12000, 'food', 'SYNTHETIC 聚餐'),
        ('2026-10-08', 5000, 'transport', 'SYNTHETIC 出行'),
        ('2026-10-12', 4390, 'digital', 'SYNTHETIC 数字服务'),
        ('2026-10-15', 10510, 'study', 'SYNTHETIC 学习用品'),
        ('2026-10-19', 80000, 'living', 'SYNTHETIC 房租'),
        ('2026-10-20', 1990, 'drinks', 'SYNTHETIC 饮品'),
        ('2026-10-22', 3200, 'food', 'SYNTHETIC 午餐'),
        ('2026-10-26', 2800, 'food_canteen', 'SYNTHETIC 食堂午餐'),
        ('2026-10-26', 600, 'transport', 'SYNTHETIC 地铁往返'),
        ('2026-09-08', 3800, 'food', 'SYNTHETIC 历史支出'),
      ];
      for (final row in expenses) {
        await ledger.createExpense(
          EntryDraft(
            amount: Money.fromFen(row.$2),
            localDate: row.$1,
            occurredAtUtcMs: parseCalendarDay(row.$1).millisecondsSinceEpoch,
            categoryId: row.$3,
            note: row.$4,
          ),
        );
      }
      for (final row in [
        ('2026-10-01', 300000, 'income_family'),
        ('2026-10-25', 60000, 'income_labor'),
        ('2026-09-12', 250000, 'income_family'),
      ]) {
        await ledger.createIncome(
          EntryDraft(
            amount: Money.fromFen(row.$2),
            localDate: row.$1,
            occurredAtUtcMs: parseCalendarDay(row.$1).millisecondsSinceEpoch,
            categoryId: row.$3,
            note: 'SYNTHETIC 收入',
          ),
        );
      }
      await ledger.saveGoal(
        SavingsGoal(
          id: 'pf040-synthetic-goal',
          name: 'SYNTHETIC 旅行基金',
          target: const Money.fromFen(200000),
          saved: const Money.fromFen(80000),
        ),
      );
      await ledger.saveTemplate(
        EntryTemplate(
          id: 'pf040-synthetic-template',
          name: 'SYNTHETIC 午餐模板',
          kind: EntryKind.expense,
          categoryId: 'food_canteen',
          amount: const Money.fromFen(2800),
          note: 'SYNTHETIC 食堂午餐',
        ),
      );
      await plans.saveReminderSettings(
        const ReminderSettings(budget: false, weekly: false),
      );
      final month = await ledger.watchMonth(CalendarMonth(2026, 10)).first;
      expect(
        month.entries
            .where((e) => e.kind == EntryKind.expense)
            .fold<int>(0, (a, e) => a + e.amount.fen),
        130490,
      );
      expect(month.entries, hasLength(12));
    } finally {
      await db.close();
    }
  });
}
