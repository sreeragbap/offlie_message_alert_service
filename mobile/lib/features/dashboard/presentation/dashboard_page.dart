import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import '../../alerts/presentation/alert_tile.dart';
import '../data/dashboard.dart';
import 'dashboard_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Missed Message Alert')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/alerts/new');
          cubit.load();
        },
        icon: const Icon(Icons.send),
        label: const Text('New alert'),
      ),
      body: BlocBuilder<DashboardCubit, Resource<Dashboard>>(
        builder: (context, state) => ResourceView<Dashboard>(
          resource: state,
          onRetry: cubit.load,
          builder: (data) => RefreshIndicator(
            onRefresh: cubit.load,
            child: _DashboardContent(data: data, onChanged: cubit.load),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.onChanged});

  final Dashboard data;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: ListTile(
            leading: Icon(
              data.serviceActive ? Icons.check_circle : Icons.pause_circle_outline,
              color: data.serviceActive ? Colors.green : theme.colorScheme.outline,
              size: 32,
            ),
            title: Text(data.serviceActive ? 'Ready to send alerts' : 'Not set up yet'),
            subtitle: Text(
              '${data.alertableRecipientCount} of ${data.recipientCount} recipients can get alerts · '
              '${data.openAlertCount} pending',
            ),
          ),
        ),
        for (final issue in data.setupIssues)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(child: Text(issue, style: theme.textTheme.bodySmall)),
            ]),
          ),
        if (data.recipientCount == 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.push('/recipients/new');
                onChanged();
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add your first recipient'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('Recent alerts', style: theme.textTheme.titleMedium),
        ),
        if (data.recentAlerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No alerts yet.'),
          ),
        for (final alert in data.recentAlerts)
          AlertTile(
            alert: alert,
            onTap: () async {
              await context.push('/alerts/${alert.id}');
              onChanged();
            },
          ),
      ],
    );
  }
}
