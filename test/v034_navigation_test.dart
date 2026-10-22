import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/ledger_list/presentation/entry_details_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/statistics/presentation/statistics_page.dart';
import 'package:pocketflow/shared/widgets/entry_tile.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 21, 12);
}

void main() {
  testWidgets(
    'full ledger destination, detail edit/cancel/save, scroll and stats drill-down',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory()), clock = _Clock();
      final repo = DriftLedgerRepository(db, clock: clock);
      final plans = DriftPlanningStore(db, clock: clock);
      await tester.runAsync(() async {
        await repo.watchMonth(CalendarMonth(2026, 10)).first;
        for (var i = 0; i < 35; i++) {
          await repo.createExpense(
            EntryDraft(
              amount: Money.fromFen(100 + i),
              localDate: '2026-10-20',
              occurredAtUtcMs: 100 + i,
              categoryId: 'food',
              note: 'synthetic v034 $i',
            ),
          );
        }
      });
      Future<void> hit(Finder finder) async {
        await tester.tap(finder);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerRepositoryProvider.overrideWithValue(repo),
            backupStoreProvider.overrideWithValue(
              DriftBackupStore(db, clock: clock),
            ),
            planningPortProvider.overrideWithValue(plans),
            clockProvider.overrideWithValue(clock),
          ],
          child: const PocketFlowRoot(),
        ),
      );
      try {
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('查看全部'));
        await hit(find.text('查看全部'));
        expect(find.byType(LedgerListPage), findsOneWidget);
        expect(
          find.byType(BackButton),
          findsNothing,
          reason: 'full ledger is a bottom destination',
        );
        final listState = tester.state(find.byType(LedgerListPage));
        await tester.enterText(find.byType(TextField), 'synthetic');
        await tester.pump();
        final scroll = find
            .descendant(
              of: find.byType(LedgerListPage),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(scroll, const Offset(0, -450));
        await tester.pumpAndSettle();
        final position = tester.state<ScrollableState>(scroll).position.pixels;
        await hit(find.byType(EntryTile).first);
        await hit(find.text('编辑账单'));
        await hit(find.byIcon(Icons.arrow_back_rounded));
        expect(find.byType(EntryDetailsPage), findsOneWidget);
        await hit(find.text('编辑账单'));
        for (var i = 0; i < 12; i++) {
          await hit(find.byIcon(Icons.backspace_outlined));
        }
        await hit(find.widgetWithText(TextButton, '8'));
        await hit(find.text('保存修改'));
        expect(find.byType(EntryDetailsPage), findsOneWidget);
        expect(find.byType(QuickEntryPage), findsNothing);
        final shown = tester
            .widget<EntryDetailsPage>(find.byType(EntryDetailsPage))
            .entry;
        expect(shown.amount.fen, 800);
        final data = await tester.runAsync(
          () => repo.watchMonth(CalendarMonth(2026, 10)).first,
        );
        expect(
          data!.entries.singleWhere((e) => e.id == shown.id).amount,
          shown.amount,
        );
        await hit(find.text('编辑账单'));
        await hit(find.text('2026-10-20'));
        expect(find.byType(CalendarDatePicker), findsOneWidget);
        tester
            .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
            .onDateChanged(DateTime(2026, 9, 15));
        await tester.pump();
        await hit(find.text('确定'));
        await hit(find.text('保存修改'));
        expect(
          tester
              .widget<EntryDetailsPage>(find.byType(EntryDetailsPage))
              .entry
              .localDate,
          '2026-09-15',
        );
        expect(find.textContaining('来源列表仍保留原筛选条件'), findsOneWidget);
        final previous = await tester.runAsync(
          () => repo.watchMonth(CalendarMonth(2026, 9)).first,
        );
        expect(previous!.entries.single.id, shown.id);
        await hit(find.byType(BackButton).last);
        expect(tester.state(find.byType(LedgerListPage)), same(listState));
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          closeTo(position, 1),
        );
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'synthetic',
        );
        await hit(find.text('统计').last);
        expect(find.byType(StatisticsPage), findsOneWidget);
        final statsState = tester.state(find.byType(StatisticsPage));
        final category = find.text('餐饮').last;
        await tester.ensureVisible(category);
        await tester.pumpAndSettle();
        await hit(category);
        expect(find.text('筛选明细'), findsOneWidget);
        expect(find.text('分类：餐饮'), findsOneWidget);
        await hit(find.byType(BackButton).last);
        expect(tester.state(find.byType(StatisticsPage)), same(statsState));
        await hit(find.text('账单').last);
        expect(tester.state(find.byType(LedgerListPage)), same(listState));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'synthetic',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
  );
}
