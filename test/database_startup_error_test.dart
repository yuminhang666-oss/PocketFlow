import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/contracts/contracts.dart';

class _UnavailableLedger implements LedgerRepository {
  var reads = 0;

  @override
  Stream<LedgerMonthData> watchMonth(CalendarMonth month) {
    reads++;
    return Stream.error(
      const PocketFlowException(PocketFlowErrorCode.storageFailure),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('database startup error stays visible until an explicit retry', (
    tester,
  ) async {
    final repository = _UnavailableLedger();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerRepositoryProvider.overrideWithValue(repository)],
        child: const PocketFlowRoot(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('暂时无法读取账本'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(repository.reads, 1);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('统计暂不可用'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(repository.reads, 2);
    expect(find.text('暂时无法读取账本'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
