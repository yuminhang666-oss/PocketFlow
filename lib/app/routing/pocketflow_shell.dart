import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../theme/frosted_glass.dart';

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
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    Widget destination(int index, String label, IconData icon) => Expanded(
      child: Semantics(
        selected: _selected == index,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: () {
          setState(() => _selected = index);
          widget.onTabChanged?.call(index);
        },
        child: InkWell(
          onTap: () {
            setState(() => _selected = index);
            widget.onTabChanged?.call(index);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58, minWidth: 48),
            child: AnimatedContainer(
              duration: motion,
              decoration: _selected == index
                  ? BoxDecoration(
                      color: scheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(22),
                    )
                  : null,
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
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _selected == index
                          ? FontWeight.w600
                          : FontWeight.w400,
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
    final navigation = Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            destination(0, tr(context, "总览"), Icons.home_outlined),
            destination(1, tr(context, "账单"), Icons.receipt_long_outlined),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FilledButton(
                onPressed: widget.onAdd,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(82, 48),
                ),
                child: Text(tr(context, "＋记账")),
              ),
            ),
            destination(2, tr(context, "统计"), Icons.bar_chart_rounded),
            destination(3, tr(context, "我的"), Icons.person_outline_rounded),
          ],
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: FrostedSurface(radius: 28, child: navigation),
        ),
      ),
    );
  }
}
