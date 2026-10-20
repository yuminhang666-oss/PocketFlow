import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/planning/presentation/planning_pages_v3.dart';
import 'package:pocketflow/features/statistics/presentation/statistics_page.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 20, 12);
}

class _NoActions implements PlanningPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final month = CalendarMonth(2026, 10),
      categories = generalRecommendedCategories();
  final data = LedgerMonthData(
    month: month,
    budget: MonthlyBudget(
      month: month,
      amount: const Money.fromFen(160000),
      updatedAtUtcMs: 0,
    ),
    categories: categories,
    categoryBudgets: [
      CategoryBudget(
        month: month,
        categoryId: 'food',
        amount: const Money.fromFen(50000),
      ),
    ],
    entries: [
      LedgerEntry(
        id: 'synthetic-ui',
        amount: const Money.fromFen(2480),
        localDate: '2026-10-20',
        categoryId: 'food_canteen',
        kind: EntryKind.expense,
        note: 'User 原文 {p1}',
        occurredAtUtcMs: 100,
        createdAtUtcMs: 100,
        updatedAtUtcMs: 100,
      ),
    ],
  );
  for (final appearance in ['light', 'dark', 'glass']) {
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      testWidgets(
        'budget and populated statistics: $appearance $language at 320px / 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          Widget app(Widget home) => PocketFlowApp(
            language: language,
            glass: appearance == 'glass',
            themeMode: appearance == 'dark' ? ThemeMode.dark : ThemeMode.light,
            home: home,
          );
          await tester.pumpWidget(
            app(
              CategoryBudgetsPage(
                data: data,
                port: _NoActions(),
                today: _Clock().now(),
                onTotalBudget: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            app(
              StatisticsPage(
                month: month,
                state: AsyncData(data),
                clock: _Clock(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final section = find.byType(ChoiceChip).last;
          await tester.ensureVisible(section);
          await tester.pumpAndSettle();
          await tester.tap(section);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
