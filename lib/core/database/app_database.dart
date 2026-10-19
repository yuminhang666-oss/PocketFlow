import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../contracts/pocketflow_exception.dart';
import 'tables.dart';
import '../domain/category_catalog.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    MonthlyBudgets,
    LedgerEntries,
    RecoverySnapshots,
    PersonalState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.local() : super(driftDatabase(name: 'pocketflow'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await _createLedgerIndex();
      await addDefaultCategories();
    }),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= 3 || to != 3) {
        throw const PocketFlowException(PocketFlowErrorCode.storageFailure);
      }
      // SQLite cannot change foreign_keys inside a transaction.
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        await transaction(() async {
          if (from == 1) {
            await customStatement(
              'DROP INDEX IF EXISTS ledger_entries_local_date',
            );
            // Copy without coercion or repair: invalid v1 rows abort the upgrade.
            await migrator.alterTable(
              TableMigration(
                categories,
                newColumns: [categories.categoryKind, categories.parentId],
              ),
            );
            await migrator.alterTable(TableMigration(monthlyBudgets));
            await migrator.alterTable(TableMigration(ledgerEntries));
            await migrator.createTable(recoverySnapshots);
            await _createLedgerIndex();
          } else {
            await migrator.addColumn(categories, categories.categoryKind);
            await migrator.addColumn(categories, categories.parentId);
          }
          await migrator.createTable(personalState);
          await addDefaultCategories();
          await _checkForeignKeys();
        });
      } catch (error) {
        throw PocketFlowException(
          PocketFlowErrorCode.dataCorrupted,
          cause: error,
        );
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final enabled = await customSelect('PRAGMA foreign_keys').getSingle();
      if (enabled.read<int>('foreign_keys') != 1) {
        throw const PocketFlowException(PocketFlowErrorCode.storageFailure);
      }
      await _checkForeignKeys();
    },
  );

  Future<void> addDefaultCategories() async {
    for (final c in recommendedCategories()) {
      await customInsert(
        'INSERT OR IGNORE INTO categories '
        '(id, name, sort_order, is_archived, category_kind, parent_id) VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(c.id),
          Variable.withString(c.name),
          Variable.withInt(c.sortOrder),
          Variable.withInt(0),
          Variable<String>(c.kind?.name),
          Variable<String>(c.parentId),
        ],
        updates: {categories},
      );
    }
  }

  Future<void> _createLedgerIndex() => customStatement(
    'CREATE INDEX ledger_entries_local_date '
    'ON ledger_entries(occurred_local, occurred_at_utc_ms, id)',
  );

  Future<void> _checkForeignKeys() async {
    if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
    }
  }
}
