import 'package:drift/drift.dart';

import '../../../contracts/contracts.dart';
import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/database/ledger_reader.dart';
import '../../../core/database/ledger_validation.dart';
import 'drift_ledger_repository.dart';
import 'entry_id.dart';
import 'recovery_codec.dart';

class DriftBackupStore implements BackupStore {
  DriftBackupStore(
    this.database, {
    Clock clock = const SystemClock(),
    String Function()? idGenerator,
  }) : _clock = clock,
       _newId = idGenerator ?? newEntryId,
       _reader = LedgerReader(database);

  final AppDatabase database;
  final Clock _clock;
  final String Function() _newId;
  final LedgerReader _reader;
  static const _codec = RecoveryCodec();

  @override
  Future<BackupDocument> readAll() async {
    try {
      return await _reader.readAll(_clock.now().millisecondsSinceEpoch);
    } catch (error, stack) {
      Error.throwWithStackTrace(storageException(error), stack);
    }
  }

  @override
  Future<RestoreResult> replaceAll(BackupDocument document) async {
    // The shared typed document has a fixed v1 schema. C must reject unsupported
    // external file versions before constructing it; B checks values/relations.
    try {
      validateBackup(document);
    } catch (error) {
      throw PocketFlowException(PocketFlowErrorCode.invalidBackup, cause: error);
    }
    try {
      return await database.transaction(() async {
        final now = _clock.now().millisecondsSinceEpoch;
        final old = await _reader.readAll(now);
        final recoveryId = _newId();
        try {
          // This write and the replacement commit or roll back together.
          // A failed archive write MUST stop before deleting anything.
          await database.customInsert(
            'INSERT INTO recovery_snapshots(id, created_at_utc_ms, payload) '
            'VALUES (?, ?, ?)',
            variables: [
              Variable.withString(recoveryId),
              Variable.withInt(now),
              Variable.withString(_codec.encode(old)),
            ],
            updates: {database.recoverySnapshots},
          );
        } catch (error) {
          throw PocketFlowException(PocketFlowErrorCode.backupFailed, cause: error);
        }

        await database.delete(database.ledgerEntries).go();
        await database.delete(database.monthlyBudgets).go();
        await database.delete(database.categories).go();
        for (final category in document.categories) {
          await database.customInsert(
            'INSERT INTO categories(id, name, sort_order, is_archived) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString(category.id),
              Variable.withString(category.name),
              Variable.withInt(category.sortOrder),
              Variable.withInt(category.isArchived ? 1 : 0),
            ],
            updates: {database.categories},
          );
        }
        for (final budget in document.budgets) {
          await database.customInsert(
            'INSERT INTO monthly_budgets(month, amount_fen, updated_at_utc_ms) '
            'VALUES (?, ?, ?)',
            variables: [
              Variable.withString(budget.month.key),
              Variable.withInt(budget.amount.fen),
              Variable.withInt(budget.updatedAtUtcMs),
            ],
            updates: {database.monthlyBudgets},
          );
        }
        for (final entry in document.entries) {
          await insertEntry(database, entry);
        }
        if ((await database.customSelect('PRAGMA foreign_key_check').get())
            .isNotEmpty) {
          throw const PocketFlowException(PocketFlowErrorCode.invalidBackup);
        }
        return RestoreResult(
          entryCount: document.entries.length,
          budgetCount: document.budgets.length,
          categoryCount: document.categories.length,
          recoveryBackupId: recoveryId,
        );
      });
    } catch (error, stack) {
      Error.throwWithStackTrace(
        error is PocketFlowException ? error : PocketFlowException(
          PocketFlowErrorCode.restoreFailed, cause: error,
        ),
        stack,
      );
    }
  }

  /// Internal recovery access for integration/diagnostics. Exposing a recovery UI
  /// still needs a main-owned contract; C must not read this table directly.
  Future<BackupDocument> readRecovery(String id) async {
    try {
      final row = await database.customSelect(
        'SELECT payload FROM recovery_snapshots WHERE id = ?',
        variables: [Variable.withString(id)],
      ).getSingleOrNull();
      if (row == null) {
        throw const PocketFlowException(PocketFlowErrorCode.notFound);
      }
      try {
        return _codec.decode(row.read<String>('payload'));
      } catch (error) {
        throw PocketFlowException(PocketFlowErrorCode.dataCorrupted, cause: error);
      }
    } catch (error, stack) {
      Error.throwWithStackTrace(storageException(error), stack);
    }
  }
}
