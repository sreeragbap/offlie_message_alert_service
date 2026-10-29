import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/state/resource.dart';
import '../data/auth_repository.dart';
import 'auth_form_cubit.dart';

enum AuthMode { signIn, signUp }

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.mode});

  final AuthMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthFormCubit(GetIt.I<AuthRepository>()),
      child: _AuthForm(mode: mode),
    );
  }
}

class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.mode});

  final AuthMode mode;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<AuthFormCubit>();
    _isSignUp ? cubit.signUp(_email.text, _password.text) : cubit.signIn(_email.text, _password.text);
  }

  void _resetPassword() {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    context.read<AuthFormCubit>().resetPassword(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: BlocBuilder<AuthFormCubit, AuthFormState>(
          builder: (context, state) {
            final working = state.status == ActionStatus.working;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    _isSignUp
                        ? 'Create an account to alert people by SMS when they miss your messages.'
                        : 'Welcome back.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
                  if (state.info != null)
                    Text(state.info!, style: TextStyle(color: theme.colorScheme.primary)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: working ? null : _submit,
                    child: working
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: working ? null : _resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
