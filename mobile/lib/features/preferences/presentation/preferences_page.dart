import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import '../../alerts/presentation/new_alert_page.dart' show delayLabel;
import '../data/alert_preferences.dart';
import 'preferences_cubit.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PreferencesCubit(GetIt.I<AlertPreferencesRepository>())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Alert preferences')),
        body: BlocConsumer<PreferencesCubit, PreferencesState>(
          listener: (context, state) {
            if (state.status == ActionStatus.done) showSnack(context, 'Saved');
            if (state.error != null) showSnack(context, state.error!);
          },
          builder: (context, state) => ResourceView<AlertPreferences>(
            resource: state.preferences,
            onRetry: context.read<PreferencesCubit>().load,
            builder: (prefs) => _PreferencesForm(
              initial: prefs,
              saving: state.status == ActionStatus.working,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesForm extends StatefulWidget {
  const _PreferencesForm({required this.initial, required this.saving});

  final AlertPreferences initial;
  final bool saving;

  @override
  State<_PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends State<_PreferencesForm> {
  late AlertPreferences _prefs = widget.initial;
  late final _template = TextEditingController(text: widget.initial.messageTemplate);

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const delays = [0, 15, 30, 60, 120, 240];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Default delay', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in {...delays, _prefs.defaultDelayMinutes}.toList()..sort())
            ChoiceChip(
              label: Text(delayLabel(d)),
              selected: _prefs.defaultDelayMinutes == d,
              onSelected: (_) => setState(() => _prefs = _prefs.copyWith(defaultDelayMinutes: d)),
            ),
        ]),
        const SizedBox(height: 24),
        Text('Limits', style: theme.textTheme.titleMedium),
        _Stepper(
          label: 'Per person, per day',
          value: _prefs.maxAlertsPerRecipientPerDay,
          min: 1,
          max: 10,
          onChanged: (v) => setState(() => _prefs = _prefs.copyWith(maxAlertsPerRecipientPerDay: v)),
        ),
        _Stepper(
          label: 'In total, per day',
          value: _prefs.maxAlertsPerDay,
          min: 1,
          max: 50,
          onChanged: (v) => setState(() => _prefs = _prefs.copyWith(maxAlertsPerDay: v)),
        ),
        const SizedBox(height: 24),
        Text('Message', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _template,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            helperText: '{name} = their name, {platform} = e.g. WhatsApp. Never include private details.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.saving
              ? null
              : () => context.read<PreferencesCubit>().save(_prefs.copyWith(messageTemplate: _template.text.trim())),
          child: Text(widget.saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
        Text('$value'),
        IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add)),
      ]),
    );
  }
}
