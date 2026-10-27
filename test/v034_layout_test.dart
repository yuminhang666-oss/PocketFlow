import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';
import 'package:pocketflow/l10n/app_strings.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 21, 12);
}

void main() {
  for (final appearance in ['light', 'dark', 'glass']) {
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      for (final spec in [
        (360.0, 1.0),
        (390.0, 1.0),
        (412.0, 1.0),
        (320.0, 1.0),
        (320.0, 2.0),
      ]) {
        testWidgets(
          'entry/filter/picker $appearance $language ${spec.$1}dp ${spec.$2}x',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(
              spec.$1,
              spec.$1 == 320 && spec.$2 == 2 ? 568 : 800,
            );
            tester.platformDispatcher.textScaleFactorTestValue = spec.$2;
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(disableAnimations: spec.$2 == 2);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetViewInsets);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
            final categories = generalRecommendedCategories();
            Widget app(Widget page) => PocketFlowApp(
              language: language,
              glass: appearance == 'glass',
              themeMode: appearance == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: page,
            );
            await tester.pumpWidget(
              app(
                QuickEntryPage(
                  categories: categories,
                  clock: _Clock(),
                  onSave: (_) async => throw StateError('unused'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final grid = tester.widget<GridView>(
              find.byKey(const ValueKey('category-grid-expense')),
            );
            expect(grid.physics, isA<NeverScrollableScrollPhysics>());
            final pageContext = tester.element(find.byType(QuickEntryPage));
            final picker = find.byKey(const ValueKey('all-categories'));
            await tester.ensureVisible(picker);
            await tester.pumpAndSettle();
            await tester.tap(picker);
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byType(TextField),
              'no-such-synthetic-category',
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final noMatch = find.text(tr(pageContext, '没有匹配的分类，请尝试其他关键词'));
            await tester.ensureVisible(noMatch);
            await tester.pumpAndSettle();
            expect(noMatch.hitTestable(), findsOneWidget);
            final modalContext = tester.element(find.byType(TextField));
            final close = find.byTooltip(tr(modalContext, '关闭'));
            await tester.ensureVisible(close);
            await tester.pumpAndSettle();
            await tester.tap(close);
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            expect(find.byType(QuickEntryPage), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(
              app(
                LedgerListPage(
                  data: LedgerMonthData(
                    month: CalendarMonth(2026, 10),
                    budget: null,
                    entries: [],
                    categories: categories,
                  ),
                  query: const DefaultLedgerQueryService(),
                  asOfLocalDate: '2026-10-21',
                  initialCategoryId: 'food',
                  onAdd: () {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(
                tr(tester.element(find.byType(LedgerListPage)), '已启用筛选'),
              ),
              findsOneWidget,
            );
            await tester.tap(
              find.byTooltip(
                tr(tester.element(find.byType(LedgerListPage)), '搜索与筛选'),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(InputChip), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
