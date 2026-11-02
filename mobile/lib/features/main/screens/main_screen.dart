import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_alert/core/di/injection.dart';
import 'package:offline_alert/features/alerts/logic/alert_history_cubit/alert_history_cubit.dart';
import 'package:offline_alert/features/dashboard/logic/dashboard_cubit/dashboard_cubit.dart';
import 'package:offline_alert/features/recipients/logic/recipients_cubit/recipients_cubit.dart';
import 'package:offline_alert/features/whatsapp/logic/whatsapp_cubit/whatsapp_cubit.dart';

/// Bottom navigation for the main tabs. Each tab reloads when selected; the WhatsApp tab also
/// refreshes itself while visible so delivery ticks update.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<DashboardCubit>()..load()),
        BlocProvider(create: (_) => getIt<RecipientsCubit>()..load()),
        BlocProvider(create: (_) => getIt<AlertHistoryCubit>()..refresh()),
        BlocProvider(create: (_) => getIt<WhatsAppCubit>()..setVisible(shell.currentIndex == 1)),
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
