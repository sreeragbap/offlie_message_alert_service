import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/alert_reminders.dart';
import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import '../../preferences/data/alert_preferences.dart';
import '../../recipients/data/recipient.dart';
import '../../recipients/data/recipient_repository.dart';
import '../data/alert.dart';
import '../data/alert_repository.dart';
import 'alert_tile.dart';
import 'new_alert_cubit.dart';

class NewAlertPage extends StatelessWidget {
  const NewAlertPage({super.key, this.recipientId});

  final String? recipientId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewAlertCubit(
        GetIt.I<RecipientRepository>(),
        GetIt.I<AlertPreferencesRepository>(),
        GetIt.I<AlertRepository>(),
        GetIt.I<AlertReminders>(),
        recipientId: recipientId,
      )..load(),
      child: const _NewAlertView(),
    );
  }
}

const _delayChoices = [0, 15, 30, 60, 120];

String delayLabel(int minutes) => switch (minutes) {
      0 => 'Now',
      < 60 => 'In $minutes min',
      60 => 'In 1 hour',
      _ when minutes % 60 == 0 => 'In ${minutes ~/ 60} hours',
      _ => 'In $minutes min',
    };

class _NewAlertView extends StatelessWidget {
  const _NewAlertView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewAlertCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('New alert')),
      body: BlocConsumer<NewAlertCubit, NewAlertState>(
        listenWhen: (a, b) => a.status != b.status,
        listener: (context, state) {
          final created = state.created;
          if (state.status != ActionStatus.done || created == null) return;
          if (created.state == AlertState.due) {
            context.pushReplacement('/alerts/${created.id}?send=1');
          } else {
            showSnack(context, "Scheduled. We'll remind you at ${formatWhen(created.dueAt)}.");
            context.pop();
          }
        },
        builder: (context, state) => ResourceView<List<Recipient>>(
          resource: state.recipients,
          onRetry: cubit.load,
          isEmpty: (list) => list.isEmpty,
          empty: EmptyView(
            icon: Icons.people_outline,
            title: 'No one to alert yet',
            message: 'Add a recipient with alerts turned on first.',
            action: FilledButton(
              onPressed: () async {
                await context.push('/recipients/edit');
                cubit.load();
              },
              child: const Text('Add recipient'),
            ),
          ),
          builder: (recipients) => _Form(state: state, recipients: recipients),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state, required this.recipients});

  final NewAlertState state;
  final List<Recipient> recipients;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewAlertCubit>();
    final theme = Theme.of(context);
    final delays = {..._delayChoices, state.delayMinutes}.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Who should get the SMS?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: state.recipientId,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Recipient'),
          items: [
            for (final r in recipients) DropdownMenuItem(value: r.id, child: Text('${r.displayName}  ${r.phoneE164}')),
          ],
          onChanged: (id) => id == null ? null : cubit.selectRecipient(id),
        ),
        const SizedBox(height: 24),
        Text('Where is your message waiting?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in MessagingPlatform.values)
            ChoiceChip(
              label: Text(p.label),
              selected: state.platform == p,
              onSelected: (_) => cubit.selectPlatform(p),
            ),
        ]),
        const SizedBox(height: 24),
        Text('When?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in delays)
            ChoiceChip(
              label: Text(delayLabel(d)),
              selected: state.delayMinutes == d,
              onSelected: (_) => cubit.selectDelay(d),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
          state.delayMinutes == 0
              ? 'Your SMS app will open with the message ready. You tap Send.'
              : "We'll remind you when it's time. Cancel the alert if they reply first.",
          style: theme.textTheme.bodySmall,
        ),
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: state.canSubmit ? cubit.submit : null,
          icon: const Icon(Icons.send),
          label: Text(state.status == ActionStatus.working
              ? 'Creating…'
              : state.delayMinutes == 0
                  ? 'Continue to SMS'
                  : 'Schedule alert'),
        ),
      ],
    );
  }
}
