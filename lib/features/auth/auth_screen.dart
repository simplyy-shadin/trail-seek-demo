import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthMode { login, signup }

/// Frame 2. Log In / Sign Up with email + password, Google, Apple.
/// Shown from the splash or when a gated action needs an account; it returns
/// to [redirect] afterwards.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.redirect, this.initialMode = AuthMode.signup});
  final String? redirect;
  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode = widget.initialMode;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(localStoreProvider).displayName;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      _afterAuth();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _afterAuth() {
    final user = ref.read(authProvider);
    final redirect = widget.redirect;
    // Came here from a gated action: return to it immediately. Avatar setup
    // is offered on Home instead of blocking the flow.
    if (redirect != null && redirect != '/home' && redirect != '/profile') {
      context.go(redirect);
      return;
    }
    if (user != null && user.avatarId == null) {
      context.go('/avatar');
      return;
    }
    context.go(redirect ?? '/home');
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = ref.read(authProvider.notifier);
    if (_mode == AuthMode.signup) {
      _run(() => auth.signUp(fullName: _name.text, email: _email.text, password: _password.text));
    } else {
      _run(() => auth.signIn(email: _email.text, password: _password.text));
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first, then tap Forgot password.');
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendPasswordReset(email);
      if (!mounted) return;
      final repo = ref.read(authRepositoryProvider);
      if (repo is! SupabaseAuthRepository) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset instructions sent to $email')));
        return;
      }
      final code = TextEditingController();
      final pass = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('We emailed a 6-digit code to $email.', style: TsText.caption),
              const SizedBox(height: 10),
              TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(hintText: 'Code')),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(hintText: 'New password (6+ characters)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set password')),
          ],
        ),
      );
      if (ok != true) return;
      await _run(() async {
        await repo.resetPassword(email: email, code: code.text, newPassword: pass.text);
        ref.invalidate(authProvider);
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = _mode == AuthMode.signup;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(leading: context.canPop() ? const BackButton() : null, automaticallyImplyLeading: false),
      body: SafeArea(
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              SegmentTabs(
                labels: const ['Log In', 'Sign Up'],
                selected: isSignup ? 1 : 0,
                onChanged: (i) => setState(() {
                  _mode = i == 1 ? AuthMode.signup : AuthMode.login;
                  _error = null;
                }),
              ),
              const SizedBox(height: 22),
              if (isSignup) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Email Address', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
              ),
              if (!isSignup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TsColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TsColors.danger.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: TsColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              NeonButton(label: isSignup ? 'Create Account' : 'Log In', loading: _busy, onPressed: _submit),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TsText.caption)),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              GhostButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                onPressed: _busy ? null : () => _run(() => ref.read(authProvider.notifier).signInWithGoogle(displayNameHint: _name.text)),
              ),
              if (isIOS) ...[
                const SizedBox(height: 10),
                GhostButton(
                  label: 'Continue with Apple',
                  icon: Icons.apple,
                  onPressed: _busy ? null : () => _run(() => ref.read(authProvider.notifier).signInWithApple(displayNameHint: _name.text)),
                ),
              ],
              const SizedBox(height: 22),
              Text.rich(
                TextSpan(
                  style: TsText.caption.copyWith(height: 1.5),
                  children: const [
                    TextSpan(text: 'By signing up, you agree to our '),
                    TextSpan(text: 'Terms & Conditions', style: TextStyle(color: TsColors.neon, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy', style: TextStyle(color: TsColors.neon, fontWeight: FontWeight.w700)),
                    TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Prototype build: accounts are stored on this phone only.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: TsColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
