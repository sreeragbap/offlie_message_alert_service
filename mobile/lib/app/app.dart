import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/alert_reminders.dart';
import '../features/auth/presentation/session_cubit.dart';
import 'router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _session = GetIt.I<SessionCubit>();
  final _reminders = GetIt.I<AlertReminders>();
  late final GoRouter _router = createRouter(_session);

  @override
  void initState() {
    super.initState();
    _reminders.tappedAlertId.addListener(_openTappedAlert);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTappedAlert());
  }

  /// Tapping a reminder opens that alert, ready to send.
  void _openTappedAlert() {
    final id = _reminders.tappedAlertId.value;
    if (id == null || !_session.state) return;
    _reminders.tappedAlertId.value = null;
    _router.push('/alerts/$id?send=1');
  }

  @override
  void dispose() {
    _reminders.tappedAlertId.removeListener(_openTappedAlert);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _session,
      child: MaterialApp.router(
        title: 'Missed Message Alert',
        routerConfig: _router,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF00796B), useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF00796B),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
      ),
    );
  }
}

/// Shown when the app was built without Supabase settings.
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'App is not configured.\n\nRun with --dart-define-from-file=env.json '
              '(see mobile/env.example.json).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
