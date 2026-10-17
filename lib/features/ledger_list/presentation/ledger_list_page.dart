import 'package:flutter/material.dart';

import '../../../core/domain/ledger_entry.dart';
import '../../../core/domain/ledger_models.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/status_panel.dart';

class LedgerListPage extends StatelessWidget {
  const LedgerListPage({super.key, required this.data, this.onEntryTap});
  final LedgerMonthData data;
  final ValueChanged<LedgerEntry>? onEntryTap;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${data.month.year}年${data.month.month}月账单')),
    body: SafeArea(top: false, child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: data.entries.isEmpty
          ? const StatusPanel(title: '这个月还没有账单')
          : ListView.separated(padding: const EdgeInsets.all(20),
              itemCount: data.entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = data.entries[index];
                return EntryTile(entry: entry, categories: data.categories,
                  onTap: onEntryTap == null ? null : () => onEntryTap!(entry));
              }),
    ))),
  );
}
