import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/home/presentation/home_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_calendar_page.dart';
import 'package:pocketflow/features/settings/presentation/settings_page.dart';
import 'package:pocketflow/features/reports/presentation/reports_page.dart';
import 'package:pocketflow/features/reports/presentation/report_content.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 27, 7);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'history queries, ordinary entry, templates, calendar batch and tab resets keep dates separate',
    (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final clock = _Clock(), db = AppDatabase(NativeDatabase.memory());
      final ledger = DriftLedgerRepository(db, clock: clock),
          plans = DriftPlanningStore(db, clock: clock);
      await t.runAsync(() async {
        await ledger.saveBudget(
          CalendarMonth(2026, 10),
          const Money.fromFen(300000),
        );
        await ledger.createExpense(
          EntryDraft(
            amount: const Money.fromFen(3800),
            localDate: '2026-09-08',
            occurredAtUtcMs: 1,
            categoryId: 'food',
            note: '历史测试',
          ),
        );
        await ledger.saveTemplate(
          EntryTemplate(
            id: 'synthetic-template',
            name: '测试午餐模板',
            kind: EntryKind.expense,
            amount: const Money.fromFen(2800),
            categoryId: 'food',
            note: '模板备注',
          ),
        );
      });
      await t.pumpWidget(
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
      Future<void> hit(Finder f, {bool reveal = false}) async {
        expect(f, findsOneWidget);
        if (reveal) {
          await t.ensureVisible(f);
          await t.pumpAndSettle();
        }
        await t.tap(f);
        await settle(t);
      }

      Future<void> template() async {
        await hit(find.byTooltip('更多'));
        await hit(find.text('使用模板'));
        await hit(find.text('测试午餐模板'));
      }

      try {
        await settle(t);
        await hit(find.text('账单').last);
        await hit(find.text('2026年10月 ▾'));
        await hit(find.text('9月'));
        expect(
          t.widget<LedgerListPage>(find.byType(LedgerListPage)).month,
          CalendarMonth(2026, 9),
        );
        expect(
          t.widget<HomePage>(find.byType(HomePage, skipOffstage: false)).month,
          CalendarMonth(2026, 10),
        );
        await hit(find.text('＋记账'));
        expect(
          t.widget<QuickEntryPage>(find.byType(QuickEntryPage)).initialDate,
          '2026-10-27',
        );
        await hit(find.widgetWithText(TextButton, '1'));
        await template();
        expect(find.text('用模板替换当前输入？'), findsOneWidget);
        await hit(find.text('取消'));
        expect(find.text('¥ 1'), findsOneWidget);
        await template();
        await hit(find.text('确认替换'));
        await hit(find.text('保存支出'));
        final month = await t.runAsync(
          () => ledger.watchMonth(CalendarMonth(2026, 10)).first,
        );
        expect(month!.entries.single.localDate, '2026-10-27');
        expect(month.entries.single.amount.fen, 2800);
        expect(
          t.widget<LedgerListPage>(find.byType(LedgerListPage)).month,
          CalendarMonth(2026, 9),
        );
        await hit(find.text('日历'));
        await hit(find.byKey(const ValueKey('day-2026-09-08')), reveal: true);
        await hit(find.text('补记这一天'), reveal: true);
        expect(
          t.widget<QuickEntryPage>(find.byType(QuickEntryPage)).initialDate,
          '2026-09-08',
        );
        await template();
        expect(find.text('发生日期 2026-09-08 · 补记'), findsOneWidget);
        await hit(find.text('保存并继续'));
        await hit(find.widgetWithText(TextButton, '2'));
        await hit(find.text('保存支出'));
        expect(find.byType(LedgerCalendarPage), findsOneWidget);
        final historical = await t.runAsync(
          () => ledger.watchMonth(CalendarMonth(2026, 9)).first,
        );
        expect(historical!.entries, hasLength(3));
        expect(
          historical.entries.every((e) => e.localDate == '2026-09-08'),
          isTrue,
        );
        await hit(find.text('总览').last);
        await hit(find.text('本月账单'), reveal: true);
        expect(
          t.widget<LedgerListPage>(find.byType(LedgerListPage)).month,
          CalendarMonth(2026, 10),
        );
        expect(find.byType(LedgerCalendarPage), findsNothing);
        await hit(find.byTooltip('搜索与筛选'));
        await t.enterText(find.byType(TextField), '没有匹配的词');
        await settle(t);
        await hit(find.text('总览').last);
        await hit(find.text('记账日历'), reveal: true);
        expect(find.byType(LedgerCalendarPage), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await hit(find.byTooltip('搜索与筛选'));
        expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await hit(find.text('＋记账'));
        expect(
          t.widget<QuickEntryPage>(find.byType(QuickEntryPage)).initialDate,
          '2026-10-27',
        );
        await hit(find.byIcon(Icons.arrow_back_rounded));
        await hit(find.text('统计').last);
        await hit(find.text('账单').last);
        expect(find.byType(LedgerCalendarPage), findsNothing);
        await hit(find.text('总览').last);
        await hit(find.text('更多'), reveal: true);
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        await t.runAsync(db.close);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  testWidgets(
    'report tabs show the requested week and ongoing month from one range snapshot',
    (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory()), clock = _Clock();
      final ledger = DriftLedgerRepository(db, clock: clock),
          plans = DriftPlanningStore(db, clock: clock);
      await t.runAsync(
        () => ledger.createExpense(
          EntryDraft(
            amount: const Money.fromFen(80000),
            localDate: '2026-10-19',
            occurredAtUtcMs: 1,
            categoryId: 'living',
          ),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: ReportsPage(
            port: plans,
            clock: clock,
            initialStart: '2026-10-19',
            initialEnd: '2026-10-25',
          ),
        ),
      );
      try {
        await settle(t);
        expect(
          t
              .widget<ReportContent>(find.byType(ReportContent))
              .report
              .expense
              .fen,
          80000,
        );
        expect(find.text('2026-10-19 — 2026-10-25'), findsOneWidget);
        await t.tap(find.text('月报'));
        await settle(t);
        expect(find.text('2026-10-01 — 2026-10-27'), findsOneWidget);
        expect(
          t.widget<ReportContent>(find.byType(ReportContent)).monthly,
          isTrue,
        );
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        await t.runAsync(db.close);
      }
    },
  );
}
