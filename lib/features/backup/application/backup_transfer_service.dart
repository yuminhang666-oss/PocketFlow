import '../../../contracts/contracts.dart';

/// Confirmation receives the exact immutable preflight document. No implicit
/// merge/retry. Every replace operation requires a new explicit confirmation.
typedef ConfirmBackupReplacement =
    Future<bool> Function(BackupDocument document);

final class BackupTransferService {
  BackupTransferService({
    required this.store,
    required this.files,
    required this.codec,
    this._clock = const SystemClock(),
  });
  final BackupStore store;
  final FileTransferPort files;
  final BackupCodec codec;
  final Clock _clock;
  bool _restoring = false;

  Future<bool> save() async => files.saveText(
    suggestedName: 'pocketflow-backup-${calendarDayKey(_clock.now())}.json',
    mimeType: 'application/json',
    content: codec.encode(await store.readAll()),
  );

  Future<bool> share() async => files.shareTextFile(
    suggestedName: 'pocketflow-backup-${calendarDayKey(_clock.now())}.json',
    mimeType: 'application/json',
    content: codec.encode(await store.readAll()),
  );

  /// Null on picker/confirmation cancellation; B owns recovery point + atomicity.
  /// A must show counts, destructive replacement warning and the returned
  /// recoveryBackupId. Empty backups also require explicit confirmation.
  Future<RestoreResult?> restore({
    required ConfirmBackupReplacement confirm,
  }) async {
    if (_restoring) {
      throw const PocketFlowException(PocketFlowErrorCode.restoreFailed);
    }
    _restoring = true;
    try {
      final picked = await files.pickJsonText();
      if (picked == null) return null;
      final document = codec.decode(picked.content);
      if (!await confirm(document)) return null;
      return await store.replaceAll(document);
    } finally {
      _restoring = false;
    }
  }
}
