import '../../../contracts/contracts.dart';

/// A injects FileTransferPort; composition injects the production adapter.
/// Cancellation is returned as false. No network or clipboard side effects.
final class ReportExportService {
  const ReportExportService({required this.files, required this.markdown});
  final FileTransferPort files;
  final MarkdownExporter markdown;

  Future<bool> save(MonthlyReport report) => files.saveText(
      suggestedName: 'pocketflow-${report.month.key}.md',
      mimeType: 'text/markdown', content: markdown.render(report));

  Future<bool> share(MonthlyReport report) => files.shareTextFile(
      suggestedName: 'pocketflow-${report.month.key}.md',
      mimeType: 'text/markdown', content: markdown.render(report));
}
