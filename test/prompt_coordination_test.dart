import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 19, 12);
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'weekly takes priority; duplicate resumed cannot reset session; next foreground may show budget',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory()), clock = _Clock();
      final ledger = DriftLedgerRepository(db, clock: clock),
          plans = DriftPlanningStore(db, clock: clock);
      await tester.runAsync(() async {
        await ledger.saveBudget(
          CalendarMonth(2026, 10),
          const Money.fromFen(1000),
        );
        await ledger.createExpense(
          EntryDraft(
            amount: const Money.fromFen(2000),
            localDate: '2026-10-12',
            occurredAtUtcMs: 100,
            categoryId: 'food',
            note: 'SYNTHETIC reminder coordination',
          ),
        );
      });
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ledgerRepositoryProvider.overrideWithValue(ledger),
              backupStoreProvider.overrideWithValue(
                DriftBackupStore(db, clock: clock),
              ),
              planningPortProvider.overrideWithValue(plans),
              clockProvider.overrideWithValue(clock),
            ],
            child: const PocketFlowRoot(),
          ),
        );
        await _frames(tester);
        expect(find.text('上周收支回顾已准备好'), findsOneWidget);
        expect(find.text('预算进度提醒'), findsNothing);
        await tester.tap(find.text('稍后再看'));
        await _frames(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _frames(tester);
        expect(find.text('预算进度提醒'), findsNothing);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await _frames(tester);
        expect(find.text('上周收支回顾已准备好'), findsNothing);
        expect(find.text('预算进度提醒'), findsOneWidget);
        await tester.tap(find.text('知道了'));
        await _frames(tester);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
        await tester.runAsync(
          () => db.close().timeout(const Duration(seconds: 3)),
        );
      }
    },
  );
}
