import 'package:flutter/material.dart';

import '../../../../core/domain/calendar_month.dart';

Future<CalendarMonth?> showMonthPicker(
  BuildContext context,
  CalendarMonth selected,
) => showModalBottomSheet<CalendarMonth>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => _MonthPicker(selected: selected),
);

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.selected});
  final CalendarMonth selected;
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.selected.year;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .65,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上一年',
                onPressed: _year <= 1900 ? null : () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '$_year年',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '下一年',
                onPressed: _year >= 9999 ? null : () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = MediaQuery.textScalerOf(context).scale(16) > 22
                    ? 2
                    : 3;
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var month = 1; month <= 12; month++)
                        SizedBox(
                          width:
                              (constraints.maxWidth - (columns - 1) * 8) /
                              columns,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 56),
                              backgroundColor:
                                  _year == widget.selected.year &&
                                      month == widget.selected.month
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            onPressed: () => Navigator.pop(
                              context,
                              CalendarMonth(_year, month),
                            ),
                            child: Text('$month月'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
