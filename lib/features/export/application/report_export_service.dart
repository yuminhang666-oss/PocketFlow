import '../../../contracts/contracts.dart';
import '../domain/csv_exporter.dart';
import '../domain/markdown_exporter.dart';

enum ReportFileFormat { markdown, entriesCsv, summaryCsv }

typedef ReportFile = ({String name, String mime, String content});

/// Composition supplies the file port. Cancellation is returned as false.
final class ReportExportService {
  const ReportExportService({required this.files, required this.markdown});
  final FileTransferPort files;
  final MarkdownExporter markdown;

  ReportFile _monthlyMarkdown(MonthlyReport report) => (
    name: 'pocketflow-${report.month.key}.md',
    mime: 'text/markdown',
    content: markdown.render(report),
  );

  Future<bool> save(MonthlyReport report) => transfer(_monthlyMarkdown(report));
  Future<bool> share(MonthlyReport report) =>
      transfer(_monthlyMarkdown(report), share: true);

  ReportFile render(
    WeeklyReport report,
    ReportFileFormat format, {
    MonthlyReport? month,
    String? filteredMonth,
  }) {
    const csv = CsvReportExporter();
    final data = report.data;
    final prefix =
        'pocketflow-${month?.month.key ?? '${data.start}_to_${data.end}'}';
    return switch (format) {
      ReportFileFormat.markdown =>
        month != null
            ? _monthlyMarkdown(month)
            : (
                name: '$prefix.md',
                mime: 'text/markdown',
                content: renderRangeMarkdown(report),
              ),
      ReportFileFormat.entriesCsv => (
        name: filteredMonth == null
            ? '$prefix-entries.csv'
            : 'pocketflow-$filteredMonth-filtered.csv',
        mime: 'text/csv',
        content: csv.entries(data),
      ),
      ReportFileFormat.summaryCsv => (
        name: '$prefix-summary.csv',
        mime: 'text/csv',
        content: csv.summary(report),
      ),
    };
  }

  Future<bool> transfer(ReportFile file, {bool share = false}) {
    return share
        ? files.shareTextFile(
            suggestedName: file.name,
            mimeType: file.mime,
            content: file.content,
          )
        : files.saveText(
            suggestedName: file.name,
            mimeType: file.mime,
            content: file.content,
          );
  }
}
