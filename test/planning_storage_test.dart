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
import 'package:pocketflow/core/domain/category_catalog.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/transactions/data/recovery_codec.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';

class _Clock implements Clock {
  DateTime value = DateTime(2026, 10, 10, 12);
  @override
  DateTime now() => value;
}

class _Old3 extends GeneratedDatabase {
  _Old3(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final sql in File(
        'test/fixtures/v3_schema.sql',
      ).readAsStringSync().split(';')) {
        if (sql.trim().isNotEmpty) await customStatement(sql);
      }
    },
  );
}

EntryDraft _draft(
  int fen, {
  String category = 'food',
  String date = '2026-10-10',
}) => EntryDraft(
  amount: Money.fromFen(fen),
  localDate: date,
  occurredAtUtcMs: 100,
  categoryId: category,
  note: 'SYNTHETIC',
);
RecurringVersion _version({
  String id = 'v1',
  String rule = 'rule',
  int month = 10,
  int day = 5,
  int fen = 3900,
  String category = 'food',
  String note = 'SYNTHETIC v1',
}) => RecurringVersion(
  id: id,
  ruleId: rule,
  effectiveMonth: CalendarMonth(2026, month),
  startMonth: CalendarMonth(2026, 10),
  kind: EntryKind.expense,
  categoryId: category,
  amount: Money.fromFen(fen),
  day: day,
  note: note,
);

void main() {
  late AppDatabase db;
  late _Clock clock;
  late DriftLedgerRepository ledger;
  late DriftPlanningStore plans;
  late DriftBackupStore backup;
  setUp(() {
    clock = _Clock();
    db = AppDatabase(NativeDatabase.memory());
    ledger = DriftLedgerRepository(db, clock: clock);
    plans = DriftPlanningStore(db, clock: clock);
    backup = DriftBackupStore(db, clock: clock);
  });
  tearDown(() => db.close());
  test(
    'classification budgets are plans and total budget can be cleared independently',
    () async {
      final month = CalendarMonth(2026, 10);
      await ledger.saveBudget(month, const Money.fromFen(150000));
      for (final item in {
        'food': 60000,
        'shopping': 30000,
        'transport': 20000,
      }.entries) {
        await plans.saveCategoryBudget(
          CategoryBudget(
            month: month,
            categoryId: item.key,
            amount: Money.fromFen(item.value),
          ),
        );
      }
      await ledger.createExpense(_draft(12000));
      await ledger.createExpense(_draft(8000, category: 'food_canteen'));
      final data = await ledger.watchMonth(month).first;
      expect(data.categoryBudgets.length, 3);
      expect(
        const BudgetCalculator()
            .calculate(
              month: month,
              today: clock.now(),
              budget: data.budget!.amount,
              entries: data.entries,
            )
            .remaining!
            .fen,
        130000,
      );
      await plans.clearBudget(month);
      final cleared = await ledger.watchMonth(month).first;
      expect(cleared.budget, isNull);
      expect(cleared.entries.length, 2);
      expect(cleared.categoryBudgets.length, 3);
      await ledger.saveBudget(month, const Money.fromFen(0));
      expect((await ledger.watchMonth(month).first).budget!.amount.fen, 0);
    },
  );
  test(
    'period confirmations are idempotent; all version fields stay immutable',
    () async {
      final v1 = _version();
      await plans.saveRuleVersion(v1);
      final results = await Future.wait([
        plans.confirm(
          PendingOccurrence(v1, CalendarMonth(2026, 10)),
          actualAmount: const Money.fromFen(3900),
        ),
        plans.confirm(
          PendingOccurrence(v1, CalendarMonth(2026, 10)),
          actualAmount: const Money.fromFen(3900),
        ),
      ]);
      expect(results[0].id, results[1].id);
      expect((await backup.readAll()).entries.length, 1);
      final v2 = _version(
        id: 'v2',
        month: 11,
        fen: 4900,
        category: 'drinks',
        note: 'SYNTHETIC v2',
      );
      await plans.saveRuleVersion(v2);
      final p = (await backup.readAll()).plans;
      expect(
        p.versionFor('rule', CalendarMonth(2026, 10))!.note,
        'SYNTHETIC v1',
      );
      expect(p.versionFor('rule', CalendarMonth(2026, 10))!.categoryId, 'food');
      expect(p.versionFor('rule', CalendarMonth(2026, 11))!.amount.fen, 4900);
      await expectLater(
        plans.undoCreate(results[0]),
        throwsA(isA<PocketFlowException>()),
      );
      await ledger.deleteEntry(results[0].id);
      expect(
        (await backup.readAll()).plans.occurrences.single.status,
        OccurrenceStatus.skipped,
      );
      await plans.reopen('rule', CalendarMonth(2026, 10));
      expect((await backup.readAll()).plans.occurrences, isEmpty);
    },
  );
  test(
    'same-millisecond edit prevents undo and future settlement is refused',
    () async {
      final e = await ledger.createExpense(_draft(100));
      await ledger.updateExpense(e.id, _draft(200));
      await expectLater(
        plans.undoCreate(e),
        throwsA(isA<PocketFlowException>()),
      );
      final next = await ledger.createExpense(_draft(100));
      await plans.undoCreate(next);
      expect((await backup.readAll()).entries.single.amount.fen, 200);
      final v = _version(day: 31);
      await plans.saveRuleVersion(v);
      await expectLater(
        plans.confirm(
          PendingOccurrence(v, CalendarMonth(2026, 10)),
          actualAmount: v.amount,
        ),
        throwsA(isA<PocketFlowException>()),
      );
      expect(v.dueDate(CalendarMonth(2028, 2)), '2028-02-29');
      expect(v.dueDate(CalendarMonth(2028, 3)), '2028-03-31');
    },
  );
  test('quota survives restore, clock rollback and settings changes', () async {
    final month = CalendarMonth(2026, 10);
    await ledger.saveBudget(month, const Money.fromFen(150000));
    await ledger.createExpense(_draft(80000));
    final old = await backup.readAll();
    expect(await plans.reserveBudgetNotice(month), isTrue);
    expect(await plans.reserveBudgetNotice(month), isFalse);
    clock.value = DateTime(2026, 10, 16, 12);
    await ledger.createExpense(_draft(40000, date: '2026-10-16'));
    expect(await plans.reserveBudgetNotice(month), isFalse);
    clock.value = DateTime(2026, 10, 17, 12);
    expect(await plans.reserveBudgetNotice(month), isTrue);
    await backup.replaceAll(old);
    await ledger.createExpense(_draft(90000));
    clock.value = DateTime(2026, 10, 25, 12);
    expect(await plans.reserveBudgetNotice(month), isFalse);
    clock.value = DateTime(2026, 10, 10, 12);
    expect(await plans.reserveBudgetNotice(month), isFalse);
    await plans.saveReminderSettings(const ReminderSettings(budget: false));
    await plans.saveReminderSettings(const ReminderSettings());
    expect(await plans.reserveBudgetNotice(month), isFalse);
  });
  test(
    'v3 restores plans and bounds recovery; old backup empties only financial plans',
    () async {
      const codec = JsonBackupCodec();
      await plans.saveRuleVersion(_version());
      final snapshot = await backup.readAll();
      final imported = codec.decode(codec.encode(snapshot));
      expect(imported.plans.versions.single.amount.fen, 3900);
      await db.customInsert(
        "INSERT INTO device_states(key,payload) VALUES ('test','{\"kept\":true}')",
      );
      await db.customInsert(
        "INSERT INTO feedback_draft_rows(id,payload) VALUES ('test','{}')",
      );
      for (var i = 0; i < 5; i++) {
        clock.value = clock.value.add(const Duration(seconds: 1));
        await backup.replaceAll(imported);
      }
      expect((await plans.recoveryPoints()).length, 3);
      final raw = jsonDecode(codec.encode(imported)) as Map<String, dynamic>;
      raw['formatVersion'] = 2;
      raw.remove('planning');
      final old = codec.decode(jsonEncode(raw));
      expect(old.sourceFormatVersion, 2);
      await backup.replaceAll(old);
      expect((await backup.readAll()).plans.rules, isEmpty);
      expect((await db.select(db.deviceStates).get()).single.key, 'test');
      expect((await db.select(db.feedbackDraftRows).get()).single.id, 'test');
      expect(
        const RecoveryCodec()
            .decode(const RecoveryCodec().encode(imported))
            .plans
            .versions
            .length,
        1,
      );
    },
  );
  test(
    'failed restore rolls back plans, ledger, recovery creation and pruning',
    () async {
      await plans.saveRuleVersion(_version());
      await ledger.createExpense(_draft(100));
      const codec = JsonBackupCodec();
      final snapshot = await backup.readAll();
      await backup.replaceAll(snapshot);
      final before = codec.encode(await backup.readAll()),
          points = (await plans.recoveryPoints()).map((p) => p.id).toList();
      await db.customStatement(
        "CREATE TRIGGER fail_plan BEFORE INSERT ON plan_versions BEGIN SELECT RAISE(ABORT,'SYNTHETIC failure'); END",
      );
      await expectLater(
        backup.replaceAll(snapshot),
        throwsA(isA<PocketFlowException>()),
      );
      expect(codec.encode(await backup.readAll()), before);
      expect((await plans.recoveryPoints()).map((p) => p.id).toList(), points);
    },
  );
  test(
    'real captured schema3 upgrades unchanged entries; failure rolls back metadata',
    () async {
      final dir = await Directory.systemTemp.createTemp('pf-v3-synthetic-');
      final opened = <GeneratedDatabase>[];
      try {
        for (final inject in [false, true]) {
          final file = File(
                '${dir.path}/${inject ? 'failure' : 'success'}.sqlite',
              ),
              old = _Old3(
                NativeDatabase(
                  File('${dir.path}/${inject ? 'failure' : 'success'}.sqlite'),
                ),
              );
          opened.add(old);
          for (final c in recommendedCategories()) {
            await old.customStatement(
              'INSERT INTO categories(id,name,sort_order,is_archived,category_kind,parent_id) VALUES (?,?,?,0,?,?)',
              [c.id, c.name, c.sortOrder, c.kind?.name, c.parentId],
            );
          }
          for (var i = 0; i < 30; i++) {
            await old.customStatement(
              "INSERT INTO ledger_entries VALUES (?,1234,'expense','2026-10-01',100,'food','SYNTHETIC',100,100)",
              ['synthetic-$i'],
            );
          }
          for (final month in ['2026-08', '2026-09', '2026-10']) {
            await old.customStatement(
              'INSERT INTO monthly_budgets VALUES (?,150000,100)',
              [month],
            );
          }
          await old.customStatement(
            "INSERT INTO personal_state VALUES ('profile',?)",
            [jsonEncode(PersonalProfile(theme: 'dark').toJson())],
          );
          if (inject) {
            await old.customStatement(
              "CREATE TRIGGER fail_catalog BEFORE UPDATE ON categories BEGIN SELECT RAISE(ABORT,'SYNTHETIC migration'); END",
            );
          }
          await old.close();
          final upgraded = AppDatabase(NativeDatabase(file));
          opened.add(upgraded);
          if (inject) {
            await expectLater(
              upgraded.customSelect('SELECT * FROM categories').get(),
              throwsA(anything),
            );
            await upgraded.close();
            final verify = _Old3(NativeDatabase(file));
            opened.add(verify);
            expect(
              (await verify.customSelect('PRAGMA user_version').getSingle())
                  .read<int>('user_version'),
              3,
            );
            expect(
              (await verify.customSelect('SELECT * FROM categories').get())
                  .length,
              87,
            );
            expect(
              (await verify.customSelect('SELECT * FROM ledger_entries').get())
                  .length,
              30,
            );
            await verify.close();
          } else {
            final doc = await DriftBackupStore(
              upgraded,
              clock: clock,
            ).readAll();
            expect(doc.entries.length, 30);
            expect(
              doc.entries.every(
                (e) =>
                    e.amount.fen == 1234 &&
                    e.createdAtUtcMs == 100 &&
                    e.updatedAtUtcMs == 100 &&
                    e.categoryId == 'food',
              ),
              isTrue,
            );
            expect(doc.budgets.length, 3);
            expect(doc.profile.theme, 'dark');
            expect(
              doc.categories
                  .firstWhere((c) => c.id == 'income_tutoring')
                  .isArchived,
              isTrue,
            );
            await upgraded.close();
          }
        }
      } finally {
        for (final connection in opened) {
          try {
            await connection.close();
          } catch (_) {}
        }
        await dir.delete(recursive: true);
      }
    },
  );
}
