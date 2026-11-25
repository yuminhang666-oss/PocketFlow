import 'package:flutter/material.dart';
import 'package:pocketflow/l10n/app_strings.dart';

import '../../../contracts/contracts.dart';
import '../application/report_export_service.dart';

Future<({ReportFileFormat format, bool share})?> showReportExportPreview(
  BuildContext context,
  WeeklyReport report, {
  bool filtered = false,
}) {
  final data = report.data;
  final formats = filtered
      ? [ReportFileFormat.entriesCsv]
      : ReportFileFormat.values;
  var format = formats.first;
  return showModalBottomSheet<({ReportFileFormat format, bool share})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, update) {
            void finish(bool share) =>
                Navigator.pop(sheet, (format: format, share: share));
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, '导出预览'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('${data.start} – ${data.end}'),
                Text(tr(context, '当前范围共 {0} 笔', [data.entries.length])),
                Text(
                  tr(context, '支出 {0} · 收入 {1}', [
                    report.expense.yuan,
                    report.income.yuan,
                  ]),
                ),
                if (!filtered) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in formats)
                        ChoiceChip(
                          label: Text(switch (value) {
                            ReportFileFormat.markdown => 'Markdown',
                            ReportFileFormat.entriesCsv => tr(
                              context,
                              '明细 CSV',
                            ),
                            ReportFileFormat.summaryCsv => tr(
                              context,
                              '汇总 CSV',
                            ),
                          }),
                          selected: format == value,
                          onSelected: (_) => update(() => format = value),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => finish(false),
                      child: Text(tr(context, '保存文件')),
                    ),
                    OutlinedButton(
                      onPressed: () => finish(true),
                      child: Text(tr(context, '分享文件')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheet),
                      child: Text(tr(context, '取消')),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
