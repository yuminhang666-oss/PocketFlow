import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/features/settings/presentation/about_pocketflow_page.dart';

void main() {
  for (final spec in [
    (const Size(360, 640), 1.0, ThemeMode.light),
    (const Size(320, 568), 2.0, ThemeMode.dark),
  ]) {
    testWidgets('offline release history navigation at $spec', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = spec.$1;
      tester.platformDispatcher.textScaleFactorTestValue = spec.$2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        PocketFlowApp(
          themeMode: spec.$3,
          home: const AboutPocketFlowPage(installedVersion: '0.3.0'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('更新记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更新记录'));
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseHistoryPage), findsOneWidget);
      expect(find.text('当前版本'), findsOneWidget);
      expect(find.text('新增功能'), findsOneWidget);
      expect(find.text('问题修复'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Collapse the long current notes, then read a historical fix.
      await tester.tap(find.text('0.3.0'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('0.1.1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0.1.1'));
      await tester.pumpAndSettle();
      final oldFix = find.textContaining('修复Android中账本无法读取');
      await tester.ensureVisible(oldFix);
      await tester.pumpAndSettle();
      expect(oldFix, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(AboutPocketFlowPage), findsOneWidget);
      await tester.ensureVisible(find.text('开源许可'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开源许可'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
