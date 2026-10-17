import '../core/domain/backup_models.dart';
import '../core/domain/ledger_models.dart';
import '../core/domain/report_models.dart';

abstract interface class MonthlyReportService {
  MonthlyReport build(LedgerMonthData data, {required String asOfLocalDate});
}

abstract interface class MarkdownExporter {
  String render(MonthlyReport report);
}

abstract interface class BackupCodec {
  String encode(BackupDocument document);
  BackupDocument decode(String content);
}
