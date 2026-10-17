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
  ),
);

class BudgetEditorSheet extends StatefulWidget {
  const BudgetEditorSheet({
    super.key,
    required this.month,
    required this.onSave,
    this.initialBudget,
  });
  final CalendarMonth month;
  final Money? initialBudget;
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
          _error = presentationError(error);
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
              '${widget.month.year}年${widget.month.month}月预算',
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
                labelText: '本月生活费',
                prefixText: '¥ ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            const Text('预算可以为零，保存后将更新该月预算信息。'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存预算'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    ),
  );
}
