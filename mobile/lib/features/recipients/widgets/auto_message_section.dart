import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:offline_alert/features/recipients/domain/models/auto_message.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _smsDelays = [1, 2, 5, 10, 15, 30, 60];

/// Settings for the WhatsApp message the backend sends to this recipient by itself. Edits a draft
/// [value]; the text field is owned by the caller through [textController].
class AutoMessageSection extends StatelessWidget {
  const AutoMessageSection({
    super.key,
    required this.value,
    required this.saved,
    required this.textController,
    required this.onChanged,
    this.loading = false,
    this.loadError,
  });

  final AutoMessage value;

  /// What the backend has now, for the status line.
  final AutoMessage saved;
  final TextEditingController textController;
  final ValueChanged<AutoMessage> onChanged;
  final bool loading;
  final String? loadError;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value.sendTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) onChanged(value.copyWith(sendTime: () => picked));
  }

  void _toggleDay(String day) {
    final days = value.days.contains(day) ? (value.days.toList()..remove(day)) : [...value.days, day];
    if (days.isEmpty) return; // At least one day.
    onChanged(value.copyWith(days: weekdays.where(days.contains).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delays = {..._smsDelays, value.smsAfterMinutes}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Automatic WhatsApp message', style: theme.textTheme.titleMedium),
        if (loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (loadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(loadError!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Send automatically'),
          subtitle: const Text('Sent from your WhatsApp Business number. If WhatsApp does not deliver it in '
              'time, your relay phone sends an SMS.'),
          value: value.enabled,
          onChanged: loading ? null : (v) => onChanged(value.copyWith(enabled: v)),
        ),
        if (value.enabled) ...[
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Once'), icon: Icon(Icons.send_outlined)),
              ButtonSegment(value: true, label: Text('On a schedule'), icon: Icon(Icons.schedule)),
            ],
            selected: {value.repeating},
            onSelectionChanged: (s) => onChanged(value.copyWith(
                sendTime: () => s.first ? (value.sendTime ?? const TimeOfDay(hour: 9, minute: 0)) : null)),
          ),
          const SizedBox(height: 8),
          if (!value.repeating)
            Text('Goes 1 minute after you save.', style: theme.textTheme.bodySmall)
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Time (India)'),
              trailing: Text(value.sendTime!.format(context), style: theme.textTheme.titleMedium),
              onTap: () => _pickTime(context),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < weekdays.length; i++)
                  FilterChip(
                    label: Text(_dayLetters[i]),
                    tooltip: weekdays[i][0] + weekdays[i].substring(1).toLowerCase(),
                    selected: value.days.contains(weekdays[i]),
                    onSelected: (_) => _toggleDay(weekdays[i]),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: textController,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: 'Message (optional)',
              hintText: value.defaultText,
              helperText: 'Leave empty for the default. {name} is their name, {sender} is yours.',
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: value.smsAfterMinutes,
            decoration: const InputDecoration(
              labelText: 'Send SMS if not delivered within',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in delays) DropdownMenuItem(value: m, child: Text(m == 1 ? '1 minute' : '$m minutes')),
            ],
            onChanged: (m) => onChanged(value.copyWith(smsAfterMinutes: m)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Keep the relay phone running for the SMS. Each person gets at most 3 SMS alerts a day.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        ..._status(theme),
      ],
    );
  }

  List<Widget> _status(ThemeData theme) {
    String when(DateTime t) => DateFormat('EEE d MMM, h:mm a').format(t);
    return [
      if (saved.enabled && saved.nextRunAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Next: ${when(saved.nextRunAt!)}', style: theme.textTheme.bodyMedium),
        ),
      if (saved.lastRunAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Last sent: ${when(saved.lastRunAt!)}', style: theme.textTheme.bodySmall),
        ),
      if (saved.lastError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(saved.lastError!, style: TextStyle(color: theme.colorScheme.error)),
        ),
    ];
  }
}
