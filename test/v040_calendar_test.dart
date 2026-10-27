import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_calendar_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';

void main() {
  final categories = [
    Category(id: 'food', name: '餐饮', sortOrder: 0),
    Category(
      id: 'income_work',
      name: '工资薪酬',
      sortOrder: 1,
      kind: EntryKind.income,
    ),
  ];
  LedgerMonthData data(CalendarMonth month) => LedgerMonthData(
    month: month,
    budget: null,
    categories: categories,
    entries: month == CalendarMonth(2028, 1)
        ? [
            for (final kind in EntryKind.values)
              LedgerEntry(
                id: kind.name,
                amount: const Money.fromFen(1234),
                localDate: '2028-01-31',
                categoryId: kind == EntryKind.expense ? 'food' : 'income_work',
                kind: kind,
                occurredAtUtcMs: 1,
                createdAtUtcMs: 1,
                updatedAtUtcMs: 1,
              ),
          ]
        : [],
  );
  Widget calendar(
    LedgerMonthData d, {
    String? selected,
    ValueChanged<CalendarMonth>? move,
    LedgerFilter? filter,
  }) => LedgerCalendarPage(
    data: d,
    view: const DefaultLedgerQueryService().filter(
      d,
      filter ?? const LedgerFilter(),
      asOfLocalDate: '2028-04-02',
    ),
    today: '2028-04-02',
    selectedDate: selected,
    onMoveMonth: move,
    onOpenDay: (_) {},
    onMarkZero: (_, _) async {},
    onAddDay: (_) {},
  );

  testWidgets(
    'calendar clamps a 31st into leap February and keeps the actual selected day on the next move',
    (t) async {
      var month = CalendarMonth(2028, 1);
      await t.pumpWidget(
        PocketFlowApp(
          home: StatefulBuilder(
            builder: (context, update) => calendar(
              data(month),
              selected: '2028-01-31',
              move: (value) => update(() => month = value),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('下月'));
      await t.pumpAndSettle();
      expect(find.text('2028-02-29'), findsOneWidget);
      await t.tap(find.byTooltip('下月'));
      await t.pumpAndSettle();
      expect(find.text('2028-03-29'), findsOneWidget);
      final today = find.text('回到今天');
      await t.ensureVisible(today);
      await t.tap(today);
      await t.pumpAndSettle();
      expect(month, CalendarMonth(2028, 4));
      expect(find.text('2028-04-02'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'income-only filter cannot enable zero-spend confirmation over a hidden expense',
    (t) async {
      await t.pumpWidget(
        PocketFlowApp(
          home: calendar(
            data(CalendarMonth(2028, 1)),
            selected: '2028-01-31',
            filter: const LedgerFilter(kind: EntryKind.income),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('确认当天零支出'), findsNothing);
      expect(find.text('查看当天账单'), findsNothing);
      expect(find.text('补记这一天'), findsOneWidget);
    },
  );
  for (final mode in ['light', 'dark', 'glass']) {
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      testWidgets(
        'calendar seven columns at 320dp 200 percent $mode $language',
        (t) async {
          t.view.physicalSize = const Size(320, 568);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pumpWidget(
            PocketFlowApp(
              language: language,
              glass: mode == 'glass',
              themeMode: mode == 'dark' ? ThemeMode.dark : ThemeMode.light,
              home: calendar(
                data(CalendarMonth(2028, 1)),
                selected: '2028-01-31',
              ),
            ),
          );
          await t.pumpAndSettle();
          final grid = find.byType(GridView);
          final delegate =
              t.widget<GridView>(grid).gridDelegate
                  as SliverGridDelegateWithFixedCrossAxisCount;
          expect(delegate.crossAxisCount, 7);
          expect(t.takeException(), isNull);
          final date = find.text('2028-01-31');
          await t.ensureVisible(date);
          await t.pumpAndSettle();
          expect(date.hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
