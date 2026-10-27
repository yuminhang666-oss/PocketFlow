import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/app/routing/pocketflow_shell.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/category_catalog.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/home/presentation/home_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_calendar_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';
import 'package:pocketflow/features/statistics/domain/monthly_report_service.dart';
import 'package:pocketflow/features/statistics/presentation/statistics_page.dart';
import 'package:pocketflow/features/statistics/presentation/fl_chart_widgets.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

void _screen(WidgetTester tester, Size size, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  final month = CalendarMonth(2026, 10), categories = recommendedCategories();
  final expense = LedgerEntry(
    id: 'e',
    amount: const Money.fromFen(1234),
    localDate: '2026-10-17',
    categoryId: 'food_canteen',
    kind: EntryKind.expense,
    note: 'Fixture lunch',
    occurredAtUtcMs: 100,
    createdAtUtcMs: 100,
    updatedAtUtcMs: 100,
  );
  final income = LedgerEntry(
    id: 'i',
    amount: const Money.fromFen(20000),
    localDate: '2026-10-16',
    categoryId: 'income_tutoring_english',
    kind: EntryKind.income,
    occurredAtUtcMs: 99,
    createdAtUtcMs: 99,
    updatedAtUtcMs: 99,
  );
  final data = LedgerMonthData(
    month: month,
    budget: MonthlyBudget(
      month: month,
      amount: const Money.fromFen(150000),
      updatedAtUtcMs: 100,
    ),
    entries: [expense, income],
    categories: categories,
  );
  final report = DefaultMonthlyReportService(
    clock: _Clock(),
  ).build(data, asOfLocalDate: '2026-10-17');
  testWidgets('budget plot avoids duplicate labels at padded boundaries', (
    tester,
  ) async {
    _screen(tester, const Size(412, 915), 1);
    await tester.pumpWidget(
      PocketFlowApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemainingBudgetLines(report: report),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1.5千元'), findsOneWidget);
    expect(find.text('-38'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('editor controls reachable at $size, scale $scale', (
        tester,
      ) async {
        _screen(tester, size, scale);
        EntryDraft? saved;
        await tester.pumpWidget(
          PocketFlowApp(
            home: QuickEntryPage(
              categories: categories,
              clock: _Clock(),
              onSave: (draft) async {
                saved = draft;
                return expense;
              },
              onSaveIncome: (draft) async => income,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (scale == 1 && size.height >= 640) {
          final grid = find.byKey(const ValueKey('category-grid-expense'));
          final keypad = find.widgetWithText(TextButton, '1');
          expect(
            tester.getRect(grid).bottom,
            lessThanOrEqualTo(tester.getRect(keypad).top),
            reason:
                'The visible quick category row must fit above the keypad on a normal phone',
          );
        }
        final zero = find.widgetWithText(TextButton, '0'),
            dot = find.widgetWithText(TextButton, '.'),
            save = find.text('保存支出');
        for (final control in [zero, dot, save]) {
          if (scale == 2) {
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
          }
          final bounds = tester.getRect(control);
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          expect(control.hitTestable(), findsOneWidget);
        }
        final one = find.widgetWithText(TextButton, '1');
        await tester.ensureVisible(one);
        await tester.tap(one);
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(of: save, matching: find.byType(FilledButton)),
              )
              .onPressed,
          isNotNull,
        );
        expect(saved, isNull);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pump();
        expect(saved?.amount.fen, 100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('four destinations and content at 360x640, scale $scale', (
      tester,
    ) async {
      _screen(tester, const Size(360, 640), scale);
      final snapshot = BudgetSnapshot(
        month: month,
        period: MonthPeriod.current,
        budget: data.budget!.amount,
        spent: report.totalExpense,
        remaining: report.remaining,
        remainingDays: 15,
        dailyAllowance: const Money.fromFen(9917),
      );
      await tester.pumpWidget(
        PocketFlowApp(
          home: PocketFlowShell(
            onAdd: () {},
            home: HomePage(
              month: month,
              state: AsyncData((data, snapshot)),
              report: report,
              todayKey: '2026-10-17',
            ),
            ledger: LedgerListPage(
              data: data,
              query: const DefaultLedgerQueryService(),
              asOfLocalDate: '2026-10-17',
            ),
            statistics: StatisticsPage(
              month: month,
              state: AsyncData(data),
              clock: _Clock(),
            ),
            settings: const Scaffold(body: Text('我的设置')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['账单', '统计', '我的', '总览']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(find.text('＋记账').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('收入分析'));
      await tester.pumpAndSettle();
      expect(find.text('收入分析').hitTestable(), findsOneWidget);
      await tester.tap(find.text('收入分析'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text('收入分析'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('预算趋势'));
      await tester.pumpAndSettle();
      expect(find.text('预算趋势').hitTestable(), findsOneWidget);
      await tester.tap(find.text('预算趋势'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('calendar distinguishes days at 360x640, scale $scale', (
      tester,
    ) async {
      _screen(tester, const Size(360, 640), scale);
      await tester.pumpWidget(
        PocketFlowApp(
          home: LedgerCalendarPage(
            data: data,
            view: const DefaultLedgerQueryService().filter(
              data,
              const LedgerFilter(),
              asOfLocalDate: '2026-10-17',
            ),
            today: '2026-10-17',
            onOpenDay: (_) {},
            onMarkZero: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
