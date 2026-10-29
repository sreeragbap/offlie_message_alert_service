import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// First screen for signed-out users: what the app does and, honestly, what it can't do.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(Icons.sms_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Missed Message Alert', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              "Sent someone a message that they haven't seen? Send them a short SMS "
              'to let them know, even if they are offline on WhatsApp or other apps.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const _Point(
              icon: Icons.timer_outlined,
              title: 'Alert now or later',
              text: 'Choose a delay. We remind you when it is time, and you can cancel if they reply.',
            ),
            const _Point(
              icon: Icons.phone_android,
              title: 'Sent from your own phone',
              text: 'The SMS goes from your number through your messaging app, so they know it is you. '
                  'Normal SMS charges from your mobile plan may apply.',
            ),
            const _Point(
              icon: Icons.info_outline,
              title: 'What this app cannot do',
              text: 'No app can read your personal WhatsApp, Telegram or other chats. '
                  'This app does not know whether your message was delivered. You decide when to alert.',
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.push('/sign-up'), child: const Text('Create account')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.push('/sign-in'), child: const Text('I already have an account')),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(text),
    );
  }
}
