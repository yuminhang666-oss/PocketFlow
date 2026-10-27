import 'package:flutter/material.dart';
import 'package:pocketflow/l10n/app_strings.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/completed_modal.dart';
import '../../../shared/widgets/presentation_errors.dart';

Future<void> increaseSavingsGoal(
  BuildContext context,
  SavingsGoal goal,
  Future<void> Function(SavingsGoal) save,
) async {
  final input = TextEditingController();
  var busy = false;
  String? error;
  await showCompletedBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, update) {
        Money? next;
        try {
          next = Money.fromFen(goal.saved.fen + Money.parse(input.text).fen);
        } catch (_) {
          /* Empty or partial input. */
        }
        return PopScope(
          canPop: !busy,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(sheet).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, '增加进度'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(goal.name),
                Text(tr(context, '当前累计 {0}', [goal.saved.yuan])),
                TextField(
                  controller: input,
                  autofocus: true,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => update(() {}),
                  decoration: InputDecoration(
                    labelText: tr(context, '本次增加（元）'),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                Text(tr(context, '增加后累计 {0}', [next?.yuan ?? '—'])),
                Text(tr(context, '独立登记进度，不扣减生活费预算')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            final added = Money.parse(input.text);
                            if (added.fen <= 0) {
                              throw const FormatException('请输入大于零的金额');
                            }
                            final updated = SavingsGoal(
                              id: goal.id,
                              name: goal.name,
                              target: goal.target,
                              saved: Money.fromFen(goal.saved.fen + added.fen),
                            );
                            update(() {
                              busy = true;
                              error = null;
                            });
                            await save(updated);
                            if (sheet.mounted) Navigator.pop(sheet);
                          } catch (e) {
                            if (sheet.mounted) {
                              update(() {
                                busy = false;
                                error = tr(
                                  sheet,
                                  e is FormatException
                                      ? e.message
                                      : presentationError(e),
                                );
                              });
                            }
                          }
                        },
                  child: Text(tr(context, busy ? '保存中…' : '保存进度')),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(sheet),
                  child: Text(tr(context, '取消')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  input.dispose();
}
