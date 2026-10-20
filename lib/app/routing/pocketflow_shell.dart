import 'package:flutter/material.dart';

class PocketFlowShell extends StatefulWidget {
  const PocketFlowShell({
    super.key,
    required this.home,
    required this.statistics,
    required this.settings,
    required this.ledger,
    this.onAdd,
    this.onTabChanged,
  });
  final Widget home, statistics, settings, ledger;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onTabChanged;
  @override
  State<PocketFlowShell> createState() => _PocketFlowShellState();
}

class _PocketFlowShellState extends State<PocketFlowShell> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget destination(int index, String label, IconData icon) => Expanded(
      child: Semantics(
        selected: _selected == index,
        button: true,
        child: InkWell(
          onTap: () {
            setState(() => _selected = index);
            widget.onTabChanged?.call(index);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: _selected == index
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    size: 23,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _selected == index
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: IndexedStack(
        index: _selected,
        children: [
          widget.home,
          widget.ledger,
          widget.statistics,
          widget.settings,
        ],
      ),
      bottomNavigationBar: Material(
        color: scheme.surface,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                destination(0, '总览', Icons.home_outlined),
                destination(1, '账单', Icons.receipt_long_outlined),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FilledButton(
                    onPressed: widget.onAdd,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(82, 48),
                    ),
                    child: const Text('＋记账'),
                  ),
                ),
                destination(2, '统计', Icons.bar_chart_rounded),
                destination(3, '我的', Icons.person_outline_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
