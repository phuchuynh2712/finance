import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import 'google_sign_in_feature_flag.dart';
import 'sign_up_validation.dart';

/// Registration form (FR-001, FR-004): email + password. On success, the
/// account requires email confirmation before it can sign in (FR-015,
/// FR-021) — this screen shows a "check your email" message rather than
/// assuming the user lands signed in.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _emailFieldError;
  String? _passwordFieldError;
  String? _confirmPasswordFieldError;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Dismiss the keyboard so a validation or server error (rendered below
    // the submit button) isn't hidden underneath it — otherwise the result
    // of tapping submit can look like nothing happened.
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final emailError = SignUpValidation.isEmailValid(email)
        ? null
        : l10n.signUpEmailInvalidError;
    final passwordError = SignUpValidation.isPasswordValid(password)
        ? null
        : l10n.signUpPasswordTooShortError;
    final confirmPasswordError =
        SignUpValidation.isConfirmPasswordValid(password, confirmPassword)
        ? null
        : l10n.signUpConfirmPasswordMismatchError;

    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      setState(() {
        _emailFieldError = emailError;
        _passwordFieldError = passwordError;
        _confirmPasswordFieldError = confirmPasswordError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _emailFieldError = null;
      _passwordFieldError = null;
      _confirmPasswordFieldError = null;
      _errorMessage = null;
    });
    try {
      final needsConfirmation = await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email,
            password: password,
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
          );
      if (!mounted) return;
      // FR-015/FR-021: unconfirmed accounts don't get a session, so the
      // router's auth guard won't navigate away on its own — show the
      // "check your email" message and stay on this screen.
      setState(() => _needsEmailConfirmation = needsConfirmation);
    } catch (e) {
      if (!mounted) return;
      // FR-011: preserve the entered email so the user can retry without
      // full re-entry, but clear the password fields.
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() => _errorMessage = _mapSignUpError(e, l10n));
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
      setState(() => _errorMessage = l10n.signUpResendConfirmationSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = l10n.signUpResendConfirmationError(
          e.toString(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Maps Supabase's signUp error conditions to user-facing messages
  /// (FR-011, FR-003, FR-012 — contracts/auth_repository_interface.md).
  /// `email_exists`/`user_already_exists` covers both a duplicate
  /// password-based account (FR-003) and an existing Google-only account
  /// (FR-012) — Supabase's error code doesn't distinguish the two, and
  /// telling them apart client-side would require a custom email-lookup
  /// endpoint, itself a user-enumeration risk (research.md §6), so both
  /// cases share one message directing the user to either sign-in path.
  String _mapSignUpError(Object error, AppLocalizations l10n) {
    if (error is AuthApiException &&
        (error.code == 'email_exists' ||
            error.code == 'user_already_exists')) {
      return l10n.signUpDuplicateEmailError;
    }
    return l10n.signUpError(error.toString());
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
    if (_needsEmailConfirmation) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.signUpTitle)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.signUpCheckEmailMessage(_emailController.text.trim()),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton(
                onPressed: _isSubmitting ? null : _resendConfirmationEmail,
                child: Text(l10n.signUpResendConfirmationAction),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: Text(l10n.signUpNavigateToSignIn),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signUpTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.signUpEmailLabel,
                errorText: _emailFieldError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.signUpPasswordLabel,
                errorText: _passwordFieldError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.signUpConfirmPasswordLabel,
                errorText: _confirmPasswordFieldError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.signUpNameLabel),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.signUpPhoneLabel),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  : Text(l10n.signUpSubmit),
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
              onPressed: _isSubmitting ? null : () => context.go('/sign-in'),
              child: Text(l10n.signUpNavigateToSignIn),
            ),
          ],
        ),
      ),
    );
  }
}
