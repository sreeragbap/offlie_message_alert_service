import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/alert_reminders.dart';
import '../features/alerts/data/alert_repository.dart';
import '../features/alerts/presentation/alert_history_cubit.dart';
import '../features/dashboard/data/dashboard.dart';
import '../features/dashboard/presentation/dashboard_cubit.dart';
import '../features/recipients/data/recipient_repository.dart';
import '../features/recipients/presentation/recipients_cubit.dart';
import '../features/whatsapp/data/whatsapp_message.dart';
import '../features/whatsapp/presentation/whatsapp_cubit.dart';

/// Bottom navigation for the main tabs. Each tab reloads when selected; the WhatsApp tab also
/// refreshes itself while visible so delivery ticks update.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.I;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              DashboardCubit(getIt<DashboardRepository>(), getIt<AlertRepository>(), getIt<AlertReminders>())..load(),
        ),
        BlocProvider(create: (_) => RecipientsCubit(getIt<RecipientRepository>())..load()),
        BlocProvider(create: (_) => AlertHistoryCubit(getIt<AlertRepository>())..refresh()),
        BlocProvider(create: (_) => WhatsAppCubit(getIt<WhatsAppRepository>())..setVisible(shell.currentIndex == 1)),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) {
              context.read<WhatsAppCubit>().setVisible(index == 1);
              switch (index) {
                case 0:
                  context.read<DashboardCubit>().load();
                case 2:
                  context.read<RecipientsCubit>().load();
                case 3:
                  context.read<AlertHistoryCubit>().refresh();
              }
              shell.goBranch(index, initialLocation: index == shell.currentIndex);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat), label: 'WhatsApp'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Recipients'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
