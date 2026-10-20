import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/planning/data/drift_planning_store.dart';
import 'package:pocketflow/features/settings/presentation/settings_page.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 20, 12);
}

void main() {
  test(
    'glass preference survives reopen, JSON and recovery without changing finance',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftLedgerRepository(db, clock: _Clock());
      final store = DriftBackupStore(db, clock: _Clock());
      await repository.saveBudget(
        CalendarMonth(2026, 10),
        const Money.fromFen(100000),
      );
      final before = await store.readAll();
      await repository.savePreferences(theme: 'dark', surfaceStyle: 'glass');
      final reopened = DriftLedgerRepository(db, clock: _Clock());
      final data = await reopened.watchMonth(CalendarMonth(2026, 10)).first;
      expect(data.profile.surfaceStyle, 'glass');
      expect(data.profile.theme, 'dark');
      final saved = await store.readAll();
      final decoded = const JsonBackupCodec().decode(
        const JsonBackupCodec().encode(saved),
      );
      expect(decoded.profile.surfaceStyle, 'glass');
      expect(decoded.budgets.single.amount, before.budgets.single.amount);
      await repository.savePreferences(surfaceStyle: 'classic');
      await store.replaceAll(decoded);
      expect((await store.readAll()).profile.surfaceStyle, 'glass');
      final old = {...saved.profile.toJson()}..remove('surfaceStyle');
      expect(PersonalProfile.fromJson(old).surfaceStyle, 'classic');
      expect(
        () => PersonalProfile(surfaceStyle: 'unknown'),
        throwsFormatException,
      );
    },
  );

  for (final brightness in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('glass theme selection and accessibility at $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = false;
      await tester.pumpWidget(
        PocketFlowApp(
          glass: true,
          themeMode: brightness,
          home: SettingsPage(
            glass: true,
            themeMode: brightness,
            onThemeChanged: (_) {},
            onGlassSelected: () => selected = true,
          ),
        ),
      );
      await tester.ensureVisible(find.text('主题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('主题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('毛玻璃（浅色）').last);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.light,
      );
      expect(selected, isTrue);
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BackdropFilter>(find.byType(BackdropFilter))
            .every((w) => !w.enabled),
        isTrue,
      );
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
  }

  testWidgets(
    'real save auto-dismisses after three seconds and undo still removes only new entry',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final clock = _Clock(),
          repository = DriftLedgerRepository(db, clock: _Clock());
      final planning = DriftPlanningStore(db, clock: clock);
      Future<void> hit(Finder finder, {bool settle = true}) async {
        await tester.tap(finder);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          for (var attempt = 0; attempt < 40; attempt++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            if (find.byType(SnackBar).evaluate().isNotEmpty) break;
          }
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pump();
        }
      }

      await tester.runAsync(
        () => repository.watchMonth(CalendarMonth(2026, 10)).first,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerRepositoryProvider.overrideWithValue(repository),
            backupStoreProvider.overrideWithValue(
              DriftBackupStore(db, clock: clock),
            ),
            planningPortProvider.overrideWithValue(planning),
            clockProvider.overrideWithValue(clock),
          ],
          child: const PocketFlowRoot(),
        ),
      );
      try {
        await tester.pumpAndSettle();
        await hit(find.text('＋记账'));
        await hit(find.widgetWithText(TextButton, '1'));
        await hit(find.text('保存支出'), settle: false);
        expect(
          find.text('撤销'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        expect(
          tester
              .widgetList<SnackBar>(find.byType(SnackBar))
              .any(
                (notice) =>
                    !notice.persist &&
                    notice.duration == const Duration(seconds: 3),
              ),
          isTrue,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('撤销'), findsOneWidget);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1200)),
        );
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
        expect(find.text('撤销'), findsNothing);
        expect(
          (await tester.runAsync(
            () => repository.watchMonth(CalendarMonth(2026, 10)).first,
          ))!.entries.length,
          1,
        );
        await hit(find.text('＋记账'));
        await hit(find.widgetWithText(TextButton, '2'));
        await hit(find.text('保存支出'), settle: false);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await hit(find.text('撤销'));
        final data = await tester.runAsync(
          () => repository.watchMonth(CalendarMonth(2026, 10)).first,
        );
        expect(data!.entries.single.amount.fen, 100);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
  );
}
