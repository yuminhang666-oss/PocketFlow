import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../contracts/pocketflow_exception.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Categories, MonthlyBudgets, LedgerEntries, RecoverySnapshots],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  AppDatabase.local() : super(driftDatabase(name: 'pocketflow'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => transaction(() async {
          await migrator.createAll();
          await _createLedgerIndex();
          const names = {
            'food': '餐饮',
            'drinks': '饮品',
            'shopping': '购物',
            'transport': '交通',
            'study': '学习',
            'fun': '娱乐',
            'health': '医疗',
            'other': '其他',
          };
          var order = 0;
          for (final entry in names.entries) {
            await into(categories).insert(CategoriesCompanion.insert(
              id: entry.key,
              name: entry.value,
              sortOrder: Value(order++),
            ));
          }
        }),
        onUpgrade: (migrator, from, to) async {
          if (from != 1 || to != 2) {
            throw const PocketFlowException(PocketFlowErrorCode.storageFailure);
          }
          // SQLite cannot change foreign_keys inside a transaction.
          await customStatement('PRAGMA foreign_keys = OFF');
          try {
            await transaction(() async {
              await customStatement('DROP INDEX IF EXISTS ledger_entries_local_date');
              // Copy without coercion or repair: invalid v1 rows abort the upgrade.
              await migrator.alterTable(TableMigration(categories));
              await migrator.alterTable(TableMigration(monthlyBudgets));
              await migrator.alterTable(TableMigration(ledgerEntries));
              await migrator.createTable(recoverySnapshots);
              await _createLedgerIndex();
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
