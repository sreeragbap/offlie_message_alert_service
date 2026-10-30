import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/alert_reminders.dart';
import '../../../core/sms/sms_composer.dart';
import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import '../data/alert.dart';
import '../data/alert_repository.dart';
import 'alert_tile.dart';
import 'alert_detail_cubit.dart';

class AlertDetailPage extends StatelessWidget {
  const AlertDetailPage({super.key, required this.alertId, this.startSending = false});

  final String alertId;

  /// Opens the SMS app straight away (used right after creating an immediate alert).
  final bool startSending;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AlertDetailCubit(
        GetIt.I<AlertRepository>(),
        GetIt.I<AlertReminders>(),
        const SmsComposer(),
        alertId,
      )..load(),
      child: _AlertDetailView(startSending: startSending),
    );
  }
}

class _AlertDetailView extends StatefulWidget {
  const _AlertDetailView({required this.startSending});

  final bool startSending;

  @override
  State<_AlertDetailView> createState() => _AlertDetailViewState();
}

class _AlertDetailViewState extends State<_AlertDetailView> {
  bool _autoStarted = false;

  /// The phone does not tell us whether the SMS was sent, so we ask.
  Future<void> _send() async {
    final cubit = context.read<AlertDetailCubit>();
    if (!await cubit.openSmsApp() || !mounted) return;
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Did you send the SMS?'),
        content: const Text('Your phone does not tell this app whether the message was sent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, I sent it')),
        ],
      ),
    );
    if (sent == true && await cubit.confirmSent() && mounted) _close('Marked as sent');
  }

  /// Leaves the screen after a successful action, e.g. back to Home or History.
  void _close(String message) {
    showSnack(context, message);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this alert?'),
        content: const Text('Use this if they already replied.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel alert')),
        ],
      ),
    );
    if (confirmed == true && mounted && await context.read<AlertDetailCubit>().cancel() && mounted) {
      _close('Alert cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AlertDetailCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alert')),
      body: BlocConsumer<AlertDetailCubit, AlertDetailState>(
        listener: (context, state) {
          if (state.error != null) showSnack(context, state.error!);
          final alert = state.alert;
          if (widget.startSending && !_autoStarted && alert is Loaded<Alert> && alert.data.canSendFromDevice) {
            _autoStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _send());
          }
        },
        builder: (context, state) => ResourceView<Alert>(
          resource: state.alert,
          onRetry: cubit.load,
          builder: (alert) => _Details(alert: alert, busy: state.busy, onSend: _send, onCancel: _cancel),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.alert, required this.busy, required this.onSend, required this.onCancel});

  final Alert alert;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  String get _explanation => switch (alert.state) {
        AlertState.scheduled => "We'll remind you at ${formatWhen(alert.dueAt)}. You can also send it now.",
        AlertState.due => 'Ready to send from your phone.',
        AlertState.sentFromDevice =>
          'You sent this SMS from your phone. Phones do not report whether an SMS reached the other person.',
        AlertState.smsAccepted => 'The SMS provider accepted this message. Delivery is not confirmed.',
        AlertState.expired => 'This alert was not sent in time and expired.',
        _ => alert.note ?? alert.state.label,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(alertIcon(alert.state))),
          title: Text(alert.recipientName ?? 'Removed recipient', style: theme.textTheme.titleLarge),
          subtitle: Text(alert.recipientPhone ?? ''),
          trailing: AlertStateChip(state: alert.state, label: alert.stateLabel),
        ),
        const SizedBox(height: 8),
        Text(_explanation),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Message', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(alert.messageText),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text('About a message on ${alert.platform.label} · created ${formatWhen(alert.createdAt)}',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        if (alert.canSendFromDevice)
          FilledButton.icon(
            onPressed: busy ? null : onSend,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Send SMS now'),
          ),
        if (alert.isOpen) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : onCancel,
            child: const Text('They replied, cancel alert'),
          ),
        ],
      ],
    );
  }
}
