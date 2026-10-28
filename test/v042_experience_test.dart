import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/entry_editor/presentation/widgets/category_selector.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/reports/presentation/report_content.dart';
import 'package:pocketflow/features/reports/presentation/reports_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 28, 12);
}

class _Plans implements PlanningPort {
  @override
  Stream<LedgerRangeData> watchRange(String start, String end) => Stream.value(
    LedgerRangeData(
      start: start,
      end: end,
      entries: const [],
      categories: generalRecommendedCategories(),
      revision: 'SYNTHETIC-v042',
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void screen(
  WidgetTester t, [
  Size size = const Size(360, 640),
  double scale = 1,
]) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets(
    'date, visible note and quick categories fit with Android safe areas',
    (t) async {
      screen(t);
      await t.pumpWidget(
        PocketFlowApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: QuickEntryPage(
                categories: generalRecommendedCategories(),
                clock: _Clock(),
                onSave: (_) async => throw StateError('unused'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('entry-note')).hitTestable(),
        findsOneWidget,
      );
      final grid = find.byKey(const ValueKey('category-grid-expense'));
      final keypad = find.widgetWithText(TextButton, '1');
      expect(t.getRect(grid).bottom, lessThanOrEqualTo(t.getRect(keypad).top));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'reselecting a historical report keeps period; picker cancel and type switch are explicit',
    (t) async {
      screen(t);
      await t.pumpWidget(
        PocketFlowApp(
          home: ReportsPage(
            port: _Plans(),
            clock: _Clock(),
            initialStart: '2026-10-12',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('周报'));
      await t.pumpAndSettle();
      expect(find.text('2026-10-12 — 2026-10-18'), findsOneWidget);
      expect(find.text('选择历史月报'), findsNothing);
      await t.tap(find.text('切换到月报'));
      await t.pumpAndSettle();
      expect(find.text('选择月份'), findsOneWidget);
      await t.tap(find.byTooltip('上一期间'));
      await t.pumpAndSettle();
      expect(find.text('2026-09-01 — 2026-09-30'), findsOneWidget);
      await t.tap(find.text('月报'));
      await t.pumpAndSettle();
      expect(find.text('2026-09-01 — 2026-09-30'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('report-period-picker')));
      await t.pumpAndSettle();
      expect(find.text('9月'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('2026-09-01 — 2026-09-30'), findsOneWidget);
      await t.tap(find.text('周报'));
      await t.pumpAndSettle();
      expect(
        find.text('2026-10-26 — 2026-10-28'),
        findsOneWidget,
        reason: 'September is outside weekly retention; use current week',
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final spec in [
    ('2026-11', '2026-11-01', 1, 1),
    ('2026-09', '2026-11-01', 1, 30),
    ('2028-02', '2028-03-01', 1, 29),
  ]) {
    testWidgets(
      'date filter opens with local bounds ${spec.$1} as of ${spec.$2}',
      (t) async {
        screen(t);
        final month = CalendarMonth.parse(spec.$1);
        await t.pumpWidget(
          PocketFlowApp(
            home: LedgerListPage(
              data: LedgerMonthData(
                month: month,
                budget: null,
                entries: const [],
                categories: generalRecommendedCategories(),
              ),
              query: const DefaultLedgerQueryService(),
              asOfLocalDate: spec.$2,
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('搜索与筛选'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(ActionChip, '日期'));
        await t.pumpAndSettle();
        final picker = t.widget<DateRangePickerDialog>(
          find.byType(DateRangePickerDialog),
        );
        expect(picker.firstDate.isUtc, isFalse);
        expect(picker.lastDate.isUtc, isFalse);
        expect(picker.firstDate.day, spec.$3);
        expect(picker.lastDate.day, spec.$4);
        expect(picker.firstDate.month, month.month);
        expect(picker.lastDate.month, month.month);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('future month date filter is disabled', (t) async {
    final month = CalendarMonth(2026, 12);
    await t.pumpWidget(
      PocketFlowApp(
        home: LedgerListPage(
          data: LedgerMonthData(
            month: month,
            budget: null,
            entries: const [],
            categories: generalRecommendedCategories(),
          ),
          query: const DefaultLedgerQueryService(),
          asOfLocalDate: '2026-11-01',
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('搜索与筛选'));
    await t.pumpAndSettle();
    expect(
      t.widget<ActionChip>(find.widgetWithText(ActionChip, '日期')).onPressed,
      isNull,
    );
  });

  testWidgets(
    'subcategory overflow controls reveal the final choice and disappear when all fit',
    (t) async {
      screen(t);
      String? selected;
      final categories = [
        Category(
          id: 'root',
          name: '测试分类',
          sortOrder: 0,
          kind: EntryKind.expense,
        ),
        for (var i = 0; i < 8; i++)
          Category(
            id: 'child-$i',
            name: '细分类$i',
            sortOrder: i + 1,
            parentId: 'root',
            kind: EntryKind.expense,
          ),
      ];
      await t.pumpWidget(
        PocketFlowApp(
          home: Scaffold(
            body: CategorySelector(
              categories: categories,
              selectedId: 'root',
              onSelected: (id) => selected = id,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('更多细分类'), findsOneWidget);
      for (
        var i = 0;
        i < 12 && find.byTooltip('更多细分类').evaluate().isNotEmpty;
        i++
      ) {
        await t.tap(find.byTooltip('更多细分类'));
        await t.pumpAndSettle();
      }
      await t.tap(find.text('细分类7'));
      expect(selected, 'child-7');
      expect(find.byTooltip('前面的细分类'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        PocketFlowApp(
          home: Scaffold(
            body: CategorySelector(
              categories: categories.take(2).toList(),
              selectedId: 'root',
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('更多细分类'), findsNothing);
      expect(find.byTooltip('前面的细分类'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save keeps draft and retries once; busy save rejects both actions',
    (t) async {
      screen(t, const Size(412, 915));
      final first = Completer<LedgerEntry>();
      var calls = 0;
      EntryDraft? kept;
      await t.pumpWidget(
        PocketFlowApp(
          home: QuickEntryPage(
            categories: generalRecommendedCategories(),
            clock: _Clock(),
            onSave: (draft) {
              kept = draft;
              if (++calls == 1) return first.future;
              return Future.value(
                LedgerEntry(
                  id: 'SYNTHETIC-retry',
                  amount: draft.amount,
                  localDate: draft.localDate,
                  categoryId: draft.categoryId,
                  note: draft.note,
                  occurredAtUtcMs: draft.occurredAtUtcMs,
                  createdAtUtcMs: 1,
                  updatedAtUtcMs: 1,
                ),
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('entry-note')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'SYNTHETIC keep note');
      await t.tap(find.text('完成'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, '8'));
      await t.pump();
      final save = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存支出'))
          .onPressed!;
      final more = t
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '保存并继续'))
          .onPressed!;
      save();
      more();
      save();
      await t.pump();
      expect(calls, 1);
      first.completeError(
        const PocketFlowException(PocketFlowErrorCode.storageFailure),
      );
      await t.pump();
      expect(find.textContaining('未保存，内容仍在'), findsOneWidget);
      expect(find.text('¥ 8'), findsOneWidget);
      expect(find.text('SYNTHETIC keep note'), findsOneWidget);
      await t.tap(find.text('保存并继续'));
      await t.pump();
      expect(calls, 2);
      expect(kept!.amount.fen, 800);
      expect(kept!.note, 'SYNTHETIC keep note');
      expect(kept!.localDate, '2026-10-28');
      expect(find.textContaining('支出 ¥8.00'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      expect(t.takeException(), isNull);
    },
  );

  for (final theme in ['light', 'dark', 'glass']) {
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      testWidgets(
        '$theme $language report and entry at 320dp / 200% remain reachable',
        (t) async {
          screen(t, const Size(320, 568), 2);
          Widget app(Widget home) => PocketFlowApp(
            glass: theme == 'glass',
            themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
            language: language,
            home: home,
          );
          await t.pumpWidget(app(ReportsPage(port: _Plans(), clock: _Clock())));
          await t.pumpAndSettle();
          expect(find.byType(ReportContent), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(
            app(
              QuickEntryPage(
                categories: generalRecommendedCategories(),
                clock: _Clock(),
                onSave: (_) async => throw StateError('unused'),
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.ensureVisible(find.byKey(const ValueKey('entry-note')));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('entry-note')).hitTestable(),
            findsOneWidget,
          );
          final save = find.byType(FilledButton).last;
          await t.ensureVisible(save);
          await t.pumpAndSettle();
          expect(save.hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
