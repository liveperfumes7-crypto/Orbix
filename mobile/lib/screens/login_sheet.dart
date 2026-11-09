import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';

/// Returns true when the user ended up with a real account.
Future<bool> requireAccount(BuildContext context) async {
  final app = AppScope.of(context);
  if (!app.status.isGuest) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tokens.surface,
    builder: (_) => const LoginSheet(),
  );
  await app.refresh();
  return ok == true;
}

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});
  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false, _busy = false;
  String? _err, _info;

  Future<void> _submit() async {
    setState(() { _busy = true; _err = null; _info = null; });
    try {
      final email = _email.text.trim();
      if (_signup) {
        if (sb.auth.currentSession == null) {
          await sb.auth.signUp(email: email, password: _pass.text, emailRedirectTo: '${Config.authScheme}://login-callback');
          setState(() => _info = 'Check your email to confirm your account, then log in.');
          return;
        }
        // Guest -> member upgrade keeps the same user id (and guest data).
        await sb.auth.updateUser(
          UserAttributes(email: email, password: _pass.text),
          emailRedirectTo: '${Config.authScheme}://login-callback',
        );
        setState(() => _info = 'Check your email to confirm your account.');
        if (mounted && sb.auth.currentUser?.isAnonymous == false) Navigator.pop(context, true);
      } else {
        await sb.auth.signInWithPassword(email: email, password: _pass.text);
        if (mounted) Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      setState(() => _err = e.message);
    } catch (_) {
      setState(() => _err = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) return setState(() => _err = 'Enter your email first.');
    await sb.auth.resetPasswordForEmail(email, redirectTo: '${Config.authScheme}://login-callback');
    setState(() => _info = 'Password reset link sent.');
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_signup ? 'Create your account' : 'Log in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Tokens.danger))),
            if (_info != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_info!, style: const TextStyle(color: Tokens.success))),
            const SizedBox(height: 14),
            GradientButton(label: _busy ? 'Please wait…' : (_signup ? 'Sign up' : 'Log in'), onPressed: _busy ? null : _submit),
            TextButton(onPressed: () => setState(() => _signup = !_signup), child: Text(_signup ? 'I already have an account' : 'New here? Sign up')),
            if (!_signup) TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('google_login'),
              onPressed: () => setState(() => _info = 'Google sign-in is coming soon. Please use email for now.'),
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Continue with Google (coming soon)'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continue as Guest')),
          ]),
        ),
      );
}
