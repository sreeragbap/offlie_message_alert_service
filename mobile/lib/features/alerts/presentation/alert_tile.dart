import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/alert.dart';

/// One alert in a list, with a status chip.
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, this.onTap});

  final Alert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final when = alert.isOpen ? alert.dueAt : (alert.completedAt ?? alert.createdAt);
    final prefix = alert.state == AlertState.scheduled ? 'Due ' : '';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Icon(alertIcon(alert.state), size: 20)),
      title: Text(alert.recipientName ?? 'Removed recipient'),
      subtitle: Text('${alert.platform.label} · $prefix${formatWhen(when)}'),
      trailing: AlertStateChip(state: alert.state, label: alert.stateLabel),
    );
  }
}

class AlertStateChip extends StatelessWidget {
  const AlertStateChip({super.key, required this.state, this.label});

  final AlertState state;

  /// Overrides [AlertState.label], e.g. with [Alert.stateLabel].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (state) {
      AlertState.due => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AlertState.scheduled => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      AlertState.smsFailed || AlertState.smsUnknown => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(label ?? state.label, style: TextStyle(color: foreground, fontSize: 12)),
    );
  }
}

IconData alertIcon(AlertState state) => switch (state) {
      AlertState.scheduled => Icons.schedule,
      AlertState.due => Icons.notifications_active_outlined,
      AlertState.sentFromDevice || AlertState.smsAccepted || AlertState.smsDelivered => Icons.check,
      AlertState.cancelled || AlertState.skipped || AlertState.expired => Icons.block,
      _ => Icons.error_outline,
    };

String formatWhen(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  return sameDay ? DateFormat.jm().format(local) : DateFormat('d MMM, h:mm a').format(local);
}
