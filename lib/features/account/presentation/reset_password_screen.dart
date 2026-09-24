import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'sign_up_validation.dart';

/// "Set New Password" (FR-016) — reachable only via the router's
/// `isPasswordRecovery` redirect (contracts §4), after the user opens the
/// password-reset deep link. On success, [AuthRepository.confirmPasswordReset]
/// already signs the account out globally (FR-016a); this screen shows a
/// brief success message, then navigates to Login explicitly rather than
/// waiting on the router's reactive redirect — observed on-device to
/// sometimes never fire for this screen's auth-state transition, stranding
/// the user here indefinitely.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _confirmPasswordFieldError;
  String? _errorMessage;
  bool _succeeded = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!SignUpValidation.isConfirmPasswordValid(password, confirmPassword)) {
      setState(
        () => _confirmPasswordFieldError = l10n.resetPasswordMismatchError,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _confirmPasswordFieldError = null;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).confirmPasswordReset(password);
      if (!mounted) return;
      setState(() => _succeeded = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go('/sign-in');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = mapErrorToMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      backgroundColor: semantic.bgApp,
      appBar: AppBar(
        backgroundColor: semantic.bgApp,
        title: Text(l10n.resetPasswordTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.resetPasswordNewPasswordLabel,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.resetPasswordConfirmPasswordLabel,
                  errorText: _confirmPasswordFieldError,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_succeeded) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.resetPasswordSuccessMessage,
                  style: TextStyle(color: semantic.success),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: (_isSubmitting || _succeeded) ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.resetPasswordSubmitAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
