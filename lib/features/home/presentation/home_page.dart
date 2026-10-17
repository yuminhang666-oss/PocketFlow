import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/budget_snapshot.dart';
import '../../../core/domain/calendar_month.dart';
import '../../../core/domain/ledger_entry.dart';
import '../../../core/domain/ledger_models.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../../../shared/widgets/status_panel.dart';
import 'widgets/daily_allowance_panel.dart';

/// Composition must derive both record fields from the SAME LedgerMonthData.
/// No repository, database subscription or financial calculation lives here.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.month,
    required this.state,
    this.onAddExpense,
    this.onSetBudget,
    this.onOpenLedger,
    this.onEntryTap,
    this.onChooseMonth,
    this.onRefresh,
  });

  final CalendarMonth month;
  final AsyncValue<(LedgerMonthData, BudgetSnapshot)> state;
  final VoidCallback? onAddExpense;
  final VoidCallback? onSetBudget;
  final VoidCallback? onOpenLedger;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final VoidCallback? onChooseMonth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final stackedHeader =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    final data = state.asData?.value;
    final previous = state.hasValue ? state.value : null;
    final content = data ?? previous;
    Widget body;
    if (content == null) {
      body = StatusPanel(
        title: state.hasError ? '暂时无法读取账本' : '正在读取账本',
        message: state.hasError ? presentationError(state.error!) : null,
        loading: !state.hasError,
        icon: Icons.cloud_off_rounded,
        actionLabel: '重试',
        onAction: onRefresh == null
            ? null
            : () {
                onRefresh!();
              },
      );
    } else if (content.$1.month != month || content.$2.month != month) {
      body = StatusPanel(title: '月份数据正在更新', loading: true);
    } else {
      final ledger = content.$1;
      final snapshot = content.$2;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.hasError) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded),
                const SizedBox(width: 8),
                const Expanded(child: Text('更新失败，当前显示上次结果')),
                if (onRefresh != null)
                  TextButton(
                    onPressed: () {
                      onRefresh!();
                    },
                    child: const Text('重试'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (state.isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          DailyAllowancePanel(snapshot: snapshot, onSetBudget: onSetBudget),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text('最近消费', style: Theme.of(context).textTheme.titleLarge),
              if (onOpenLedger != null)
                TextButton(onPressed: onOpenLedger, child: const Text('查看全部')),
            ],
          ),
          if (ledger.entries.where((e) => e.kind == EntryKind.expense).isEmpty)
            StatusPanel(
              title: '还没有消费记录',
              message: '从今天的一笔消费开始',
              actionLabel: '记第一笔',
              onAction: onAddExpense,
            )
          else
            ...ledger.entries
                .where((e) => e.kind == EntryKind.expense)
                .take(5)
                .map(
                  (entry) => EntryTile(
                    entry: entry,
                    categories: ledger.categories,
                    onTap: onEntryTap == null ? null : () => onEntryTap!(entry),
                  ),
                ),
        ],
      );
    }
    Widget scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stackedHeader)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onChooseMonth,
                      child: Text(
                        '${month.year}年${month.month}月${onChooseMonth == null ? '' : ' ▾'}',
                      ),
                    ),
                  ),
                ),
              body,
            ],
          ),
        ),
      ),
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketFlow'),
        actions: stackedHeader
            ? null
            : [
                TextButton(
                  onPressed: onChooseMonth,
                  child: Text(
                    '${month.year}年${month.month}月${onChooseMonth == null ? '' : ' ▾'}',
                  ),
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: SafeArea(top: false, child: scroll),
      floatingActionButton: onAddExpense == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text('记一笔'),
            ),
    );
  }
}
