import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../data/platform_info.dart';

/// Explains, per platform, what is and isn't possible, as reported by the backend.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late Future<List<PlatformInfo>> _platforms = GetIt.I<PlatformRepository>().list();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & limitations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('How it works', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '1. You send someone a message on WhatsApp or another app.\n'
            "2. If they haven't seen it, create an alert here, now or with a delay.\n"
            '3. When it is time, your SMS app opens with a short message ready. You tap Send.\n'
            '4. The SMS comes from your own number, so they know who it is.',
          ),
          const SizedBox(height: 24),
          Text('Why the app cannot check delivery for you', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Messaging apps keep personal chats private and end-to-end encrypted. They do not let other apps '
            'see whether your message was delivered, and this app will never read your chats or notifications.',
          ),
          const SizedBox(height: 24),
          Text('Platforms', style: theme.textTheme.titleMedium),
          FutureBuilder<List<PlatformInfo>>(
            future: _platforms,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error is ApiException ? snapshot.error as ApiException : ApiException.network;
                return ErrorView(
                  error: error,
                  onRetry: () => setState(() => _platforms = GetIt.I<PlatformRepository>().list()),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              return Column(children: [
                for (final p in snapshot.data!)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(p.name),
                    subtitle: Text('Manual alerts: yes · Automatic detection: ${p.automaticLabel}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(alignment: Alignment.centerLeft, child: Text(p.explanation)),
                      ),
                    ],
                  ),
              ]);
            },
          ),
          const SizedBox(height: 24),
          Text('SMS charges', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Alerts are normal SMS from your phone. Your mobile plan\'s SMS charges apply.'),
        ],
      ),
    );
  }
}
