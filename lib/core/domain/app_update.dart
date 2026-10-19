class InstalledApp {
  const InstalledApp({
    required this.versionName,
    required this.versionCode,
    required this.certificateSha256,
    required this.applicationId,
  });
  final String versionName, certificateSha256, applicationId;
  final int versionCode;
}

class AppUpdate {
  AppUpdate({
    required this.versionName,
    required this.versionCode,
    required this.bytes,
    required this.sha256,
    required this.downloadUrl,
    required this.releaseUrl,
    required List<String> notes,
  }) : notes = List.unmodifiable(notes);
  final String versionName, sha256;
  final int versionCode, bytes;
  final Uri downloadUrl, releaseUrl;
  final List<String> notes;
}

class UpdateUnavailable implements Exception {
  const UpdateUnavailable();
}
