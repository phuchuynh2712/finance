import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import 'google_sign_in_feature_flag.dart';

/// Minimal email/password sign-in form. Built in Foundational (not deferred
/// to US4's Account tab) because the router's auth guard needs a concrete
/// redirect target before any tab can be reached during independent testing
/// of any user story.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showResendConfirmation = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Dismiss the keyboard so a server error (rendered below the submit
    // button) isn't hidden underneath it.
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _showResendConfirmation = false;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      // FR-022: a distinct message (with a resend action) for an unconfirmed
      // account, rather than the generic wrong-password error.
      if (e.code == 'email_not_confirmed') {
        setState(() {
          _errorMessage = l10n.signInEmailNotConfirmedError;
          _showResendConfirmation = true;
        });
      } else {
        setState(() => _errorMessage = l10n.signInError(e.toString()));
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = AppLocalizations.of(
          context,
        ).signInError(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendConfirmationEmail() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendConfirmationEmail(email);
      if (!mounted) return;
      setState(() => _errorMessage = l10n.signInResendConfirmationSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = l10n.signInResendConfirmationError(
          e.toString(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// User cancelling the Google account chooser is a silent no-op (FR-009)
  /// — distinct from a network/server failure, which shows a retryable
  /// error.
  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      if (!mounted) return;
      setState(() => _errorMessage = l10n.signInWithGoogleError(e.toString()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.signInWithGoogleError(e.toString()));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.signInEmailLabel),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.signInPasswordLabel),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            if (_showResendConfirmation) ...[
              OutlinedButton(
                onPressed: _isSubmitting ? null : _resendConfirmationEmail,
                child: Text(l10n.signInResendConfirmationAction),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.signInSubmit),
            ),
            if (kGoogleSignInEnabled) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isSubmitting ? null : _signInWithGoogle,
                child: Text(l10n.signInWithGoogleAction),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isSubmitting ? null : () => context.go('/sign-up'),
              child: Text(l10n.signInNavigateToSignUp),
            ),
          ],
        ),
      ),
    );
  }
}
