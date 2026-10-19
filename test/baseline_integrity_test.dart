import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/recovery_codec.dart';

// Synthetic baseline fixtures; never connect to a user's database.
class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 19, 12);
}

void main() {
  const codec = JsonBackupCodec();
  late AppDatabase db;
  late DriftLedgerRepository repo;
  late DriftBackupStore store;
  late BackupDocument snapshot;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLedgerRepository(db, clock: _Clock());
    store = DriftBackupStore(db, clock: _Clock());
    await repo.createExpense(
      EntryDraft(
        amount: const Money.fromFen(1200),
        localDate: '2026-10-19',
        occurredAtUtcMs: 100,
        categoryId: 'food',
        note: 'SYNTHETIC integrity fixture',
      ),
    );
    snapshot = await store.readAll();
  });
  tearDown(() => db.close());

  test('public JSON rejects explicit entry/category kind mismatch', () {
    final raw = jsonDecode(codec.encode(snapshot)) as Map<String, dynamic>;
    raw['entries'][0]['kind'] = 'income';
    expect(
      () => codec.decode(jsonEncode(raw)),
      throwsA(isA<PocketFlowException>()),
    );
  });

  test('public JSON rejects explicit template/category kind mismatch', () {
    final raw = jsonDecode(codec.encode(snapshot)) as Map<String, dynamic>;
    raw['profile']['templates'] = [
      {
        'id': 'template',
        'name': 'SYNTHETIC',
        'kind': 'income',
        'amountFen': 100,
        'categoryId': 'food',
        'note': '',
      },
    ];
    expect(
      () => codec.decode(jsonEncode(raw)),
      throwsA(isA<PocketFlowException>()),
    );
  });

  test(
    'typed restore refuses mismatch before changing ledger or recovery points',
    () async {
      final entry = snapshot.entries.single;
      final bad = BackupDocument(
        exportedAtUtcMs: snapshot.exportedAtUtcMs,
        categories: snapshot.categories,
        budgets: snapshot.budgets,
        profile: snapshot.profile,
        entries: [
          LedgerEntry(
            id: entry.id,
            amount: entry.amount,
            localDate: entry.localDate,
            categoryId: entry.categoryId,
            kind: EntryKind.income,
            note: entry.note,
            occurredAtUtcMs: entry.occurredAtUtcMs,
            createdAtUtcMs: entry.createdAtUtcMs,
            updatedAtUtcMs: entry.updatedAtUtcMs,
          ),
        ],
      );
      final before = codec.encode(snapshot);
      await expectLater(
        store.replaceAll(bad),
        throwsA(isA<PocketFlowException>()),
      );
      expect(codec.encode(await store.readAll()), before);
      expect(await db.select(db.recoverySnapshots).get(), isEmpty);
    },
  );

  test('private recovery decoding rejects explicit kind mismatch', () {
    final raw =
        jsonDecode(const RecoveryCodec().encode(snapshot))
            as Map<String, dynamic>;
    raw['entries'][0][4] = 'income';
    expect(
      () => const RecoveryCodec().decode(jsonEncode(raw)),
      throwsA(anything),
    );
  });

  test(
    'typed restore refuses incompatible template without a recovery write',
    () async {
      final bad = BackupDocument(
        exportedAtUtcMs: snapshot.exportedAtUtcMs,
        categories: snapshot.categories,
        budgets: snapshot.budgets,
        entries: snapshot.entries,
        profile: PersonalProfile(
          templates: [
            EntryTemplate(
              id: 'template',
              name: 'SYNTHETIC',
              kind: EntryKind.income,
              amount: const Money.fromFen(100),
              categoryId: 'food',
            ),
          ],
        ),
      );
      await expectLater(
        store.replaceAll(bad),
        throwsA(isA<PocketFlowException>()),
      );
      expect(codec.encode(await store.readAll()), codec.encode(snapshot));
      expect(await db.select(db.recoverySnapshots).get(), isEmpty);
    },
  );

  test(
    'incompatible stored rows report corruption without repairing kind',
    () async {
      await db.customStatement("UPDATE ledger_entries SET kind = 'income'");
      await expectLater(
        store.readAll(),
        throwsA(
          isA<PocketFlowException>().having(
            (e) => e.code,
            'code',
            PocketFlowErrorCode.dataCorrupted,
          ),
        ),
      );
      final row = await db
          .customSelect('SELECT kind FROM ledger_entries')
          .getSingle();
      expect(row.read<String>('kind'), 'income');
    },
  );

  test(
    'legacy null-kind categories retain income without changing fields',
    () async {
      final raw = jsonDecode(codec.encode(snapshot)) as Map<String, dynamic>;
      for (final category in raw['categories'] as List) {
        category['kind'] = null;
      }
      raw['entries'][0]['kind'] = 'income';
      final legacy = codec.decode(jsonEncode(raw));
      await store.replaceAll(legacy);
      final restored = (await store.readAll()).entries.single;
      expect(restored.kind, EntryKind.income);
      expect(restored.categoryId, 'food');
      expect(restored.amount.fen, 1200);
      expect(restored.localDate, '2026-10-19');
      expect(restored.createdAtUtcMs, snapshot.entries.single.createdAtUtcMs);
    },
  );

  test('blank category names are rejected without silently renaming', () {
    for (final name in [' ', '\t\n', '\u3000']) {
      expect(
        () => Category(id: 'blank', name: name, sortOrder: 0),
        throwsArgumentError,
      );
    }
  });

  test('blank category name in JSON fails preflight', () {
    final raw = jsonDecode(codec.encode(snapshot)) as Map<String, dynamic>;
    raw['categories'][0]['name'] = ' \t ';
    expect(
      () => codec.decode(jsonEncode(raw)),
      throwsA(isA<PocketFlowException>()),
    );
  });
}
