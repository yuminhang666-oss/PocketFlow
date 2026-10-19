import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

class _Files implements FileTransferPort {
  String? saved;
  String? picked;
  @override
  Future<bool> saveText({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) async {
    saved = content;
    return true;
  }

  @override
  Future<bool> shareTextFile({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) => saveText(
    suggestedName: suggestedName,
    mimeType: mimeType,
    content: content,
  );
  @override
  Future<SelectedTextFile?> pickJsonText() async => picked == null
      ? null
      : SelectedTextFile(name: 'fixture.json', content: picked!);
}

void main() {
  testWidgets(
    'production composition: budget, entry, edit/delete, charts and file flows',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final clock = _Clock();
      final files = _Files();
      final repo = DriftLedgerRepository(db, clock: clock);
      final backup = DriftBackupStore(db, clock: clock);
      final month = CalendarMonth(2026, 10);
      Future<void> hit(Finder finder) async {
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 120));
        });
        await tester.pumpAndSettle();
      }

      Future<LedgerMonthData> read() async => ProviderScope.containerOf(
        tester.element(find.byType(PocketFlowRoot)),
      ).read(monthDataProvider(month)).requireValue;
      await tester.runAsync(() => repo.watchMonth(month).first);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerRepositoryProvider.overrideWithValue(repo),
            backupStoreProvider.overrideWithValue(backup),
            clockProvider.overrideWithValue(clock),
            fileTransferProvider.overrideWithValue(files),
          ],
          child: const PocketFlowRoot(),
        ),
      );
      try {
        await tester.pumpAndSettle();
        expect(find.text('待设置预算'), findsOneWidget);
        await hit(find.text('设置本月预算'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1500');
        await hit(find.text('保存预算'));
        await tester.pumpAndSettle();
        expect((await read()).budget?.amount.fen, 150000);
        await hit(find.text('＋记账'));
        await tester.pumpAndSettle();
        await hit(find.widgetWithText(TextButton, '3'));
        await hit(find.widgetWithText(TextButton, '0'));
        await tester.pump();
        await hit(find.text('保存支出'));
        await tester.pumpAndSettle();
        var data = await read();
        expect(data.entries.single.amount.fen, 3000);
        expect(find.textContaining('1,470.00'), findsWidgets);
        await hit(find.text('餐饮').last);
        await tester.pumpAndSettle();
        expect(find.text('编辑账单'), findsOneWidget);
        await hit(find.text('编辑账单'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 5; i++) {
          await hit(find.byIcon(Icons.backspace_outlined));
        }
        await hit(find.widgetWithText(TextButton, '4'));
        await hit(find.widgetWithText(TextButton, '0'));
        await tester.pump();
        await hit(find.text('保存修改'));
        await tester.pumpAndSettle();
        data = await read();
        expect(data.entries.single.amount.fen, 4000);
        await hit(find.text('统计').last);
        await tester.pumpAndSettle();
        expect(find.text('钱花在哪里'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await hit(find.text('我的').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('导出月报'));
        await hit(find.text('导出月报'));
        await tester.pumpAndSettle();
        await hit(find.text('Markdown 月报 · 保存文件'));
        await tester.pumpAndSettle();
        expect(files.saved, contains('40.00'));
        files.picked = const JsonBackupCodec().encode(
          (await tester.runAsync(() => backup.readAll()))!,
        );
        await tester.ensureVisible(find.text('恢复备份'));
        await hit(find.text('恢复备份'));
        await tester.pumpAndSettle();
        expect(find.text('恢复并替换现有账本？'), findsOneWidget);
        await hit(find.text('确认替换'));
        await tester.pumpAndSettle();
        expect(find.text('恢复完成'), findsOneWidget);
        await hit(find.text('完成'));
        await tester.pumpAndSettle();
        await hit(find.text('总览').last);
        await tester.pumpAndSettle();
        await hit(find.text('餐饮').last);
        await tester.pumpAndSettle();
        await hit(find.text('删除账单'));
        await tester.pumpAndSettle();
        await hit(find.text('删除'));
        await tester.pumpAndSettle();
        expect((await read()).entries, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
