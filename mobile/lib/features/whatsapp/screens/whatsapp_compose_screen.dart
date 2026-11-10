import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/di/injection.dart';
import 'package:offline_alert/core/widgets/state_views.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/whatsapp/logic/whatsapp_compose_cubit/whatsapp_compose_cubit.dart';
import 'package:offline_alert/features/whatsapp/widgets/whatsapp_message_tile.dart';

class WhatsAppComposeScreen extends StatelessWidget {
  const WhatsAppComposeScreen({super.key, this.recipientId});

  final String? recipientId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<WhatsAppComposeCubit>(param1: recipientId)..load(),
      child: const _ComposeView(),
    );
  }
}

const _alertChoices = [5, 10, 15, 30, 60];

class _ComposeView extends StatelessWidget {
  const _ComposeView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WhatsAppComposeCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('New WhatsApp message')),
      body: BlocConsumer<WhatsAppComposeCubit, WhatsAppComposeState>(
        listenWhen: (a, b) => a.status != b.status,
        listener: (context, state) {
          final sent = state.sent;
          if (state.status != ActionStatus.done || sent == null) return;
          showSnack(context, describeAlert(sent) ?? 'Sent on WhatsApp');
          context.pop();
        },
        builder: (context, state) => ResourceView<List<Recipient>>(
          resource: state.recipients,
          onRetry: cubit.load,
          isEmpty: (list) => list.isEmpty,
          empty: EmptyView(
            icon: Icons.people_outline,
            title: 'No recipients yet',
            message: 'Add the person you want to message first.',
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

  final WhatsAppComposeState state;
  final List<Recipient> recipients;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WhatsAppComposeCubit>();
    final theme = Theme.of(context);
    final choices = {..._alertChoices, state.alertAfterMinutes}.toList()..sort();
    final selected = recipients.where((r) => r.id == state.recipientId).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: state.recipientId,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'To'),
          items: [
            for (final r in recipients) DropdownMenuItem(value: r.id, child: Text('${r.displayName}  ${r.phoneE164}')),
          ],
          onChanged: (id) => id == null ? null : cubit.selectRecipient(id),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: state.text,
          minLines: 3,
          maxLines: 8,
          maxLength: 1000,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'WhatsApp message',
            helperText: 'Edit it for this message. {name} = their name, {sender} = your name.',
            helperMaxLines: 2,
          ),
          onChanged: cubit.setText,
        ),
        if (selected != null && state.text.trim().isNotEmpty)
          _Preview(label: 'They get', text: state.messagePreview(selected)),
        Text(
          'If they have not written to your business number in the last 24 hours, WhatsApp only allows an '
          'approved template, so they get the template text first. Once they reply, your own text is sent.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('SMS alert if not delivered'),
          subtitle: Text(
            selected != null && !selected.canReceiveAlerts
                ? 'Alerts are off for ${selected.displayName}'
                : 'Your relay phone texts them automatically',
          ),
          value: state.smsAlert,
          onChanged: cubit.setSmsAlert,
        ),
        if (state.smsAlert) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in choices)
                ChoiceChip(
                  label: Text('After $m min'),
                  selected: state.alertAfterMinutes == m,
                  onSelected: (_) => cubit.setAlertAfter(m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: state.smsText,
            minLines: 2,
            maxLines: 5,
            maxLength: WhatsAppComposeState.maxSmsLength,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'SMS if not delivered',
              helperText: 'Edit it for this message. {name} = their name, {platform} = WhatsApp. '
                  'Never include private details.',
              helperMaxLines: 2,
            ),
            onChanged: cubit.setSmsText,
          ),
          if (selected != null && state.smsText.trim().isNotEmpty)
            _Preview(label: 'SMS', text: state.smsPreview(selected)),
          Text(
            'Your default SMS is in Settings → Alert preferences.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: state.canSend ? cubit.send : null,
          icon: const Icon(Icons.send),
          label: Text(state.status == ActionStatus.working ? 'Sending…' : 'Send on WhatsApp'),
        ),
      ],
    );
  }
}

/// Shows a message with the names filled in, as the recipient will see it.
class _Preview extends StatelessWidget {
  const _Preview({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: text),
          ],
        ),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
