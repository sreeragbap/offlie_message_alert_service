import 'package:flutter/material.dart';

import '../../alerts/data/alert.dart';
import '../../alerts/presentation/alert_tile.dart';
import '../data/whatsapp_message.dart';

/// A WhatsApp message with its ticks and what happened to its SMS alert.
class WaMessageTile extends StatelessWidget {
  const WaMessageTile({super.key, required this.message});

  final WaMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alertLine = describeAlert(message);
    return ListTile(
      leading: CircleAvatar(child: Icon(message.incoming ? Icons.call_received : Icons.call_made, size: 20)),
      title: Text(
        message.incoming
            ? '${message.recipientName ?? 'Someone'} replied'
            : 'To ${message.recipientName ?? 'removed recipient'}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            [
              formatWhen(message.createdAt),
              if (!message.incoming) statusLabel(message.status),
              if (message.usedTemplate) 'template',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (message.error != null && (message.status == WaStatus.failed || message.status == WaStatus.unknown))
            Text(message.error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          if (alertLine != null) Text(alertLine, style: theme.textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
      trailing: message.incoming ? null : _Ticks(status: message.status),
    );
  }
}

class _Ticks extends StatelessWidget {
  const _Ticks({required this.status});

  final WaStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      WaStatus.pending || WaStatus.accepted => Icon(Icons.schedule, size: 18, color: scheme.outline),
      WaStatus.sent => Icon(Icons.done, size: 18, color: scheme.outline),
      WaStatus.delivered => Icon(Icons.done_all, size: 18, color: scheme.outline),
      WaStatus.read => const Icon(Icons.done_all, size: 18, color: Colors.blue),
      WaStatus.failed => Icon(Icons.error_outline, size: 18, color: scheme.error),
      WaStatus.unknown || WaStatus.received => Icon(Icons.help_outline, size: 18, color: scheme.outline),
    };
  }
}

String statusLabel(WaStatus status) => switch (status) {
  WaStatus.pending => 'Sending',
  WaStatus.accepted => 'Accepted by WhatsApp',
  WaStatus.sent => 'Sent, not delivered yet',
  WaStatus.delivered => 'Delivered',
  WaStatus.read => 'Read',
  WaStatus.failed => 'Failed',
  WaStatus.unknown => 'Unknown',
  WaStatus.received => 'Received',
};

/// One line about the SMS alert, or null when there is nothing to say.
String? describeAlert(WaMessage message) {
  final alert = message.alert;
  if (alert == null) {
    return switch (message.alertSkipped) {
      null => null,
      'RECIPIENT_OPTED_OUT' => 'No SMS alert: they asked not to get alerts',
      'RECIPIENT_ALERTS_DISABLED' => 'No SMS alert: alerts are off for them',
      'RECIPIENT_RATE_LIMITED' || 'DAILY_RATE_LIMITED' => 'No SMS alert: daily alert limit reached',
      _ => 'No SMS alert',
    };
  }
  return switch (alert.state) {
    AlertState.scheduled => 'SMS alert at ${formatWhen(alert.dueAt!)} if not delivered',
    AlertState.due || AlertState.sending => 'Not delivered in time · SMS waiting for your relay phone',
    AlertState.smsAccepted => 'Not delivered in time · SMS sent by your relay phone',
    AlertState.smsDelivered => 'Not delivered in time · SMS delivered',
    AlertState.cancelled => 'SMS alert not needed${alert.note == null ? '' : ': ${alert.note}'}',
    AlertState.expired => 'SMS not sent: your relay phone was offline',
    _ => 'SMS alert: ${alert.state.label}${alert.note == null ? '' : ' (${alert.note})'}',
  };
}
