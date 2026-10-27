import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/transactions/data/recovery_codec.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';
import 'package:pocketflow/features/reports/domain/range_report_service.dart';
import 'package:pocketflow/shared/widgets/entry_tile.dart';

class _Clock implements Clock {
  DateTime value = DateTime(2026, 9, 1, 12);
  @override
  DateTime now() => value;
}

void main() {
  late AppDatabase db;
  late _Clock clock;
  late DriftLedgerRepository ledger;
  late DriftPlanningStore plans;
  late DriftBackupStore backup;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = _Clock();
    ledger = DriftLedgerRepository(db, clock: clock);
    plans = DriftPlanningStore(db, clock: clock);
    backup = DriftBackupStore(db, clock: clock);
  });
  tearDown(() => db.close());
  RecurringVersion version({EntryKind kind = EntryKind.expense, int day = 5}) =>
      RecurringVersion(
        id: 'synthetic-v040-v',
        ruleId: 'synthetic-v040-rule',
        effectiveMonth: CalendarMonth(2026, 9),
        startMonth: CalendarMonth(2026, 9),
        kind: kind,
        categoryId: kind == EntryKind.income ? 'income_work' : 'food',
        amount: const Money.fromFen(2800),
        day: day,
      );

  test(
    'cross-month confirmation is atomic and idempotent with actual date',
    () async {
      final v = version();
      await plans.saveRuleVersion(v);
      clock.value = DateTime(2026, 10, 26, 12);
      await ledger.saveBudget(
        CalendarMonth(2026, 10),
        const Money.fromFen(300000),
      );
      final pending = PendingOccurrence(v, CalendarMonth(2026, 9));
      final results = await Future.wait([
        plans.confirm(
          pending,
          actualAmount: const Money.fromFen(3200),
          actualLocalDate: '2026-10-26',
        ),
        plans.confirm(
          pending,
          actualAmount: const Money.fromFen(9999),
          actualLocalDate: '2026-09-05',
        ),
      ]);
      expect(results[0].id, results[1].id);
      final all = await backup.readAll();
      expect(all.entries, hasLength(1));
      expect(all.entries.single.localDate, '2026-10-26');
      expect(all.entries.single.amount.fen, 3200);
      expect(all.plans.occurrences.single.actualLocalDate, '2026-10-26');
      final october = await ledger.watchMonth(CalendarMonth(2026, 10)).first;
      final september = await ledger.watchMonth(CalendarMonth(2026, 9)).first;
      expect(september.entries, isEmpty);
      expect(
        const BudgetCalculator()
            .calculate(
              month: october.month,
              today: clock.now(),
              budget: october.budget!.amount,
              entries: october.entries,
            )
            .remaining!
            .fen,
        296800,
      );
      final encoded = const JsonBackupCodec().encode(all);
      final decoded = const JsonBackupCodec().decode(encoded);
      await backup.replaceAll(decoded);
      expect(
        (await backup.readAll()).plans.occurrences.single.actualLocalDate,
        '2026-10-26',
      );
      expect(
        (await plans.confirm(
          pending,
          actualAmount: const Money.fromFen(100),
        )).id,
        results[0].id,
      );
      final recovered = const RecoveryCodec().decode(
        const RecoveryCodec().encode(all),
      );
      expect(recovered.plans.occurrences.single.actualLocalDate, '2026-10-26');
      final changed = jsonDecode(encoded) as Map<String, dynamic>;
      (changed['planning']['occurrences'] as List).single['actualLocalDate'] =
          '2026-10-25';
      expect(
        () => const JsonBackupCodec().decode(jsonEncode(changed)),
        throwsA(isA<PocketFlowException>()),
      );
    },
  );
  test(
    'future due or actual date cannot bypass pending confirmation',
    () async {
      final v = version(day: 31);
      await plans.saveRuleVersion(v);
      clock.value = DateTime(2026, 10, 26);
      await expectLater(
        plans.confirm(
          PendingOccurrence(v, CalendarMonth(2026, 10)),
          actualAmount: v.amount,
          actualLocalDate: '2026-10-25',
        ),
        throwsA(isA<PocketFlowException>()),
      );
      await expectLater(
        plans.confirm(
          PendingOccurrence(v, CalendarMonth(2026, 9)),
          actualAmount: v.amount,
          actualLocalDate: '2026-10-27',
        ),
        throwsA(isA<PocketFlowException>()),
      );
      expect((await backup.readAll()).entries, isEmpty);
    },
  );
  test('income confirmation never increases the living budget', () async {
    final v = version(kind: EntryKind.income);
    await plans.saveRuleVersion(v);
    clock.value = DateTime(2026, 10, 26);
    await ledger.saveBudget(
      CalendarMonth(2026, 10),
      const Money.fromFen(300000),
    );
    await plans.confirm(
      PendingOccurrence(v, CalendarMonth(2026, 9)),
      actualAmount: const Money.fromFen(100000),
      actualLocalDate: '2026-10-26',
    );
    final data = await ledger.watchMonth(CalendarMonth(2026, 10)).first;
    expect(
      const BudgetCalculator()
          .calculate(
            month: data.month,
            today: clock.now(),
            budget: data.budget!.amount,
            entries: data.entries,
          )
          .remaining!
          .fen,
      300000,
    );
  });
  test(
    'legacy due-date occurrence, delete, skip and reopen preserve consistency',
    () async {
      final v = version();
      await plans.saveRuleVersion(v);
      clock.value = DateTime(2026, 10, 26);
      final pending = PendingOccurrence(v, CalendarMonth(2026, 9));
      final entry = await plans.confirm(pending, actualAmount: v.amount);
      final raw =
          jsonDecode(const JsonBackupCodec().encode(await backup.readAll()))
              as Map<String, dynamic>;
      (raw['planning']['occurrences'] as List).single.remove('actualLocalDate');
      await backup.replaceAll(const JsonBackupCodec().decode(jsonEncode(raw)));
      expect(
        (await plans.confirm(pending, actualAmount: v.amount)).localDate,
        '2026-09-05',
      );
      await ledger.deleteEntry(entry.id);
      expect(
        (await backup.readAll()).plans.occurrences.single.status,
        OccurrenceStatus.skipped,
      );
      await plans.reopen(v.ruleId, CalendarMonth(2026, 9));
      await plans.skip(pending);
      expect((await backup.readAll()).entries, isEmpty);
      await plans.reopen(v.ruleId, CalendarMonth(2026, 9));
      final next = await plans.confirm(
        pending,
        actualAmount: v.amount,
        actualLocalDate: '2026-10-26',
      );
      expect(next.localDate, '2026-10-26');
      expect(
        const JsonBackupCodec()
            .decode(const JsonBackupCodec().encode(await backup.readAll()))
            .entries,
        hasLength(1),
      );
    },
  );
  test(
    'custom root color survives rename order archive preferences JSON and recovery',
    () async {
      const color = 0xFFC46891;
      await ledger.saveCategory(
        Category(
          id: 'synthetic-custom',
          name: '测试分类',
          sortOrder: 900,
          kind: EntryKind.expense,
          colorValue: color,
        ),
      );
      await ledger.saveCategory(
        Category(
          id: 'synthetic-child',
          name: '测试子类',
          sortOrder: 901,
          parentId: 'synthetic-custom',
          kind: EntryKind.expense,
        ),
      );
      await ledger.saveCategory(
        Category(
          id: 'synthetic-custom',
          name: '改名',
          sortOrder: 2,
          kind: EntryKind.expense,
          isArchived: true,
        ),
      );
      await ledger.savePreferences(theme: 'dark', locale: 'en');
      final data = await ledger.watchMonth(CalendarMonth(2026, 9)).first;
      expect(
        categoryColor('synthetic-child', data.categories),
        const Color(color),
      );
      expect(
        data.categories
            .singleWhere((c) => c.id == 'synthetic-custom')
            .isArchived,
        isTrue,
      );
      final all = await backup.readAll();
      await backup.replaceAll(
        const JsonBackupCodec().decode(const JsonBackupCodec().encode(all)),
      );
      final reopened = await DriftLedgerRepository(
        db,
        clock: clock,
      ).watchMonth(CalendarMonth(2026, 9)).first;
      expect(
        categoryColor('synthetic-custom', reopened.categories),
        const Color(color),
      );
      expect(reopened.profile.categoryColors, {'synthetic-custom': color});
      expect(
        const RecoveryCodec()
            .decode(const RecoveryCodec().encode(all))
            .profile
            .categoryColors,
        all.profile.categoryColors,
      );
      final old = all.profile.toJson()..remove('categoryColors');
      expect(PersonalProfile.fromJson(old).categoryColors, isEmpty);
      expect(categoryColor('food'), const Color(0xFFE77A2C));
      expect(categoryColor('transport'), const Color(0xFF327BCB));
      expect(categoryColor('work'), const Color(0xFF596DB0));
    },
  );
  test(
    'goal increments retain original order and never create a ledger entry',
    () async {
      for (final id in ['first', 'second']) {
        await ledger.saveGoal(
          SavingsGoal(
            id: id,
            name: id,
            target: const Money.fromFen(10000),
            saved: const Money.fromFen(0),
          ),
        );
      }
      await ledger.saveGoal(
        SavingsGoal(
          id: 'first',
          name: 'first',
          target: const Money.fromFen(10000),
          saved: const Money.fromFen(12000),
        ),
      );
      final all = await backup.readAll();
      expect(all.profile.goals.map((g) => g.id), ['first', 'second']);
      expect(all.profile.goals.first.saved.fen, 12000);
      expect(all.entries, isEmpty);
      expect(all.budgets, isEmpty);
    },
  );
  test(
    'design weekly fixture aggregates exact totals, category shares and conservative allowance',
    () {
      clock.value = DateTime(2026, 10, 26);
      final categories = [
        Category(id: 'living', name: '居住生活', sortOrder: 0),
        Category(id: 'food', name: '餐饮', sortOrder: 1),
        Category(id: 'drinks', name: '饮品', sortOrder: 2),
        Category(
          id: 'income_work',
          name: '收入',
          sortOrder: 3,
          kind: EntryKind.income,
        ),
      ];
      final values = [
        ('living', 80000, '2026-10-19'),
        ('drinks', 1990, '2026-10-20'),
        ('food', 3200, '2026-10-22'),
        ('income_work', 60000, '2026-10-25'),
      ];
      final entries = [
        for (var i = 0; i < values.length; i++)
          LedgerEntry(
            id: 'synthetic-$i',
            amount: Money.fromFen(values[i].$2),
            localDate: values[i].$3,
            categoryId: values[i].$1,
            kind: i == 3 ? EntryKind.income : EntryKind.expense,
            occurredAtUtcMs: i,
            createdAtUtcMs: i,
            updatedAtUtcMs: i,
          ),
      ];
      final report = const RangeReportService().build(
        LedgerRangeData(
          start: '2026-10-19',
          end: '2026-10-25',
          entries: entries,
          categories: categories,
          revision: 'fixture',
        ),
        now: clock.now(),
      );
      expect(report.expense.fen, 85190);
      expect(report.income.fen, 60000);
      expect(report.net.fen, -25190);
      expect(
        report.categories.map(
          (c) => (c.amount.fen / report.expense.fen * 100).toStringAsFixed(1),
        ),
        ['93.9', '3.8', '2.3'],
      );
      final snapshot = const BudgetCalculator().calculate(
        month: CalendarMonth(2026, 10),
        today: clock.now(),
        budget: const Money.fromFen(169510),
        entries: [],
      );
      expect(snapshot.remainingDays, 6);
      expect(snapshot.dailyAllowance!.fen, 28251);
    },
  );
}
