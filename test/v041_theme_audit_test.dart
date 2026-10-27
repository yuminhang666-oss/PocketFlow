import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/entry_editor/presentation/widgets/category_selector.dart';
import 'package:pocketflow/features/settings/presentation/categories_page.dart';
import 'package:pocketflow/features/statistics/domain/monthly_report_service.dart';
import 'package:pocketflow/features/statistics/presentation/fl_chart_widgets.dart';
import 'package:pocketflow/shared/widgets/entry_tile.dart';

void main() {
  final categories = generalRecommendedCategories();
  final entry = LedgerEntry(
    id: 'synthetic-theme',
    amount: const Money.fromFen(2800),
    categoryId: 'food',
    localDate: '2026-09-26',
    occurredAtUtcMs: 1,
    createdAtUtcMs: 1,
    updatedAtUtcMs: 1,
  );
  final report = const DefaultMonthlyReportService().build(
    LedgerMonthData(
      month: CalendarMonth(2026, 9),
      budget: null,
      categories: categories,
      entries: [entry],
    ),
    asOfLocalDate: '2026-09-30',
  );
  for (final mode in ['light', 'dark', 'glass']) {
    Widget app(Widget home) => PocketFlowApp(
      glass: mode == 'glass',
      themeMode: mode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      home: home,
    );
    testWidgets(
      '$mode selection and tonal controls render with interaction blue',
      (t) async {
        await t.pumpWidget(
          app(
            Scaffold(
              body: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('列表')),
                      ButtonSegment(value: true, label: Text('日历')),
                    ],
                    selected: const {false},
                    onSelectionChanged: (_) {},
                  ),
                  FilledButton.tonal(
                    onPressed: () {},
                    child: const Text('补记这一天'),
                  ),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final selected = find.text('列表'), tonal = find.text('补记这一天');
        final scheme = Theme.of(t.element(selected)).colorScheme;
        final selectedMaterials = t.widgetList<Material>(
          find.ancestor(of: selected, matching: find.byType(Material)),
        );
        expect(selectedMaterials.any((m) => m.color == scheme.primary), isTrue);
        final tonalMaterials = t.widgetList<Material>(
          find.ancestor(of: tonal, matching: find.byType(Material)),
        );
        expect(
          tonalMaterials.any((m) => m.color == scheme.primaryContainer),
          isTrue,
        );
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$mode category identity agrees in entry, ledger, management and statistics',
      (t) async {
        await t.pumpWidget(
          app(
            Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    EntryTile(entry: entry, categories: categories),
                    CategorySelector(
                      categories: categories,
                      selectedId: 'food',
                      onSelected: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final context = t.element(find.byType(EntryTile));
        final identity = identityColor(context, 'food', categories);
        final foodIcons = t.widgetList<Icon>(
          find.byIcon(categoryIcon('food', categories)),
        );
        expect(foodIcons.length, greaterThan(1));
        expect(foodIcons.every((icon) => icon.color == identity), isTrue);
        final selectedCheck = find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byIcon(Icons.check_circle),
        );
        expect(
          t.widget<Icon>(selectedCheck).color,
          Theme.of(context).colorScheme.primary,
        );
        final label = find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.text('餐饮'),
        );
        expect(
          DefaultTextStyle.of(t.element(label)).style.color,
          Theme.of(context).colorScheme.onSurface,
        );
        await t.pumpWidget(
          app(
            CategoriesPage(
              categories: categories,
              onSave: (_) async {},
              onRecommended: () async {},
              onReorder: (_) async {},
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          t
              .widget<Icon>(find.byIcon(categoryIcon('food', categories)).first)
              .color,
          identity,
        );
        await t.pumpWidget(
          app(
            Scaffold(
              body: CategoryExpenseDonut(
                report: report,
                categories: categories,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          t.widget<PieChart>(find.byType(PieChart)).data.sections.single.color,
          identity,
        );
        expect(categoryColor('food', categories), const Color(0xFFE77A2C));
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'editing a category in dark mode does not persist its brightened display color',
    (t) async {
      Category? saved;
      final one = [categories.firstWhere((c) => c.id == 'food')];
      await t.pumpWidget(
        PocketFlowApp(
          themeMode: ThemeMode.dark,
          home: CategoriesPage(
            categories: one,
            onSave: (c) async => saved = c,
            onRecommended: () async {},
            onReorder: (_) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('餐饮'));
      await t.pumpAndSettle();
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await t.pumpAndSettle();
      await t.tap(find.text('修改名称'));
      await t.pumpAndSettle();
      await t.tap(find.text('保存分类'));
      await t.pumpAndSettle();
      expect(saved?.colorValue, 0xFFE77A2C);
      expect(t.takeException(), isNull);
    },
  );
}
