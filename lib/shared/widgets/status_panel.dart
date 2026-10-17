import 'package:flutter/material.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.receipt_long_rounded,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}
