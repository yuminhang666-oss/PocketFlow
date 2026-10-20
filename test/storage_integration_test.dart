import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

class _V1Database extends GeneratedDatabase {
  _V1Database(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      final sql = File('test/fixtures/v1_schema.sql').readAsStringSync();
      for (final statement in sql.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
    },
  );
}

void main() {
  test(
    'actual Drift v1 to v3 migration preserves fields, budget and foreign keys',
    () async {
      final dir = await Directory.systemTemp.createTemp('pocketflow-migrate-');
      final file = File('${dir.path}/ledger.sqlite');
      final old = _V1Database(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO categories(id,name) VALUES ('food','餐饮')",
      );
      await old.customStatement(
        "INSERT INTO monthly_budgets VALUES ('2026-10',150000,100)",
      );
      await old.customStatement(
        "INSERT INTO ledger_entries VALUES ('old',3000,'expense','2026-10-17',100,'food','原备注',100,100)",
      );
      await old.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        final rows = await db.select(db.ledgerEntries).get();
        expect(rows.single.amountFen, 3000);
        expect(rows.single.note, '原备注');
        expect(
          (await db.select(db.monthlyBudgets).get()).single.amountFen,
          150000,
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          4,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(await db.select(db.recoverySnapshots).get(), isEmpty);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'failed restore after deletes rolls back old records and recovery write',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftLedgerRepository(db, clock: _Clock());
      final store = DriftBackupStore(db, clock: _Clock());
      final month = CalendarMonth(2026, 10);
      try {
        await repo.saveBudget(month, const Money.fromFen(150000));
        final original = await repo.createExpense(
          EntryDraft(
            amount: const Money.fromFen(3000),
            localDate: '2026-10-17',
            occurredAtUtcMs: 100,
            categoryId: 'food',
          ),
        );
        final backup = await store.readAll();
        await db.customStatement(
          "CREATE TRIGGER reject_restore BEFORE INSERT ON ledger_entries BEGIN SELECT RAISE(ABORT, 'test failure'); END",
        );
        await expectLater(
          store.replaceAll(backup),
          throwsA(isA<PocketFlowException>()),
        );
        final data = await repo.watchMonth(month).first;
        expect(data.entries.single.id, original.id);
        expect(data.entries.single.amount.fen, 3000);
        expect(await db.select(db.recoverySnapshots).get(), isEmpty);
      } finally {
        await db.close();
      }
    },
  );
}
