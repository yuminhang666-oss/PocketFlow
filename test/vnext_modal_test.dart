import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/category_catalog.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/settings/presentation/planning_pages.dart';
import 'package:pocketflow/features/settings/presentation/categories_page.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

void main() {
  final categories = recommendedCategories();
  void screen(WidgetTester t) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(412, 915);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets(
    'saving focused income template waits for dialog disposal and preserves form',
    (t) async {
      screen(t);
      EntryTemplate? saved;
      LedgerEntry? returned;
      final entry = LedgerEntry(
        id: 'fixture',
        kind: EntryKind.income,
        amount: const Money.fromFen(100),
        localDate: '2026-10-17',
        categoryId: 'income_family',
        occurredAtUtcMs: 100,
        createdAtUtcMs: 100,
        updatedAtUtcMs: 100,
      );
      await t.pumpWidget(
        PocketFlowApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await Navigator.push<LedgerEntry>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickEntryPage(
                        categories: categories,
                        clock: _Clock(),
                        onSave: (_) async => throw StateError(
                          'Expense callback used for income',
                        ),
                        onSaveIncome: (draft) async {
                          expect(draft.amount.fen, 100);
                          return entry;
                        },
                        onSaveTemplate: (value) async => saved = value,
                      ),
                    ),
                  );
                },
                child: const Text('打开记账'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('打开记账'));
      await t.pumpAndSettle();
      await t.tap(find.text('收入'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, '1'));
      await t.pump();
      await t.tap(find.byTooltip('更多'));
      await t.pumpAndSettle();
      await t.tap(find.text('保存为模板'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Fixture template');
      await t.tap(find.text('保存模板'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(saved?.kind, EntryKind.income);
      expect(saved?.amount.fen, 100);
      expect(find.text('保存收入').hitTestable(), findsOneWidget);
      await t.tap(find.text('保存收入'));
      await t.pumpAndSettle();
      expect(returned?.kind, EntryKind.income);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'goal form closes with focused input and returns saved progress',
    (t) async {
      screen(t);
      SavingsGoal? saved;
      await t.pumpWidget(
        PocketFlowApp(
          home: GoalsPage(
            profile: PersonalProfile(),
            onSave: (value) async => saved = value,
            onDelete: (_) async {},
          ),
        ),
      );
      await t.tap(find.text('新建目标'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), 'Fixture goal');
      await t.enterText(find.byType(TextField).at(1), '1000');
      await t.enterText(find.byType(TextField).at(2), '200');
      await t.ensureVisible(find.text('保存目标'));
      await t.pumpAndSettle();
      await t.tap(find.text('保存目标'));
      await t.pumpAndSettle();
      expect(saved?.target.fen, 100000);
      expect(saved?.saved.fen, 20000);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'category name dialog closes without disposing a live text controller',
    (t) async {
      screen(t);
      Category? saved;
      await t.pumpWidget(
        PocketFlowApp(
          home: CategoriesPage(
            categories: categories,
            onSave: (value) async => saved = value,
            onRecommended: () async {},
            onReorder: (_) async {},
          ),
        ),
      );
      await t.tap(find.byTooltip('新增分类'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Fixture custom');
      await t.tap(find.text('保存分类'));
      await t.pumpAndSettle();
      expect(saved?.name, 'Fixture custom');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'amount filter sheet applies after focus and keeps exact filtered sums',
    (t) async {
      screen(t);
      final month = CalendarMonth(2026, 10);
      final data = LedgerMonthData(
        month: month,
        budget: null,
        categories: categories,
        entries: [
          LedgerEntry(
            id: 'small',
            amount: const Money.fromFen(500),
            kind: EntryKind.expense,
            localDate: '2026-10-17',
            categoryId: 'food',
            occurredAtUtcMs: 100,
            createdAtUtcMs: 100,
            updatedAtUtcMs: 100,
          ),
          LedgerEntry(
            id: 'large',
            amount: const Money.fromFen(1500),
            kind: EntryKind.expense,
            localDate: '2026-10-17',
            categoryId: 'food',
            occurredAtUtcMs: 101,
            createdAtUtcMs: 101,
            updatedAtUtcMs: 101,
          ),
        ],
      );
      await t.pumpWidget(
        PocketFlowApp(
          home: LedgerListPage(
            data: data,
            query: const DefaultLedgerQueryService(),
            asOfLocalDate: '2026-10-17',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('分类 / 金额'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, '最低金额（元，选填）'), '10');
      await t.ensureVisible(find.text('应用筛选'));
      await t.pumpAndSettle();
      await t.tap(find.text('应用筛选'));
      await t.pumpAndSettle();
      expect(find.textContaining('共 1 笔'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
