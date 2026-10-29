import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import '../data/recipient.dart';
import '../data/recipient_repository.dart';
import 'recipient_form_cubit.dart';

class RecipientFormPage extends StatelessWidget {
  const RecipientFormPage({super.key, this.existing});

  final Recipient? existing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RecipientFormCubit(GetIt.I<RecipientRepository>(), existing: existing),
      child: _RecipientForm(existing: existing),
    );
  }
}

class _RecipientForm extends StatefulWidget {
  const _RecipientForm({this.existing});

  final Recipient? existing;

  @override
  State<_RecipientForm> createState() => _RecipientFormState();
}

class _RecipientFormState extends State<_RecipientForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.displayName);
  late final _phone = TextEditingController(text: widget.existing?.phoneE164);
  late bool _optedOut = widget.existing?.optedOut ?? false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove recipient?'),
        content: const Text('Pending alerts to this person will be cancelled. Past alerts stay in your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await GetIt.I<RecipientRepository>().delete(widget.existing!.id);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not remove recipient. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit recipient' : 'Add recipient'),
        actions: [
          if (isEdit) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Remove'),
        ],
      ),
      body: BlocConsumer<RecipientFormCubit, RecipientFormState>(
        listener: (context, state) {
          if (state.status == ActionStatus.done) context.pop(state.saved);
        },
        builder: (context, state) {
          final working = state.status == ActionStatus.working;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    helperText: 'Indian numbers can be entered without +91',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 6) ? 'Enter a mobile number' : null,
                ),
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('They asked not to be alerted'),
                    subtitle: const Text('No alerts can be sent to this person while this is on.'),
                    value: _optedOut,
                    onChanged: (v) => setState(() => _optedOut = v),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Only add people who are happy to get an SMS from you.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: working
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            context
                                .read<RecipientFormCubit>()
                                .save(displayName: _name.text, phone: _phone.text, optedOut: _optedOut);
                          }
                        },
                  child: Text(working ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
