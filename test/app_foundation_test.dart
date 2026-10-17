import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'foundation empty state renders at $size, text scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(const PocketFlowApp());
          await tester.pumpAndSettle();
          expect(find.text('PocketFlow'), findsOneWidget);
          expect(find.text('待设置预算'), findsOneWidget);
          expect(find.text('还没有消费记录'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
