import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 21, 12);
}

LedgerEntry saved(EntryDraft draft, int id) => LedgerEntry(
  id: 'synthetic-$id',
  amount: draft.amount,
  localDate: draft.localDate,
  categoryId: draft.categoryId,
  kind: EntryKind.expense,
  note: draft.note,
  occurredAtUtcMs: draft.occurredAtUtcMs,
  createdAtUtcMs: id,
  updatedAtUtcMs: id,
);

Future<void> screen(
  WidgetTester tester,
  Future<LedgerEntry> Function(EntryDraft) save,
  Future<void> Function(LedgerEntry) undo,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    PocketFlowApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<LedgerEntry>(
              MaterialPageRoute(
                builder: (_) => QuickEntryPage(
                  categories: generalRecommendedCategories(),
                  clock: _Clock(),
                  onSave: save,
                  onUndo: undo,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> key(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(TextButton, label));
  await tester.pump();
}

void main() {
  testWidgets(
    'three continuous saves undo only last, preserve next draft and original expiry',
    (tester) async {
      final entries = <LedgerEntry>[];
      await screen(
        tester,
        (draft) async {
          final entry = saved(draft, entries.length + 1);
          entries.add(entry);
          return entry;
        },
        (entry) async {
          entries.removeWhere((e) => e.id == entry.id);
        },
      );
      for (final digit in ['1', '2', '3']) {
        await key(tester, digit);
        await tester.tap(find.text('保存并继续'));
        await tester.pump();
      }
      expect(entries.map((e) => e.amount.fen), [100, 200, 300]);
      await key(tester, '4');
      await tester.tap(find.byTooltip('备注（选填）'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'synthetic next draft');
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('撤销'), findsOneWidget);
      await tester.tap(find.text('撤销'));
      await tester.pump();
      expect(entries.map((e) => e.amount.fen), [100, 200]);
      expect(find.text('¥ 4'), findsOneWidget);
      expect(find.text('synthetic next draft'), findsOneWidget);
      await tester.tap(find.text('保存并继续'));
      await tester.pump();
      expect(entries.last.note, 'synthetic next draft');
      expect(entries.last.amount.fen, 400);
      await tester.pump(const Duration(milliseconds: 2900));
      await key(tester, '5');
      expect(find.text('撤销'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 101));
      expect(find.text('撤销'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending save blocks duplicate taps and back; failure keeps amount category date and note',
    (tester) async {
      var calls = 0;
      final pending = Completer<LedgerEntry>();
      EntryDraft? submitted;
      await screen(tester, (draft) {
        calls++;
        submitted = draft;
        return pending.future;
      }, (_) async {});
      await key(tester, '8');
      await tester.tap(find.byTooltip('备注（选填）'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'keep me');
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('饮品'));
      await tester.pump();
      // Two invocations before rebuilding exercise the in-method guard.
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存支出'))
          .onPressed!;
      save();
      save();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(QuickEntryPage), findsOneWidget);
      pending.completeError(
        const PocketFlowException(PocketFlowErrorCode.storageFailure),
      );
      await tester.pump();
      expect(find.text('¥ 8'), findsOneWidget);
      expect(find.text('keep me'), findsOneWidget);
      expect(submitted!.categoryId, 'drinks');
      expect(submitted!.localDate, '2026-10-21');
      expect(find.text('已选：饮品'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 1, reason: 'financial writes must not auto retry');
      expect(find.text('撤销'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'undo conflict keeps next draft and returning does not replay a save',
    (tester) async {
      var id = 0, undos = 0;
      await screen(tester, (draft) async => saved(draft, ++id), (_) async {
        undos++;
        throw const PocketFlowException(PocketFlowErrorCode.conflict);
      });
      await key(tester, '1');
      await tester.tap(find.text('保存并继续'));
      await tester.pump();
      await key(tester, '9');
      await tester.tap(find.text('撤销'));
      await tester.pump();
      expect(undos, 1);
      expect(find.text('¥ 9'), findsOneWidget);
      expect(find.text('撤销'), findsNothing);
      expect(find.byType(QuickEntryPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
