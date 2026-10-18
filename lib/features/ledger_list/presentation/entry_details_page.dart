import 'package:flutter/material.dart';

import '../../../core/domain/ledger_entry.dart';
import '../../../core/domain/ledger_models.dart';
import '../../../core/domain/category_catalog.dart';
import '../../../shared/widgets/amount_text.dart';

class EntryDetailsPage extends StatelessWidget {
  const EntryDetailsPage({
    super.key,
    required this.entry,
    required this.categories,
    this.onEdit,
    this.onDelete,
  });
  final LedgerEntry entry;
  final List<Category> categories;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final names = categories.where((c) => c.id == entry.categoryId);
    return Scaffold(
      appBar: AppBar(title: const Text('账单详情')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(entry.kind == EntryKind.expense ? '支出金额' : '收入金额'),
                  const SizedBox(height: 12),
                  AmountText(
                    entry.amount,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('分类'),
                    subtitle: Text(
                      names.isEmpty
                          ? '未识别分类'
                          : categoryPath(names.first, categories),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('发生日期'),
                    subtitle: Text(entry.localDate),
                  ),
                  const SizedBox(height: 16),
                  const Text('备注'),
                  const SizedBox(height: 8),
                  SelectableText(entry.note.isEmpty ? '无备注' : entry.note),
                  const SizedBox(height: 24),
                  if (onEdit != null)
                    FilledButton.tonalIcon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑账单'),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除账单'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
