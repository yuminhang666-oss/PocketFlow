enum PocketFlowErrorCode {
  invalidAmount,
  invalidDate,
  invalidCategory,
  notFound,
  storageFailure,
  dataCorrupted,
  unsupportedBackupVersion,
  invalidBackup,
  backupFailed,
  restoreFailed,
  exportFailed,
  importFailed,
}

final class PocketFlowException implements Exception {
  const PocketFlowException(this.code, {this.cause});
  final PocketFlowErrorCode code;
  final Object? cause;

  @override
  String toString() => 'PocketFlowException(${code.name})';
}
