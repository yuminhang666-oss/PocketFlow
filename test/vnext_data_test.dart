import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart'
    show
        GeneratedDatabase,
        TableInfo,
        Table,
        DatabaseSchemaEntity,
        MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';
import 'package:pocketflow/features/statistics/domain/monthly_report_service.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/recovery_codec.dart';
import 'package:pocketflow/shared/widgets/entry_tile.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

class _V2Database extends GeneratedDatabase {
  _V2Database(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      // v2's persisted column layout; the Android update test also uses the actual 0.1.1 database.
      for (final statement in File(
        'test/fixtures/v1_schema.sql',
      ).readAsStringSync().split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
      await customStatement(
        'CREATE TABLE recovery_snapshots(id TEXT NOT NULL PRIMARY KEY,created_at_utc_ms INTEGER NOT NULL,payload TEXT NOT NULL)',
      );
    },
  );
}

EntryDraft _draft(
  int fen,
  String category, {
  String date = '2026-10-17',
  String note = '',
}) => EntryDraft(
  amount: Money.fromFen(fen),
  localDate: date,
  categoryId: category,
  note: note,
  occurredAtUtcMs: DateTime(2026, 10, 17, 12).millisecondsSinceEpoch,
);

void main() {
  final month = CalendarMonth(2026, 10);
  const codec = JsonBackupCodec();
  late AppDatabase db;
  late DriftLedgerRepository repo;
  late DriftBackupStore store;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLedgerRepository(db, clock: _Clock());
    store = DriftBackupStore(db, clock: _Clock());
  });
  tearDown(() async => db.close());
  Future<LedgerMonthData> read() => repo.watchMonth(month).first;
  test(
    'income create/edit/delete remains separate from spending and budget',
    () async {
      await repo.saveBudget(month, const Money.fromFen(100000));
      await repo.createExpense(_draft(3000, 'food_canteen'));
      final income = await repo.createIncome(
        _draft(20000, 'income_labor_general_1'),
      );
      Future<void> verify(int expectedIncome) async {
        final data = await read();
        final report = DefaultMonthlyReportService(
          clock: _Clock(),
        ).build(data, asOfLocalDate: '2026-10-17');
        final budget = const BudgetCalculator().calculate(
          month: month,
          today: _Clock().now(),
          budget: data.budget!.amount,
          entries: data.entries,
        );
        expect(report.totalExpense.fen, 3000);
        expect(report.totalIncome.fen, expectedIncome);
        expect(report.netFlow.fen, expectedIncome - 3000);
        expect(report.remaining!.fen, 97000);
        expect(budget.remaining!.fen, 97000);
        expect(budget.dailyAllowance!.fen, 6466);
        expect(
          report.dailyIncome.fold<int>(0, (s, d) => s + d.amount.fen),
          expectedIncome,
        );
        expect(
          report.incomeCategoryTotals.fold<int>(0, (s, c) => s + c.amount.fen),
          expectedIncome,
        );
      }

      await verify(20000);
      final edited = await repo.updateIncome(
        income.id,
        _draft(25000, 'income_labor_general_2', note: 'fixture income'),
      );
      expect(edited.kind, EntryKind.income);
      expect(edited.createdAtUtcMs, income.createdAtUtcMs);
      await verify(25000);
      await expectLater(
        repo.updateExpense(income.id, _draft(1, 'food')),
        throwsA(isA<PocketFlowException>()),
      );
      await expectLater(
        repo.createIncome(_draft(100, 'food')),
        throwsA(isA<PocketFlowException>()),
      );
      await expectLater(
        repo.createExpense(_draft(100, 'income_family')),
        throwsA(isA<PocketFlowException>()),
      );
      await repo.deleteEntry(income.id);
      await verify(0);
    },
  );
  test(
    'filters combine note, hierarchy, kind, date, amount and cutoff with exact day totals',
    () async {
      await repo.createExpense(
        _draft(1200, 'food_canteen', date: '2026-10-16', note: 'Lunch fixture'),
      );
      await repo.createExpense(
        _draft(1800, 'food_takeaway', note: 'Lunch delivery'),
      );
      await repo.createExpense(_draft(1500, 'drinks_coffee'));
      await repo.createIncome(
        _draft(20000, 'income_labor_general_1', note: 'English fixture'),
      );
      final data = await read();
      const query = DefaultLedgerQueryService();
      final all = query.filter(
        data,
        const LedgerFilter(),
        asOfLocalDate: '2026-10-17',
      );
      expect(all.expense.fen, 4500);
      expect(all.income.fen, 20000);
      expect(all.netFlow.fen, 15500);
      expect(all.days['2026-10-17']!.expense.fen, 3300);
      expect(all.days['2026-10-17']!.count, 3);
      final filtered = query.filter(
        data,
        const LedgerFilter(
          query: 'lunch',
          kind: EntryKind.expense,
          categoryId: 'food',
          fromDate: '2026-10-17',
          toDate: '2026-10-17',
          minFen: 1500,
          maxFen: 2000,
        ),
        asOfLocalDate: '2026-10-17',
      );
      expect(filtered.entries.single.categoryId, 'food_takeaway');
      expect(filtered.expense.fen, 1800);
      final cutoff = query.filter(
        data,
        const LedgerFilter(),
        asOfLocalDate: '2026-10-16',
      );
      expect(cutoff.entries.length, 1);
      expect(cutoff.expense.fen, 1200);
      expect(cutoff.income.fen, 0);
      expect(
        categoryColor('food_canteen', data.categories),
        categoryColor('food_takeaway', data.categories),
      );
      expect(
        categoryColor('food_canteen', data.categories),
        categoryColor('food_canteen', data.categories.reversed.toList()),
      );
    },
  );
  test(
    'zero spending is explicit and removed when creating or moving expenses onto that day',
    () async {
      await repo.markZeroExpenseDay('2026-10-16', true);
      expect((await read()).profile.zeroExpenseDays, ['2026-10-16']);
      await repo.createIncome(
        _draft(10000, 'income_family', date: '2026-10-16'),
      );
      expect((await read()).profile.zeroExpenseDays, ['2026-10-16']);
      final expense = await repo.createExpense(
        _draft(100, 'food', date: '2026-10-16'),
      );
      expect((await read()).profile.zeroExpenseDays, isEmpty);
      await expectLater(
        repo.markZeroExpenseDay('2026-10-16', true),
        throwsA(isA<PocketFlowException>()),
      );
      await repo.markZeroExpenseDay('2026-10-15', true);
      await repo.updateExpense(
        expense.id,
        _draft(200, 'food', date: '2026-10-15'),
      );
      expect((await read()).profile.zeroExpenseDays, isEmpty);
      await expectLater(
        repo.markZeroExpenseDay('2026-10-18', true),
        throwsA(isA<PocketFlowException>()),
      );
    },
  );
  test(
    'v1 backup retains income and amounts; v2 profile and metadata restore atomically',
    () async {
      final v1 = codec.decode(
        File(
          'lib/features/backup/examples/fixture-backup-v1.json',
        ).readAsStringSync(),
      );
      expect(v1.profile.theme, 'system');
      expect(v1.profile.goals, isEmpty);
      expect(v1.entries.where((e) => e.kind == EntryKind.income), isNotEmpty);
      expect(
        v1.categories.every((c) => c.kind == null && c.parentId == null),
        isTrue,
      );
      final roundTrip = codec.decode(codec.encode(v1));
      expect(
        roundTrip.entries.map((e) => e.amount.fen),
        v1.entries.map((e) => e.amount.fen),
      );
      await repo.savePreferences(theme: 'dark', feedback: false);
      await repo.saveGoal(
        SavingsGoal(
          id: 'fixture-goal',
          name: 'Fixture goal',
          target: const Money.fromFen(100000),
          saved: const Money.fromFen(5000),
        ),
      );
      await repo.saveTemplate(
        EntryTemplate(
          id: 'fixture-template',
          name: 'Fixture tutoring',
          kind: EntryKind.income,
          amount: const Money.fromFen(20000),
          categoryId: 'income_labor_general_1',
        ),
      );
      await repo.createIncome(_draft(20000, 'income_labor_general_1'));
      await repo.markZeroExpenseDay('2026-10-15', true);
      final snapshot = await store.readAll(), encoded = codec.encode(snapshot);
      expect((jsonDecode(encoded) as Map)['formatVersion'], 3);
      final imported = codec.decode(encoded);
      expect(imported.profile.goals.single.saved.fen, 5000);
      expect(imported.profile.templates.single.kind, EntryKind.income);
      expect(
        imported.categories
            .firstWhere((c) => c.id == 'income_labor_general_1')
            .parentId,
        'income_labor',
      );
      await repo.savePreferences(theme: 'light');
      await repo.deleteGoal('fixture-goal');
      final result = await store.replaceAll(imported);
      final data = await read();
      expect(data.profile.theme, 'dark');
      expect(data.profile.feedback, isFalse);
      expect(data.profile.goals.single.name, 'Fixture goal');
      expect(data.profile.zeroExpenseDays, ['2026-10-15']);
      expect(
        (await store.readRecovery(result.recoveryBackupId)).profile.theme,
        'light',
      );
      final before = codec.encode(await store.readAll());
      await db.customStatement(
        "CREATE TRIGGER block_profile BEFORE INSERT ON personal_state BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
      );
      await expectLater(
        store.replaceAll(imported),
        throwsA(isA<PocketFlowException>()),
      );
      expect(codec.encode(await store.readAll()), before);
      final bad = jsonDecode(encoded) as Map<String, dynamic>;
      bad['profile']['templates'][0]['categoryId'] = 'missing';
      expect(
        () => codec.decode(jsonEncode(bad)),
        throwsA(isA<PocketFlowException>()),
      );
      bad['formatVersion'] = 4;
      expect(
        () => codec.decode(jsonEncode(bad)),
        throwsA(isA<PocketFlowException>()),
      );
    },
  );
  test(
    'category archive preserves history and recommendation refill respects edits',
    () async {
      final entry = await repo.createExpense(_draft(1200, 'food_canteen'));
      final old = (await read()).categories.firstWhere((c) => c.id == 'food');
      await repo.saveCategory(
        Category(
          id: old.id,
          name: '我的餐饮',
          sortOrder: old.sortOrder,
          isArchived: true,
          kind: old.kind,
        ),
      );
      await repo.addRecommendedCategories();
      final data = await read();
      expect(data.categories.firstWhere((c) => c.id == 'food').name, '我的餐饮');
      expect(
        data.categories.firstWhere((c) => c.id == 'food').isArchived,
        isTrue,
      );
      expect(data.entries.single.id, entry.id);
      await expectLater(
        repo.createExpense(_draft(1200, 'food_canteen')),
        throwsA(isA<PocketFlowException>()),
      );
      await repo.updateExpense(entry.id, _draft(1300, 'food_canteen'));
      await expectLater(
        repo.saveCategory(
          Category(
            id: 'cycle',
            name: '坏分类',
            sortOrder: 0,
            kind: EntryKind.expense,
            parentId: 'cycle',
          ),
        ),
        throwsA(isA<PocketFlowException>()),
      );
      await expectLater(
        repo.saveCategory(
          Category(
            id: 'orphan',
            name: '坏分类',
            sortOrder: 0,
            kind: EntryKind.income,
            parentId: 'food',
          ),
        ),
        throwsA(isA<PocketFlowException>()),
      );
      expect(
        (await read()).categories.length,
        generalRecommendedCategories().length,
      );
    },
  );
  test(
    'v2-shaped database migrates to v3 preserving renamed archived categories, income, audit and recovery',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'pocketflow-v2-upgrade-',
      );
      final file = File('${dir.path}/ledger.sqlite');
      final old = _V2Database(NativeDatabase(file));
      final recovery = jsonEncode({
        'recoveryVersion': 1,
        'exportedAtUtcMs': 100,
        'categories': [
          ['food', '原餐饮', 8, true],
        ],
        'budgets': [
          ['2026-10', 50000, 100],
        ],
        'entries': [
          [
            'expense-old',
            1234,
            '2026-10-16',
            'food',
            'expense',
            '原备注',
            99,
            98,
            100,
          ],
        ],
      });
      await old.customStatement(
        "INSERT INTO categories VALUES ('food','原餐饮',8,1)",
      );
      await old.customStatement(
        "INSERT INTO monthly_budgets VALUES ('2026-10',50000,100)",
      );
      await old.customStatement(
        "INSERT INTO ledger_entries VALUES ('expense-old',1234,'expense','2026-10-16',99,'food','原备注',98,100)",
      );
      await old.customStatement(
        "INSERT INTO ledger_entries VALUES ('income-old',5000,'income','2026-10-17',101,'food','原收入',100,101)",
      );
      await old.customStatement(
        "INSERT INTO recovery_snapshots VALUES ('recovery-old',100,?)",
        [recovery],
      );
      await old.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final upgradeRepo = DriftLedgerRepository(upgraded, clock: _Clock()),
            upgradeStore = DriftBackupStore(upgraded, clock: _Clock());
        final data = await upgradeRepo.watchMonth(month).first;
        expect(data.entries.map((e) => e.id).toSet(), {
          'income-old',
          'expense-old',
        });
        expect(data.budget!.amount.fen, 50000);
        final saved = data.entries.firstWhere((e) => e.id == 'expense-old');
        expect(
          [
            saved.amount.fen,
            saved.createdAtUtcMs,
            saved.updatedAtUtcMs,
            saved.occurredAtUtcMs,
          ],
          [1234, 98, 100, 99],
        );
        expect(saved.localDate, '2026-10-16');
        expect(saved.note, '原备注');
        final cat = data.categories.firstWhere((c) => c.id == 'food');
        expect(cat.name, '原餐饮');
        expect(cat.isArchived, isTrue);
        expect(cat.kind, isNull);
        expect(data.categories.length, generalRecommendedCategories().length);
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          4,
        );
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await upgradeStore.readRecovery(
            'recovery-old',
          )).entries.single.amount.fen,
          1234,
        );
        expect(const RecoveryCodec().decode(recovery).profile.theme, 'system');
      } finally {
        await upgraded.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'preferences, goals, templates and zero day survive a database restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('pocketflow-profile-');
      final file = File('${dir.path}/ledger.sqlite');
      var disk = AppDatabase(NativeDatabase(file));
      try {
        final r = DriftLedgerRepository(disk, clock: _Clock());
        await r.savePreferences(theme: 'dark', feedback: false);
        await r.saveGoal(
          SavingsGoal(
            id: 'g',
            name: 'Test',
            target: const Money.fromFen(20000),
            saved: const Money.fromFen(5000),
          ),
        );
        await r.saveTemplate(
          EntryTemplate(
            id: 't',
            name: 'Test',
            kind: EntryKind.expense,
            amount: const Money.fromFen(1000),
            categoryId: 'food',
          ),
        );
        await r.markZeroExpenseDay('2026-10-15', true);
        await disk.close();
        disk = AppDatabase(NativeDatabase(file));
        final data = await DriftLedgerRepository(
          disk,
          clock: _Clock(),
        ).watchMonth(month).first;
        expect(data.profile.theme, 'dark');
        expect(data.profile.feedback, isFalse);
        expect(data.profile.goals.single.saved.fen, 5000);
        expect(data.profile.templates.single.amount.fen, 1000);
        expect(data.profile.zeroExpenseDays, ['2026-10-15']);
        expect(data.budget, isNull);
        expect(data.entries, isEmpty);
      } finally {
        await disk.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
