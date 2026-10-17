import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/features/home/presentation/home_page.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('actual empty home at $size, text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final month = CalendarMonth(2026, 10);
        final ledger = LedgerMonthData(
          month: month,
          budget: null,
          entries: [],
          categories: [],
        );
        final budget = BudgetSnapshot(
          month: month,
          period: MonthPeriod.current,
          budget: null,
          spent: const Money.fromFen(0),
          remaining: null,
          remainingDays: 15,
          dailyAllowance: null,
        );
        await tester.pumpWidget(
          PocketFlowApp(
            home: HomePage(month: month, state: AsyncData((ledger, budget))),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('PocketFlow'), findsOneWidget);
        expect(find.text('待设置预算'), findsOneWidget);
        expect(find.text('还没有消费记录'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
