import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/composition/pocketflow_root.dart';
import 'core/database/app_database.dart';
import 'features/transactions/data/drift_backup_store.dart';
import 'features/transactions/data/drift_ledger_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.local();
  runApp(
    ProviderScope(
      overrides: [
        ledgerRepositoryProvider.overrideWithValue(
          DriftLedgerRepository(database),
        ),
        backupStoreProvider.overrideWithValue(DriftBackupStore(database)),
      ],
      child: const PocketFlowRoot(),
    ),
  );
}
