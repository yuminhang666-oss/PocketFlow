import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/ledger_list/presentation/ledger_list_page.dart';
import 'package:pocketflow/features/statistics/domain/ledger_query_service.dart';

LedgerMonthData data(int month) => LedgerMonthData(
  budget: null,
  month: CalendarMonth(2026, month),
  categories: generalRecommendedCategories(),
  entries: [
    LedgerEntry(
      id: 'synthetic-$month',
      amount: const Money.fromFen(500),
      localDate: '2026-${month.toString().padLeft(2, '0')}-10',
      categoryId: 'food',
      kind: EntryKind.expense,
      note: 'synthetic',
      occurredAtUtcMs: 1,
      createdAtUtcMs: 1,
      updatedAtUtcMs: 1,
    ),
  ],
);

void main() {
  testWidgets(
    'filters survive loading/error/month; cancel and individual removal are explicit',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var current = data(9);
      var loading = false;
      Object? error;
      late StateSetter update;
      await tester.pumpWidget(
        PocketFlowApp(
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return LedgerListPage(
                data: loading || error != null ? null : current,
                month: current.month,
                loading: loading,
                readError: error,
                query: const DefaultLedgerQueryService(),
                asOfLocalDate: '2026-10-21',
                initialCategoryId: 'food',
                initialDate: '2026-09-10',
                onRetry: () {},
                onAdd: () {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'synthetic');
      await tester.tap(find.text('分类 / 金额'));
      await tester.pumpAndSettle();
      final amounts = find.byType(TextField);
      await tester.enterText(amounts.at(1), '2');
      await tester.enterText(amounts.at(2), '8');
      await tester.tap(find.text('应用筛选'));
      await tester.pumpAndSettle();
      expect(find.text('最低 ¥2.00'), findsOneWidget);
      expect(find.text('最高 ¥8.00'), findsOneWidget);
      await tester.tap(find.text('分类 / 金额'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '2.00',
      );
      await tester.enterText(find.byType(TextField).at(1), '99');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('最低 ¥2.00'), findsOneWidget);
      expect(find.text('最低 ¥99.00'), findsNothing);
      final state = tester.state(find.byType(LedgerListPage));
      update(() => loading = true);
      await tester.pump();
      expect(find.text('正在读取账本'), findsOneWidget);
      expect(find.text('5.00'), findsNothing);
      update(() {
        loading = false;
        error = const PocketFlowException(PocketFlowErrorCode.storageFailure);
      });
      await tester.pump();
      expect(find.text('无法读取账单'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      update(() => error = null);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(LedgerListPage)), same(state));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'synthetic',
      );
      update(() => current = data(10));
      await tester.pumpAndSettle();
      expect(find.text('分类：餐饮'), findsOneWidget);
      expect(find.text('最低 ¥2.00'), findsOneWidget);
      expect(find.text('2026-09-10 至 2026-09-10'), findsNothing);
      expect(find.textContaining('日期范围已重置'), findsOneWidget);
      final minChip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, '最低 ¥2.00'),
      );
      minChip.onDeleted!();
      await tester.pump();
      expect(find.text('最低 ¥2.00'), findsNothing);
      expect(find.text('最高 ¥8.00'), findsOneWidget);
      await tester.tap(find.text('清除筛选').first);
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty month and no matching results have distinct actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      PocketFlowApp(
        home: LedgerListPage(
          data: LedgerMonthData(
            budget: null,
            month: CalendarMonth(2026, 10),
            entries: [],
            categories: generalRecommendedCategories(),
          ),
          query: const DefaultLedgerQueryService(),
          asOfLocalDate: '2026-10-21',
          onAdd: () {},
        ),
      ),
    );
    expect(find.text('本月还没有记录'), findsOneWidget);
    expect(find.text('记第一笔'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no match');
    await tester.pump();
    expect(find.text('没有符合条件的账单'), findsOneWidget);
    expect(find.text('清除筛选'), findsWidgets);
  });
}
