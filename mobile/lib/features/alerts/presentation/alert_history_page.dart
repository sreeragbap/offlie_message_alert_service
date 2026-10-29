import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import 'alert_history_cubit.dart';
import 'alert_tile.dart';

class AlertHistoryPage extends StatelessWidget {
  const AlertHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AlertHistoryCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alert history')),
      body: BlocBuilder<AlertHistoryCubit, AlertHistoryState>(
        builder: (context, state) {
          if (!state.loadedOnce && state.error != null) {
            return ErrorView(error: state.error!, onRetry: cubit.refresh);
          }
          if (!state.loadedOnce) return const Center(child: CircularProgressIndicator());
          if (state.items.isEmpty) {
            return const EmptyView(
              icon: Icons.history,
              title: 'No alerts yet',
              message: 'Alerts you create will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 300) cubit.loadMore();
                return false;
              },
              child: ListView.builder(
                itemCount: state.items.length + (state.hasMore || state.error != null ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == state.items.length) {
                    return state.error != null
                        ? TextButton(onPressed: cubit.loadMore, child: const Text('Load more'))
                        : const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                  }
                  final alert = state.items[i];
                  return AlertTile(
                    alert: alert,
                    onTap: () async {
                      await context.push('/alerts/${alert.id}');
                      cubit.refresh();
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
