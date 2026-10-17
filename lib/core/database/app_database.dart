import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Categories, MonthlyBudgets, LedgerEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  AppDatabase.local() : super(driftDatabase(name: 'pocketflow'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await customStatement('CREATE INDEX ledger_entries_local_date '
              'ON ledger_entries(occurred_local, occurred_at_utc_ms)');
          const names = {
            'food': '餐饮', 'drinks': '饮品', 'shopping': '购物',
            'transport': '交通', 'study': '学习', 'fun': '娱乐',
            'health': '医疗', 'other': '其他',
          };
          var order = 0;
          for (final entry in names.entries) {
            await into(categories).insert(CategoriesCompanion.insert(
              id: entry.key,
              name: entry.value,
              sortOrder: Value(order++),
            ));
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
