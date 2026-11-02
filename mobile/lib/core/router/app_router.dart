import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/features/alerts/screens/alert_detail_screen.dart';
import 'package:offline_alert/features/alerts/screens/alert_history_screen.dart';
import 'package:offline_alert/features/alerts/screens/new_alert_screen.dart';
import 'package:offline_alert/features/auth/logic/session_cubit/session_cubit.dart';
import 'package:offline_alert/features/auth/screens/auth_screen.dart';
import 'package:offline_alert/features/dashboard/screens/dashboard_screen.dart';
import 'package:offline_alert/features/help/screens/help_screen.dart';
import 'package:offline_alert/features/main/screens/main_screen.dart';
import 'package:offline_alert/features/onboarding/screens/welcome_screen.dart';
import 'package:offline_alert/features/preferences/screens/preferences_screen.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/recipients/screens/recipient_form_screen.dart';
import 'package:offline_alert/features/recipients/screens/recipients_screen.dart';
import 'package:offline_alert/features/relay/screens/relay_screen.dart';
import 'package:offline_alert/features/settings/screens/settings_screen.dart';
import 'package:offline_alert/features/whatsapp/screens/whatsapp_compose_screen.dart';
import 'package:offline_alert/features/whatsapp/screens/whatsapp_screen.dart';

const _publicRoutes = {'/welcome', '/sign-in', '/sign-up'};

/// The app's one router. A singleton so the route stack outlives any widget.
@lazySingleton
class AppRouter {
  AppRouter(SessionCubit session) : config = _build(session);

  final GoRouter config;

  @disposeMethod
  void dispose() => config.dispose();
}

GoRouter _build(SessionCubit session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _StreamListenable(session.stream),
    redirect: (context, state) {
      final isPublic = _publicRoutes.contains(state.matchedLocation);
      if (!session.state) return isPublic ? null : '/welcome';
      return isPublic ? '/' : null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const AuthScreen(mode: AuthMode.signIn)),
      GoRoute(path: '/sign-up', builder: (_, _) => const AuthScreen(mode: AuthMode.signUp)),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainScreen(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/whatsapp', builder: (_, _) => const WhatsAppScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/recipients', builder: (_, _) => const RecipientsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (_, _) => const AlertHistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(
        path: '/alerts/new',
        builder: (_, state) => NewAlertScreen(recipientId: state.uri.queryParameters['recipientId']),
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (_, state) => AlertDetailScreen(
          alertId: state.pathParameters['id']!,
          startSending: state.uri.queryParameters['send'] == '1',
        ),
      ),
      GoRoute(
        path: '/recipients/edit',
        builder: (_, state) => RecipientFormScreen(existing: state.extra as Recipient?),
      ),
      GoRoute(
        path: '/whatsapp/new',
        builder: (_, state) => WhatsAppComposeScreen(recipientId: state.uri.queryParameters['recipientId']),
      ),
      GoRoute(path: '/relay', builder: (_, _) => const RelayScreen()),
      GoRoute(path: '/preferences', builder: (_, _) => const PreferencesScreen()),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
    ],
  );
}

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
