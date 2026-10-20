import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/reports/domain/range_report_service.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 12, 31, 12);
}

void main() {
  test(
    'SYNTHETIC five years / 10000 entries: query, report and backup round trip',
    () async {
      final db = AppDatabase(NativeDatabase.memory()), clock = _Clock();
      final backup = DriftBackupStore(db, clock: clock),
          ledger = DriftLedgerRepository(db, clock: clock),
          plans = DriftPlanningStore(db, clock: clock);
      final times = <String, int>{}, rssBefore = ProcessInfo.currentRss;
      Future<T> measure<T>(String name, Future<T> Function() action) async {
        final watch = Stopwatch()..start();
        final value = await action();
        times[name] = watch.elapsedMicroseconds;
        return value;
      }

      try {
        final entries = [
          for (var i = 0; i < 10000; i++)
            LedgerEntry(
              id: 'synthetic-scale-$i',
              amount: Money.fromFen(100 + i % 9999),
              localDate: calendarDayKey(
                DateTime.utc(2022, 1, 1).add(Duration(days: i % 1826)),
              ),
              categoryId: i % 4 == 0 ? 'income_work' : 'food',
              kind: i % 4 == 0 ? EntryKind.income : EntryKind.expense,
              note: 'SYNTHETIC performance fixture $i',
              occurredAtUtcMs: i,
              createdAtUtcMs: i,
              updatedAtUtcMs: i,
            ),
        ];
        await measure(
          'initial_replace_us',
          () => backup.replaceAll(
            BackupDocument(
              exportedAtUtcMs: 100,
              budgets: const [],
              categories: generalRecommendedCategories(),
              entries: entries,
              plans: PlanningData(catalogVersion: 1),
            ),
          ),
        );
        final month = await measure(
          'month_query_us',
          () => ledger.watchMonth(CalendarMonth(2026, 10)).first,
        );
        final range = await measure(
          'week_query_us',
          () => plans.watchRange('2026-09-28', '2026-10-04').first,
        );
        final report = await measure(
          'week_aggregation_us',
          () async => const RangeReportService().build(range, now: clock.now()),
        );
        expect(
          report.expense.fen,
          range.entries
              .where((e) => e.kind == EntryKind.expense)
              .fold<int>(0, (a, e) => a + e.amount.fen),
        );
        expect(month.entries, isNotEmpty);
        final full = await measure('full_snapshot_us', backup.readAll);
        final encoded = await measure(
          'json_encode_us',
          () async => const JsonBackupCodec().encode(full),
        );
        final decoded = await measure(
          'json_decode_validate_us',
          () async => const JsonBackupCodec().decode(encoded),
        );
        await measure('restore_us', () => backup.replaceAll(decoded));
        final restored = await backup.readAll();
        expect(restored.entries.length, 10000);
        expect(
          restored.entries.map((e) => e.id).toSet(),
          entries.map((e) => e.id).toSet(),
        );
        expect((await plans.recoveryPoints()).length, 2);
        // Host test-runner process memory includes Flutter engine and test VM;
        // this is not presented as an Android handset memory measurement.
        // ignore: avoid_print
        print(
          'SYNTHETIC_SCALE ${jsonEncode({'entries': 10000, 'years': 5, 'host': Platform.operatingSystem, 'mode': 'Flutter test VM / in-memory SQLite', 'timings_microseconds': times, 'json_bytes': utf8.encode(encoded).length, 'rss_before_bytes': rssBefore, 'rss_after_bytes': ProcessInfo.currentRss, 'process_peak_rss_bytes': ProcessInfo.maxRss})}',
        );
      } finally {
        await db.close();
      }
    },
  );
}
