import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/domain/calendar_month.dart';
import '../../../core/domain/ledger_models.dart';
import '../../../core/domain/money.dart';
import '../../../shared/widgets/presentation_errors.dart';

Future<bool?> showBudgetEditor(
  BuildContext context, {
  required CalendarMonth month,
  required Future<MonthlyBudget> Function(Money) onSave,
  Money? initialBudget,
  Money spent = const Money.fromFen(0),
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (context) => BudgetEditorSheet(
    month: month,
    onSave: onSave,
    initialBudget: initialBudget,
    spent: spent,
  ),
);

class BudgetEditorSheet extends StatefulWidget {
  const BudgetEditorSheet({
    super.key,
    required this.month,
    required this.onSave,
    this.initialBudget,
    this.spent = const Money.fromFen(0),
  });
  final CalendarMonth month;
  final Money? initialBudget;
  final Money spent;
  final Future<MonthlyBudget> Function(Money) onSave;
  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  late final _controller = TextEditingController(
    text: widget.initialBudget?.decimal ?? '',
  );
  bool _saving = false;
  bool _saved = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    try {
      final value = _controller.text;
      final budget = Money.parse(value.endsWith('.') ? '${value}00' : value);
      setState(() {
        _saving = true;
        _error = null;
      });
      if (budget.fen < 0) throw const FormatException('预算不能为负数');
      if (budget.fen < widget.spent.fen) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(tr(context, "预算低于已支出金额")),
            content: Text(
              tr(context, "保存后将显示已超支 {0}，原账单保持不变。", [
                Money.fromFen(widget.spent.fen - budget.fen).yuan,
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(tr(context, "取消")),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(tr(context, "确认保存")),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
      await widget.onSave(budget);
      if (mounted) {
        setState(() => _saved = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = tr(context, presentationError(error));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving || _saved,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, "调整 {0}年{1}月预算", [
                widget.month.year,
                widget.month.month,
              ]),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d{0,9}(?:\.\d{0,2})?$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              decoration: InputDecoration(
                labelText: tr(context, "本月生活费"),
                prefixText: '¥ ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Text(tr(context, "预算可以为零，保存后将更新该月预算信息。")),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? tr(context, "保存中…") : tr(context, "保存预算")),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: Text(tr(context, "取消")),
            ),
          ],
        ),
      ),
    ),
  );
}
