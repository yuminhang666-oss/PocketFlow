import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/home/presentation/widgets/daily_allowance_panel.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_calendar_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';
import 'package:pocketflow/features/statistics/domain/report_arithmetic.dart';
import 'package:pocketflow/shared/widgets/entry_tile.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 27);
}

void screen(WidgetTester t) {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  final categories = generalRecommendedCategories();
  final data = LedgerMonthData(
    month: CalendarMonth(2026, 10),
    budget: null,
    categories: categories,
    entries: [
      for (var i = 0; i < 6; i++)
        LedgerEntry(
          id: 'synthetic-$i',
          amount: Money.fromFen(100 * (i + 1)),
          localDate: '2026-10-26',
          categoryId: 'food',
          occurredAtUtcMs: i,
          createdAtUtcMs: i,
          updatedAtUtcMs: i,
          note: 'SYNTHETIC $i',
        ),
    ],
  );
  testWidgets(
    'bill first screen gives records priority and filters remain shared',
    (t) async {
      screen(t);
      await t.pumpWidget(
        PocketFlowApp(
          home: LedgerListPage(
            data: data,
            query: const DefaultLedgerQueryService(),
            asOfLocalDate: '2026-10-27',
            onMarkZero: (_, _) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byType(EntryTile).hitTestable().evaluate().length,
        greaterThanOrEqualTo(4),
      );
      await t.tap(find.byTooltip('搜索与筛选'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'SYNTHETIC 5');
      await t.pumpAndSettle();
      expect(find.text('当前范围共 1 笔'), findsOneWidget);
      await t.tap(find.byTooltip('搜索与筛选'));
      await t.pumpAndSettle();
      expect(find.text('SYNTHETIC 5'), findsWidgets);
      expect(find.text('清除筛选'), findsOneWidget);
      await t.tap(find.text('日历'));
      await t.pumpAndSettle();
      expect(find.byType(LedgerCalendarPage), findsOneWidget);
      expect(find.text('当前范围共 1 笔'), findsOneWidget);
      await t.tap(find.text('清除筛选'));
      await t.pumpAndSettle();
      expect(find.text('当前范围共 6 笔'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar selection brings the day detail into view at 360 by 640',
    (t) async {
      screen(t);
      await t.pumpWidget(
        PocketFlowApp(
          home: LedgerCalendarPage(
            data: data,
            view: const DefaultLedgerQueryService().filter(
              data,
              const LedgerFilter(),
              asOfLocalDate: '2026-10-27',
            ),
            today: '2026-10-27',
            onOpenDay: (_) {},
            onMarkZero: (_, _) async {},
            onAddDay: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final day = find.byKey(const ValueKey('day-2026-10-26'));
      await t.ensureVisible(day);
      await t.tap(day);
      await t.pumpAndSettle();
      expect(find.text('2026-10-26').hitTestable(), findsOneWidget);
      expect(find.byType(EntryTile).hitTestable(), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'all fifteen root categories can be chosen without typing a search',
    (t) async {
      screen(t);
      await t.pumpWidget(
        PocketFlowApp(
          home: QuickEntryPage(
            categories: categories,
            clock: _Clock(),
            onSave: (_) async => throw StateError('unused'),
          ),
        ),
      );
      await t.pumpAndSettle();
      final roots = categories
          .where((c) => c.parentId == null && c.kind == EntryKind.expense)
          .toList();
      expect(roots, hasLength(15));
      for (final root in [roots[0], roots[4], roots[14]]) {
        final all = find.byKey(const ValueKey('all-categories'));
        await t.ensureVisible(all);
        await t.tap(all);
        await t.pumpAndSettle();
        final choice = find.widgetWithText(ChoiceChip, '${root.name}（未细分）');
        await t.ensureVisible(choice);
        await t.pumpAndSettle();
        await t.tap(choice);
        await t.pumpAndSettle();
        expect(find.textContaining('已选：${root.name}'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    },
  );

  for (final value in [(0, 0, '本月预算为0'), (10000, 10000, '预算已用完')]) {
    testWidgets('budget status distinguishes ${value.$3}', (t) async {
      final snapshot = const BudgetCalculator().calculate(
        month: CalendarMonth(2026, 10),
        today: DateTime(2026, 10, 27),
        budget: Money.fromFen(value.$1),
        entries: value.$2 == 0
            ? []
            : [
                LedgerEntry(
                  id: 'synthetic',
                  amount: Money.fromFen(value.$2),
                  localDate: '2026-10-26',
                  categoryId: 'food',
                  occurredAtUtcMs: 1,
                  createdAtUtcMs: 1,
                  updatedAtUtcMs: 1,
                ),
              ],
      );
      await t.pumpWidget(
        PocketFlowApp(
          home: Scaffold(body: DailyAllowancePanel(snapshot: snapshot)),
        ),
      );
      expect(find.text(value.$3), findsOneWidget);
      expect(
        find.text(value.$3 == '本月预算为0' ? '预算已用完' : '本月预算为0'),
        findsNothing,
      );
    });
  }

  test('one-decimal category shares use integer ratios', () {
    expect(reportPercent(80000, 85190, decimalPlaces: 1), '93.9%');
    expect(reportPercent(3200, 85190, decimalPlaces: 1), '3.8%');
    expect(reportPercent(1990, 85190, decimalPlaces: 1), '2.3%');
    expect(reportPercent(1, 2000, decimalPlaces: 1), '0.1%');
    expect(reportPercent(1, 0, decimalPlaces: 1), isNull);
  });
}
