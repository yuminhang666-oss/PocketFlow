import '../core/domain/backup_models.dart';

abstract interface class BackupStore {
  Future<BackupDocument> readAll();
  Future<RestoreResult> replaceAll(BackupDocument document);
}
