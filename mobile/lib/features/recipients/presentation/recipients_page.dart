import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import '../data/recipient.dart';
import 'recipients_cubit.dart';

class RecipientsPage extends StatelessWidget {
  const RecipientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecipientsCubit>();
    Future<void> openForm([Recipient? recipient]) async {
      await context.push('/recipients/edit', extra: recipient);
      cubit.load();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recipients')),
      floatingActionButton: FloatingActionButton(
        onPressed: openForm,
        tooltip: 'Add recipient',
        child: const Icon(Icons.person_add_alt),
      ),
      body: BlocBuilder<RecipientsCubit, Resource<List<Recipient>>>(
        builder: (context, state) => ResourceView<List<Recipient>>(
          resource: state,
          onRetry: cubit.load,
          isEmpty: (list) => list.isEmpty,
          empty: EmptyView(
            icon: Icons.people_outline,
            title: 'No recipients yet',
            message: 'Add the people you may want to alert by SMS.',
            action: FilledButton(onPressed: openForm, child: const Text('Add recipient')),
          ),
          builder: (list) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _RecipientTile(
                recipient: list[i],
                onEdit: () => openForm(list[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({required this.recipient, required this.onEdit});

  final Recipient recipient;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecipientsCubit>();
    return ListTile(
      onTap: onEdit,
      leading: CircleAvatar(child: Text(recipient.displayName.characters.first.toUpperCase())),
      title: Text(recipient.displayName),
      subtitle: Text(recipient.optedOut ? '${recipient.phoneE164} · Asked not to be alerted' : recipient.phoneE164),
      trailing: Switch(
        value: recipient.alertsEnabled && !recipient.optedOut,
        onChanged: recipient.optedOut
            ? null
            : (enabled) async {
                final error = await cubit.setAlertsEnabled(recipient, enabled);
                if (error != null && context.mounted) showSnack(context, error);
              },
      ),
    );
  }
}
