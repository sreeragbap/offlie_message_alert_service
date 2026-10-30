import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/sms/sms_relay_channel.dart';
import '../../alerts/presentation/alert_tile.dart';
import '../data/relay_repository.dart';
import 'relay_cubit.dart';

class RelayPage extends StatelessWidget {
  const RelayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sms = GetIt.I<SmsRelayChannel>();
    if (!sms.supported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relay phone')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Relay mode needs an Android phone with a SIM. iPhones do not let apps send SMS.'),
        ),
      );
    }
    return BlocProvider(
      create: (_) => RelayCubit(
        GetIt.I<RelayRepository>(),
        sms,
        requestPermission: sms.requestPermission,
        keepScreenOn: (on) => on ? WakelockPlus.enable() : WakelockPlus.disable(),
      ),
      child: const _RelayView(),
    );
  }
}

class _RelayView extends StatelessWidget {
  const _RelayView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RelayCubit>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Relay phone')),
      body: BlocBuilder<RelayCubit, RelayState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  state.running ? Icons.cell_tower : Icons.pause_circle_outline,
                  color: state.running ? Colors.green : theme.colorScheme.outline,
                  size: 32,
                ),
                title: Text(state.running ? 'Relay is running' : 'Relay is off'),
                subtitle: Text(
                  state.running
                      ? (state.lastCheckAt == null ? 'Checking…' : 'Last checked ${formatWhen(state.lastCheckAt!)}')
                      : 'Turn it on to send automatic SMS alerts from this phone.',
                ),
              ),
            ),
            if (state.connectionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(state.connectionError!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (state.permissionDenied)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'SMS permission is needed. Allow it in Settings → Apps → Missed Message Alert → Permissions.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.running ? cubit.stop : cubit.start,
              icon: Icon(state.running ? Icons.stop : Icons.play_arrow),
              label: Text(state.running ? 'Stop relay' : 'Start relay'),
            ),
            const SizedBox(height: 16),
            Text(
              'When a WhatsApp message you sent is not delivered in time, this phone sends the SMS alert '
              'from its own SIM, with no tap needed. Keep this screen open, the phone charging and on '
              'mobile network and internet. Normal SMS charges of your plan apply. Use a phone that is '
              'signed in to your account.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (state.log.isNotEmpty) Text('Sent by this phone', style: theme.textTheme.titleMedium),
            for (final entry in state.log)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.outcome == RelaySendOutcome.sent ? Icons.check : Icons.error_outline),
                title: Text(entry.to),
                subtitle: Text('${formatWhen(entry.at)} · ${_label(entry)}'),
              ),
          ],
        ),
      ),
    );
  }

  static String _label(RelayLogEntry entry) => switch (entry.outcome) {
    RelaySendOutcome.sent => 'Sent',
    RelaySendOutcome.retryableFailure => 'Not sent, will retry: ${entry.error ?? ''}',
    RelaySendOutcome.failed => 'Not sent: ${entry.error ?? ''}',
    RelaySendOutcome.unknown => 'Unknown: ${entry.error ?? ''}',
  };
}
