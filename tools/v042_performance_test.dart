// Explicit synthetic benchmark. Not run by normal test/ discovery or the app.
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 28, 12);
}

class _Reads extends QueryInterceptor {
  int selects = 0, rows = 0;
  void reset() {
    selects = 0;
    rows = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    selects++;
    final result = await executor.runSelect(statement, args);
    rows += result.length;
    return result;
  }
}

void main() {
  test('measure 1k and 10k synthetic entries with 100 recurring rules', () async {
    final results = <Map<String, Object?>>[];
    for (final count in [1000, 10000]) {
      final reads = _Reads();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(reads));
      final ledger = DriftLedgerRepository(db, clock: _Clock());
      final store = DriftBackupStore(db, clock: _Clock());
      try {
        final categories = generalRecommendedCategories();
        final month = CalendarMonth(2026, 10);
        await store.replaceAll(
          BackupDocument(
            exportedAtUtcMs: 1,
            budgets: const [],
            categories: categories,
            entries: [
              for (var i = 0; i < count; i++)
                LedgerEntry(
                  id: 'SYNTHETIC-benchmark-$i',
                  amount: Money.fromFen(100 + i % 1000),
                  localDate:
                      '2026-10-${(i % 27 + 1).toString().padLeft(2, '0')}',
                  categoryId: 'food',
                  occurredAtUtcMs: i,
                  createdAtUtcMs: i,
                  updatedAtUtcMs: i,
                ),
            ],
            plans: PlanningData(
              catalogVersion: 1,
              rules: [
                for (var i = 0; i < 100; i++)
                  RecurringRule(id: 'rule-$i', createdAtUtcMs: 1),
              ],
              versions: [
                for (var i = 0; i < 100; i++)
                  RecurringVersion(
                    id: 'version-$i',
                    ruleId: 'rule-$i',
                    effectiveMonth: month,
                    startMonth: month,
                    kind: EntryKind.expense,
                    categoryId: 'food',
                    amount: const Money.fromFen(100),
                    day: 1,
                  ),
              ],
            ),
          ),
        );
        for (final action in ['monthSnapshot', 'saveCategory']) {
          final samples = <Map<String, int>>[];
          for (var i = 0; i < 10; i++) {
            reads.reset();
            final timer = Stopwatch()..start();
            if (action == 'monthSnapshot') {
              final data = await ledger.watchMonth(month).first;
              expect(data.entries.length, count);
            } else {
              await ledger.saveCategory(
                categories.firstWhere((c) => c.id == 'food'),
              );
            }
            timer.stop();
            if (i > 0) {
              samples.add({
                'us': timer.elapsedMicroseconds,
                'selects': reads.selects,
                'rows': reads.rows,
              });
            }
          }
          final times = samples.map((v) => v['us']!).toList()..sort();
          results.add({
            'entries': count,
            'rules': 100,
            'action': action,
            'warmup': 1,
            'samples': samples,
            'medianUs': times[times.length ~/ 2],
            'p95Us': times.last,
          });
        }
        expect((await store.readAll()).entries.length, count);
      } finally {
        await db.close();
      }
    }
    final output = {
      'host': Platform.operatingSystem,
      'mode': 'Flutter test VM / in-memory SQLite',
      'warning':
          'Host measurements are not handset frame/input latency. No storage optimization applied.',
      'results': results,
    };
    final path = Platform.environment['PF042_BENCHMARK_OUTPUT'];
    if (path == null) throw StateError('Set PF042_BENCHMARK_OUTPUT explicitly');
    File(path).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    );
    // ignore: avoid_print
    print('SYNTHETIC_V042_BENCHMARK ${jsonEncode(output)}');
  });
}
