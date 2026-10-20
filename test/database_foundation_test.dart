import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/core/database/app_database.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';

Future<void> insertExpense(
  AppDatabase db,
  String id,
  Object amount, {
  String category = 'food',
}) => db.customStatement(
  'INSERT INTO ledger_entries '
  '(id, amount_fen, kind, occurred_local, occurred_at_utc_ms, category_id, '
  'note, created_at_utc_ms, updated_at_utc_ms) '
  "VALUES (?, ?, 'expense', '2026-10-17', 100, ?, '', 100, 100)",
  [id, amount, category],
);

void main() {
  group('real generated Drift schema', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test(
      'fresh schema seeds categories and enables foreign keys and index',
      () async {
        final categories = await db.select(db.categories).get();
        expect(
          categories.map((c) => c.id).toSet(),
          generalRecommendedCategories().map((c) => c.id).toSet(),
        );
        expect(
          categories.where(
            (c) => c.parentId == null && c.categoryKind == 'expense',
          ),
          hasLength(15),
        );
        expect(
          categories.where(
            (c) => c.parentId == null && c.categoryKind == 'income',
          ),
          hasLength(7),
        );
        final foreignKeys = await db
            .customSelect('PRAGMA foreign_keys')
            .getSingle();
        expect(foreignKeys.read<int>('foreign_keys'), 1);
        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND name='ledger_entries_local_date'",
            )
            .get();
        expect(indexes, hasLength(1));
      },
    );

    test(
      'SQLite rejects noninteger, nonpositive and excessive amounts',
      () async {
        for (final amount in <Object>[0, -1, 1.5, 100000000000]) {
          await expectLater(
            insertExpense(db, 'invalid', amount),
            throwsA(anything),
          );
        }
        await insertExpense(db, 'one-fen', 1);
        await insertExpense(db, 'maximum', 99999999999);
        expect(await db.select(db.ledgerEntries).get(), hasLength(2));
      },
    );

    test('SQLite rejects duplicate IDs and unknown categories', () async {
      await insertExpense(db, 'saved', 100);
      await expectLater(insertExpense(db, 'saved', 100), throwsA(anything));
      await expectLater(
        insertExpense(db, 'orphan', 100, category: 'missing'),
        throwsA(anything),
      );
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
    });

    test('failed multiwrite transaction retains the previous record', () async {
      await insertExpense(db, 'original', 100);
      await expectLater(
        db.transaction(() async {
          await db.customStatement('DELETE FROM ledger_entries');
          await insertExpense(db, 'new', 200);
          await insertExpense(db, 'invalid', 0);
        }),
        throwsA(anything),
      );
      final entries = await db.select(db.ledgerEntries).get();
      expect(entries.single.id, 'original');
      expect(entries.single.amountFen, 100);
    });
  });

  test(
    'real SQLite file retains entries after closing and reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp('pocketflow-qa-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}ledger.sqlite',
      );
      try {
        final first = AppDatabase(NativeDatabase(file));
        try {
          await insertExpense(first, 'persistent', 12345);
        } finally {
          await first.close();
        }
        final second = AppDatabase(NativeDatabase(file));
        try {
          final entries = await second.select(second.ledgerEntries).get();
          expect(entries.single.id, 'persistent');
          expect(entries.single.amountFen, 12345);
          expect(
            await second.select(second.categories).get(),
            hasLength(generalRecommendedCategories().length),
          );
        } finally {
          await second.close();
        }
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
        await directory.delete();
      }
    },
  );
}
