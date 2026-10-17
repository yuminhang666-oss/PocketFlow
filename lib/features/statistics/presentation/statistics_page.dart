import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contracts/contracts.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../../../shared/widgets/status_panel.dart';
import '../domain/monthly_report_service.dart';
import 'fl_chart_widgets.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
    super.key,
    required this.month,
    required this.state,
    required this.clock,
    this.onChooseMonth,
  });
  final CalendarMonth month;
  final AsyncValue<LedgerMonthData> state;
  final Clock clock;
  final VoidCallback? onChooseMonth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('统计'),
      actions: [
        TextButton(
          onPressed: onChooseMonth,
          child: Text('${month.year}年${month.month}月 ▾'),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            StatusPanel(title: '统计暂不可用', message: presentationError(error)),
        data: (data) {
          if (month.compareTo(CalendarMonth.fromDate(clock.now())) > 0) {
            return const StatusPanel(
              title: '未来月份尚无实际统计',
              message: '可以先在首页设置预算',
            );
          }
          final reports = DefaultMonthlyReportService(clock: clock);
          final report = reports.build(
            data,
            asOfLocalDate: reports.defaultCutoff(month),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '本月累计支出',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      report.totalExpense.yuan,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text('统计至 ${report.asOfLocalDate}'),
                    const SizedBox(height: 24),
                    Text(
                      '钱花在哪里',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    CategoryExpenseDonut(report: report),
                    const SizedBox(height: 24),
                    DailyExpenseBars(report: report),
                    const SizedBox(height: 24),
                    RemainingBudgetLines(report: report),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
