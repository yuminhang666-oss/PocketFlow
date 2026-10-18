import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/core/domain/category_catalog.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/budget/domain/budget_calculator.dart';
import 'package:pocketflow/features/export/domain/markdown_exporter.dart';
import 'package:pocketflow/features/statistics/domain/monthly_report_service.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/export/verification/c_contract_checks.dart'
    as c_checks;

class FixedClock implements Clock {
  const FixedClock();
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

EntryDraft draft(int fen, {String date = '2026-10-17', String note = ''}) =>
    EntryDraft(
      amount: Money.fromFen(fen),
      localDate: date,
      occurredAtUtcMs: DateTime(2026, 10, 17, 12).millisecondsSinceEpoch,
      categoryId: 'food',
      note: note,
    );

void main() {
  test(
    'real ledger CRUD, reports, JSON round-trip, recovery point and restart',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'pocketflow-integrated-',
      );
      final file = File('${dir.path}/ledger.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      const clock = FixedClock();
      var repository = DriftLedgerRepository(db, clock: clock);
      final month = CalendarMonth(2026, 10);
      Future<LedgerMonthData> snapshot() => repository.watchMonth(month).first;
      try {
        expect((await snapshot()).entries, isEmpty);
        expect(
          (await snapshot()).categories.length,
          recommendedCategories().length,
        );
        await repository.saveBudget(month, const Money.fromFen(150000));
        final first = await repository.createExpense(
          draft(3000, note: '午餐 | 中文\n备注'),
        );
        var data = await snapshot();
        var budget = const BudgetCalculator().calculate(
          month: month,
          today: clock.now(),
          budget: data.budget?.amount,
          entries: data.entries,
        );
        expect(budget.remaining?.fen, 147000);
        expect(budget.dailyAllowance?.fen, 9800);
        final second = await repository.createExpense(draft(2000));
        await repository.updateExpense(first.id, draft(3500));
        expect(
          (await snapshot()).entries.fold<int>(
            0,
            (sum, e) => sum + e.amount.fen,
          ),
          5500,
        );
        await repository.deleteEntry(second.id);
        data = await snapshot();
        final reports = DefaultMonthlyReportService(clock: clock);
        final report = reports.build(data, asOfLocalDate: '2026-10-17');
        expect(report.totalExpense.fen, 3500);
        expect(report.daily.fold<int>(0, (sum, d) => sum + d.amount.fen), 3500);
        expect(
          report.categoryTotals
              .where((c) => c.amount.fen > 0)
              .single
              .amount
              .fen,
          3500,
        );
        expect(
          DefaultMarkdownExporter(clock: clock).render(report),
          contains('35.00'),
        );
        final store = DriftBackupStore(db, clock: clock);
        final backup = await store.readAll();
        final encoded = const JsonBackupCodec().encode(backup);
        final decoded = const JsonBackupCodec().decode(encoded);
        await repository.createExpense(draft(5000));
        final restored = await store.replaceAll(decoded);
        expect(restored.entryCount, 1);
        expect((await snapshot()).entries.single.amount.fen, 3500);
        expect(
          (await store.readRecovery(restored.recoveryBackupId)).entries.length,
          2,
        );
        final before = const JsonBackupCodec().encode(await store.readAll());
        final badBackup = jsonDecode(encoded) as Map<String, dynamic>;
        badBackup['formatVersion'] = 99;
        expect(
          () => const JsonBackupCodec().decode(jsonEncode(badBackup)),
          throwsA(isA<PocketFlowException>()),
        );
        expect(const JsonBackupCodec().encode(await store.readAll()), before);
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        repository = DriftLedgerRepository(db, clock: clock);
        expect((await snapshot()).entries.single.amount.fen, 3500);
        expect((await snapshot()).budget?.amount.fen, 150000);
        expect(() => draft(0), throwsArgumentError);
        await expectLater(
          repository.createExpense(draft(1, date: '2026-10-18')),
          throwsA(isA<PocketFlowException>()),
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'actual C report/Markdown/JSON/confirmation contract scenarios',
    () async {
      await c_checks.main([]);
    },
  );
}
