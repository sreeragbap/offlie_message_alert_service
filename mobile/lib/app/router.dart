import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/presentation/alert_detail_page.dart';
import '../features/alerts/presentation/alert_history_page.dart';
import '../features/alerts/presentation/new_alert_page.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/help/presentation/help_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/preferences/presentation/preferences_page.dart';
import '../features/recipients/data/recipient.dart';
import '../features/recipients/presentation/recipient_form_page.dart';
import '../features/recipients/presentation/recipients_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'home_shell.dart';

const _publicRoutes = {'/welcome', '/sign-in', '/sign-up'};

GoRouter createRouter(SessionCubit session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _StreamListenable(session.stream),
    redirect: (context, state) {
      final isPublic = _publicRoutes.contains(state.matchedLocation);
      if (!session.state) return isPublic ? null : '/welcome';
      return isPublic ? '/' : null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/sign-in', builder: (_, _) => const AuthPage(mode: AuthMode.signIn)),
      GoRoute(path: '/sign-up', builder: (_, _) => const AuthPage(mode: AuthMode.signUp)),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const DashboardPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/recipients', builder: (_, _) => const RecipientsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (_, _) => const AlertHistoryPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsPage())]),
        ],
      ),
      GoRoute(
        path: '/alerts/new',
        builder: (_, state) => NewAlertPage(recipientId: state.uri.queryParameters['recipientId']),
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (_, state) => AlertDetailPage(
          alertId: state.pathParameters['id']!,
          startSending: state.uri.queryParameters['send'] == '1',
        ),
      ),
      GoRoute(
        path: '/recipients/edit',
        builder: (_, state) => RecipientFormPage(existing: state.extra as Recipient?),
      ),
      GoRoute(path: '/preferences', builder: (_, _) => const PreferencesPage()),
      GoRoute(path: '/help', builder: (_, _) => const HelpPage()),
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
