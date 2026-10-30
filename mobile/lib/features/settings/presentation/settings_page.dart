import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/notifications/alert_reminders.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../data/account_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _account = GetIt.I<AccountRepository>();
  late Future<Profile> _profile = _account.load();
  bool _busy = false;

  Future<void> _editName(Profile profile) async {
    final controller = TextEditingController(text: profile.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true, maxLength: 80),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final updated = await _account.updateName(name);
      setState(() => _profile = Future.value(updated));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _signOut() async {
    await GetIt.I<AlertReminders>().cancelAll();
    await GetIt.I<AuthRepository>().signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('Your recipients, preferences and alert history will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep account')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final signInDeleted = await _account.deleteAccount();
      if (mounted && !signInDeleted) {
        showSnack(context, 'Your data was deleted. Your sign-in will be removed by support.');
      }
      await _signOut();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          FutureBuilder<Profile>(
            future: _profile,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(profile?.displayName ?? 'Add your name'),
                subtitle: Text(profile?.email ?? (snapshot.hasError ? 'Could not load profile' : '…')),
                trailing: const Icon(Icons.edit_outlined),
                onTap: profile == null ? null : () => _editName(profile),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Alert preferences'),
            subtitle: const Text('Default delay, limits and message'),
            onTap: () => context.push('/preferences'),
          ),
          ListTile(
            leading: const Icon(Icons.cell_tower),
            title: const Text('Relay phone'),
            subtitle: const Text('Send automatic SMS alerts from this phone (Android)'),
            onTap: () => context.push('/relay'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & limitations'),
            onTap: () => context.push('/help'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _busy ? null : _signOut,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _busy ? null : _deleteAccount,
          ),
        ],
      ),
    );
  }
}
