// Explicit synthetic fixture generation; not part of normal test/ discovery.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 21, 12);
}

void main() {
  for (final count in [30, 10000]) {
    test('generate isolated $count-entry ledger', () async {
      final directory = Platform.environment['PF034_FIXTURE_DIR'];
      if (directory == null) {
        throw StateError('Explicit fixture directory required');
      }
      final file = File('$directory/synthetic-$count.sqlite');
      if (file.existsSync()) throw StateError('Preserving existing fixture');
      file.parent.createSync(recursive: true);
      final db = AppDatabase(NativeDatabase(file));
      var sequence = 0;
      final clock = _Clock(),
          repo = DriftLedgerRepository(
            db,
            clock: _Clock(),
            idGenerator: () => 'pf034-synthetic-${sequence++}',
          );
      try {
        await repo.watchMonth(CalendarMonth(2026, 10)).first;
        for (final month in [9, 10]) {
          await repo.saveBudget(
            CalendarMonth(2026, month),
            const Money.fromFen(50000000),
          );
        }
        await db.transaction(() async {
          for (var i = 0; i < count; i++) {
            final month = i.isEven ? '10' : '09',
                day = (i % 20 + 1).toString().padLeft(2, '0');
            await repo.createExpense(
              EntryDraft(
                amount: Money.fromFen(100 + i % 4000),
                localDate: '2026-$month-$day',
                occurredAtUtcMs: DateTime(
                  2026,
                  int.parse(month),
                  int.parse(day),
                  12,
                ).millisecondsSinceEpoch,
                categoryId: ['food', 'transport', 'shopping', 'fun'][i % 4],
                note: 'PF034 synthetic record $i',
              ),
            );
          }
        });
        final port = DriftPlanningStore(db, clock: clock);
        await port.saveReminderSettings(
          const ReminderSettings(budget: false, weekly: false),
        );
        expect(
          (await repo.watchMonth(CalendarMonth(2026, 10)).first).entries.length,
          count ~/ 2,
        );
        expect(
          (await repo.watchMonth(CalendarMonth(2026, 9)).first).entries.length,
          count ~/ 2,
        );
      } finally {
        await db.close();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
