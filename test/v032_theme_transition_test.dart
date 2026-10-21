import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/entry_editor/presentation/widgets/note_editor.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/app/theme/frosted_glass.dart';

class _Clock implements Clock {
  DateTime value = DateTime(2026, 10, 20, 12);
  @override
  DateTime now() => value;
}

class _Ledger implements LedgerRepository {
  final months = <CalendarMonth, StreamController<LedgerMonthData>>{};
  @override
  Stream<LedgerMonthData> watchMonth(CalendarMonth month) => months
      .putIfAbsent(month, () => StreamController<LedgerMonthData>.broadcast())
      .stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'known appearance survives a new month waiting for its snapshot',
    (tester) async {
      final ledger = _Ledger(), clock = _Clock();
      final container = ProviderContainer(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(ledger),
          clockProvider.overrideWithValue(clock),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PocketFlowRoot(),
        ),
      );
      ledger.months[CalendarMonth(2026, 10)]!.add(
        LedgerMonthData(
          month: CalendarMonth(2026, 10),
          budget: null,
          categories: generalRecommendedCategories(),
          entries: const [],
          profile: PersonalProfile(
            theme: 'dark',
            surfaceStyle: 'glass',
            locale: 'en',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        tester.widget<PocketFlowApp>(find.byType(PocketFlowApp)).glass,
        isTrue,
      );
      clock.value = DateTime(2026, 11, 1, 12);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final app = tester.widget<PocketFlowApp>(find.byType(PocketFlowApp));
      expect(app.glass, isTrue);
      expect(app.language, 'en');
      expect(app.themeMode, ThemeMode.dark);
      expect(ledger.months.containsKey(CalendarMonth(2026, 11)), isTrue);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      for (final controller in ledger.months.values) {
        await controller.close();
      }
    },
  );

  for (final appearance in ['light', 'dark', 'glass']) {
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      testWidgets(
        'editor first frame, repeated entry and note keyboard: $appearance $language',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          late BuildContext home;
          await tester.pumpWidget(
            PocketFlowApp(
              glass: appearance == 'glass',
              language: language,
              themeMode: appearance == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: Builder(
                builder: (context) {
                  home = context;
                  return const Scaffold();
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var attempt = 0; attempt < 2; attempt++) {
            Navigator.of(home).push(
              MaterialPageRoute<void>(
                builder: (_) => QuickEntryPage(
                  categories: generalRecommendedCategories(),
                  clock: _Clock(),
                  onSave: (_) async =>
                      throw StateError('This navigation test never saves'),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            for (var frame = 0; frame < 31; frame++) {
              final editor = tester.element(
                find.byType(QuickEntryPage, skipOffstage: false),
              );
              expect(
                FrostedAppearance.enabled(editor),
                appearance == 'glass',
                reason: 'frame $frame',
              );
              expect(
                Theme.of(editor).brightness,
                appearance == 'dark' ? Brightness.dark : Brightness.light,
              );
              expect(tester.takeException(), isNull);
              await tester.pump(const Duration(milliseconds: 16));
            }
            Navigator.of(home).pop();
            await tester.pumpAndSettle();
          }
          // 500 UTF-16 units is the real note limit; keyboard occupies 240dp.
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          addTearDown(tester.view.resetViewInsets);
          showModalBottomSheet<void>(
            context: home,
            isScrollControlled: true,
            builder: (_) => NoteEditor(
              initialNote: ('午餐Lunch👩🏽‍💻' * 20).padRight(500, '餐'),
            ),
          );
          await tester.pump();
          for (var frame = 0; frame < 25; frame++) {
            final note = tester.element(
              find.byType(NoteEditor, skipOffstage: false),
            );
            expect(FrostedAppearance.enabled(note), appearance == 'glass');
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
          final done = find.byType(FilledButton);
          await tester.ensureVisible(done);
          await tester.pumpAndSettle();
          await tester.tap(done);
          await tester.pumpAndSettle();
          expect(find.byType(NoteEditor), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'appearance switches atomically; reduced motion and high contrast remain accessible',
    (tester) async {
      final appearance = ValueNotifier('dark');
      addTearDown(appearance.dispose);
      late BuildContext home;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            disableAnimations: true,
            highContrast: true,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: appearance,
          builder: (_, value, _) => PocketFlowApp(
            glass: value == 'glass',
            themeMode: value == 'dark' ? ThemeMode.dark : ThemeMode.light,
            home: Builder(
              builder: (context) {
                home = context;
                return const Scaffold(
                  body: FrostedSurface(child: Text('Surface')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final value in ['glass', 'light', 'dark', 'glass']) {
        appearance.value = value;
        await tester.pump();
        expect(FrostedAppearance.enabled(home), value == 'glass');
        expect(
          Theme.of(home).brightness,
          value == 'dark' ? Brightness.dark : Brightness.light,
        );
        if (value == 'glass') {
          expect(
            tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
            isFalse,
          );
        }
        Navigator.of(home).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Still')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(SlideTransition), findsNothing);
        expect(find.text('Still'), findsOneWidget);
        Navigator.of(home).pop();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('glass backdrop survives every entering and returning frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    late BuildContext home;
    final route = MaterialPageRoute<void>(
      builder: (context) {
        expect(FrostedAppearance.enabled(context), isTrue);
        return const Scaffold(body: Text('Destination'));
      },
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: PocketFlowApp(
          glass: true,
          home: Builder(
            builder: (context) {
              home = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<List<int>> background() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        // Sample empty background far from the translated labels on both pages.
        final offset = (500 * image.width + 180) * 4;
        final pixel = bytes.buffer.asUint8List(offset, 4).toList();
        image.dispose();
        return pixel;
      }))!;
    }

    final expected = await background();
    Navigator.of(home).push(route);
    await tester.pump();
    expect(await background(), expected, reason: 'first push frame');
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(await background(), expected, reason: 'push frame $frame');
    }
    await tester.pumpAndSettle();
    Navigator.of(home).pop();
    await tester.pump();
    expect(await background(), expected, reason: 'first pop frame');
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(await background(), expected, reason: 'pop frame $frame');
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
