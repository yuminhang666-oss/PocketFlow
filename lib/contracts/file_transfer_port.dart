final class SelectedTextFile {
  const SelectedTextFile({required this.name, required this.content});
  final String name;
  final String content;
}

abstract interface class FileTransferPort {
  /// True on success; false when the user cancels.
  Future<bool> saveText({required String suggestedName,
      required String mimeType, required String content});
  Future<bool> shareTextFile({required String suggestedName,
      required String mimeType, required String content});
  /// Null when the user cancels. Never auto-import the picked content.
  Future<SelectedTextFile?> pickJsonText();
}
