import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/app/theme/frosted_glass.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';
import 'package:pocketflow/features/statistics/presentation/statistics_page.dart';
import 'package:pocketflow/shared/widgets/amount_text.dart';
import 'package:pocketflow/shared/widgets/metric_grid.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 21, 12);
}

void main() {
  const triplet = [
    ('Expenses', Money.fromFen(15888)),
    ('Income', Money.fromFen(0)),
    ('Net cash flow', Money.fromFen(-15888)),
  ];

  void checkAmounts(
    WidgetTester tester, {
    bool singleLine = true,
    int count = 3,
  }) {
    final amounts = find.descendant(
      of: find.byType(MetricGrid),
      matching: find.byType(AmountText),
    );
    expect(amounts, findsNWidgets(count));
    final sizes = <double?>{};
    final rows = <double, List<double>>{};
    for (final element in amounts.evaluate()) {
      final finder = find.byWidget(element.widget);
      final text = find.descendant(of: finder, matching: find.byType(Text));
      final widget = tester.widget<Text>(text);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final bounds = tester.getRect(text);
      final card = find.ancestor(
        of: finder,
        matching: find.byType(FrostedSurface),
      );
      final cardBounds = tester.getRect(card);
      if (singleLine) {
        expect(
          paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: widget.data!.length),
              )
              .map((box) => box.top)
              .toSet()
              .length,
          1,
          reason: '${widget.data} must not split a digit onto another line',
        );
      }
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(bounds.left, greaterThanOrEqualTo(cardBounds.left));
      expect(bounds.right, lessThanOrEqualTo(cardBounds.right));
      expect(bounds.bottom, lessThanOrEqualTo(cardBounds.bottom));
      sizes.add(widget.style?.fontSize);
      rows
          .putIfAbsent(cardBounds.top, () => [])
          .add(
            bounds.top +
                paragraph.getDryBaseline(
                  paragraph.constraints,
                  TextBaseline.alphabetic,
                )!,
          );
    }
    expect(
      sizes.length,
      1,
      reason: 'amounts use one shared readable type size',
    );
    expect(sizes.single, greaterThanOrEqualTo(16));
    for (final baselines in rows.values) {
      for (final baseline in baselines) {
        expect(baseline, closeTo(baselines.first, .1));
      }
    }
    expect(tester.takeException(), isNull);
  }

  Widget grid(List<(String, Money?)> values, double width) => PocketFlowApp(
    glass: true,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: MetricGrid(values: values),
        ),
      ),
    ),
  );

  testWidgets('negative net 158.88 stays whole and aligned in narrow cards', (
    tester,
  ) async {
    await tester.pumpWidget(grid(triplet, 328));
    await tester.pumpAndSettle();
    expect(find.text('¥-158.88'), findsOneWidget);
    checkAmounts(tester);
  });

  testWidgets('grouping separators participate in the width decision', (
    tester,
  ) async {
    await tester.pumpWidget(
      grid(const [
        ('Expenses', Money.fromFen(123456789)),
        ('Income', Money.fromFen(1)),
        ('Net cash flow', Money.fromFen(-123456788)),
      ], 320),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥1,234,567.89'), findsOneWidget);
    expect(find.text('¥-1,234,567.88'), findsOneWidget);
    checkAmounts(tester);
  });

  testWidgets('last metric fills its row instead of leaving an empty cell', (
    tester,
  ) async {
    await tester.pumpWidget(
      grid(const [
        ('Expenses', Money.fromFen(99999999)),
        ('Income', Money.fromFen(1)),
        ('Net cash flow', Money.fromFen(-99999998)),
      ], 500),
    );
    await tester.pumpAndSettle();
    final cards = find.byType(FrostedSurface);
    expect(tester.getRect(cards.at(0)).top, tester.getRect(cards.at(1)).top);
    expect(
      tester.getRect(cards.at(2)).top,
      greaterThan(tester.getRect(cards.at(0)).top),
    );
    expect(tester.getSize(cards.at(2)).width, closeTo(500, .1));
    checkAmounts(tester);
  });

  testWidgets('legal maximum preserves precision and system text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      grid(const [
        ('Expenses', Money.fromFen(Money.maxInputFen)),
        ('Income', Money.fromFen(0)),
        ('Net cash flow', Money.fromFen(-Money.maxInputFen)),
      ], 288),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥999,999,999.99'), findsOneWidget);
    expect(find.text('¥-999,999,999.99'), findsOneWidget);
    checkAmounts(tester, singleLine: false);
    final amountContext = tester.element(find.byType(AmountText).first);
    expect(MediaQuery.textScalerOf(amountContext).scale(16), 32);
  });

  testWidgets('empty and unset metric states remain usable', (tester) async {
    await tester.pumpWidget(grid(const [], 320));
    await tester.pumpAndSettle();
    expect(find.byType(FrostedSurface), findsNothing);
    await tester.pumpWidget(grid(const [('Budget', null)], 320));
    await tester.pumpAndSettle();
    expect(find.text('待设置'), findsOneWidget);
    expect(tester.getSize(find.byType(FrostedSurface)).width, 320);
    expect(tester.takeException(), isNull);
  });

  final month = CalendarMonth(2026, 10);
  final data = LedgerMonthData(
    month: month,
    budget: null,
    categories: generalRecommendedCategories(),
    entries: [
      LedgerEntry(
        id: 'synthetic-v033-layout',
        amount: const Money.fromFen(15888),
        localDate: '2026-10-21',
        categoryId: 'food_canteen',
        kind: EntryKind.expense,
        note: 'SYNTHETIC layout fixture',
        occurredAtUtcMs: 1,
        createdAtUtcMs: 1,
        updatedAtUtcMs: 1,
      ),
    ],
  );
  for (final theme in ['glass', 'light', 'dark']) {
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      testWidgets('ledger and statistics $theme $language at 320dp / 2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        Widget app(Widget page) => PocketFlowApp(
          glass: theme == 'glass',
          themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
          language: language,
          home: page,
        );
        for (final page in [
          LedgerListPage(
            data: data,
            query: const DefaultLedgerQueryService(),
            asOfLocalDate: '2026-10-21',
          ),
          StatisticsPage(month: month, state: AsyncData(data), clock: _Clock()),
        ]) {
          await tester.pumpWidget(app(page));
          await tester.pumpAndSettle();
          if (page is LedgerListPage) {
            expect(find.textContaining('¥-158.88'), findsOneWidget);
            checkAmounts(tester, count: 2);
          } else {
            expect(find.text('¥-158.88'), findsOneWidget);
            checkAmounts(tester);
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
