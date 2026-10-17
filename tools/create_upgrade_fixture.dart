import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';

class _FixtureClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 17, 12);
}

// Run explicitly with flutter test; this tool is outside test/ and does not
// write a fixture during normal regression tests. All records are synthetic.
void main() {
  test('write a v2 test ledger for the emulator-only upgrade check', () async {
    final path = Platform.environment['POCKETFLOW_UPGRADE_FIXTURE'];
    if (path == null || path.isEmpty) {
      throw StateError(
        'Set POCKETFLOW_UPGRADE_FIXTURE to a new local test file.',
      );
    }
    final file = File(path);
    if (file.existsSync()) throw StateError('Preserving the existing fixture.');
    file.parent.createSync(recursive: true);
    final database = AppDatabase(NativeDatabase(file));
    final clock = _FixtureClock();
    final repository = DriftLedgerRepository(
      database,
      clock: clock,
      idGenerator: () => 'emulator-upgrade-fixture',
    );
    try {
      final month = CalendarMonth(2026, 10);
      await repository.saveBudget(month, Money.fromFen(150000));
      await repository.createExpense(
        EntryDraft(
          amount: Money.fromFen(3000),
          localDate: '2026-10-17',
          categoryId: 'food',
          note: '模拟器覆盖更新测试夹具',
          occurredAtUtcMs: clock.now().millisecondsSinceEpoch,
        ),
      );
      final contents = await repository.watchMonth(month).first;
      expect(contents.budget?.amount.fen, 150000);
      expect(contents.entries.single.id, 'emulator-upgrade-fixture');
      expect(contents.entries.single.amount.fen, 3000);
    } finally {
      await database.close();
    }
  });
}
