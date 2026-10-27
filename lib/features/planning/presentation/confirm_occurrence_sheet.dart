import 'package:flutter/material.dart';
import 'package:pocketflow/l10n/app_strings.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/completed_modal.dart';

Future<(Money, String)?> confirmOccurrenceSheet(
  BuildContext context,
  RecurringVersion version,
  CalendarMonth period,
  Clock clock,
) async {
  final input = TextEditingController(text: version.amount.decimal);
  var date = version.dueDate(period);
  String? error;
  final result = await showCompletedBottomSheet<(Money, String)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, update) => SingleChildScrollView(
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
              tr(context, '确认入账'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              tr(context, version.kind == EntryKind.income ? '实际收入' : '实际支出'),
            ),
            TextField(
              controller: input,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr(context, '实际金额（元）'),
                errorText: error,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(tr(context, '发生日期 {0}', [date])),
              onPressed: () async {
                final today = calendarDay(clock.now());
                final selected = await showDatePicker(
                  context: sheet,
                  initialDate: parseCalendarDay(date),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(today.year, today.month, today.day),
                );
                if (selected != null && sheet.mounted) {
                  update(() => date = calendarDayKey(selected));
                }
              },
            ),
            Text(tr(context, '确认后只生成一笔实际账单，按发生日期计入收支。')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                try {
                  final amount = Money.parse(input.text);
                  if (amount.fen <= 0) throw const FormatException('请输入大于零的金额');
                  Navigator.pop(sheet, (amount, date));
                } on FormatException catch (e) {
                  update(() => error = tr(sheet, e.message));
                }
              },
              child: Text(tr(context, '确认入账')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: Text(tr(context, '取消')),
            ),
          ],
        ),
      ),
    ),
  );
  input.dispose();
  return result;
}
