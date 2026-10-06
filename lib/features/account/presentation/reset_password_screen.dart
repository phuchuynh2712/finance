import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/adaptive_body.dart';
import 'package:finance/features/account/domain/password_policy.dart';

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
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isSubmitting = false;
  String? _passwordFieldError;
  String? _confirmPasswordFieldError;
  String? _errorMessage;
  bool _succeeded = false;

  bool get _canSubmit => !_isSubmitting && !_succeeded;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // FR-015: the same minimum as sign-up and change password, checked before
    // any request so a short password never reaches the service.
    final passwordError = PasswordPolicy.meetsMinimum(password)
        ? null
        : l10n.passwordTooShortError;
    final confirmPasswordError =
        PasswordPolicy.matches(password, confirmPassword)
        ? null
        : l10n.resetPasswordMismatchError;
    if (passwordError != null || confirmPasswordError != null) {
      setState(() {
        _passwordFieldError = passwordError;
        _confirmPasswordFieldError = confirmPasswordError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _passwordFieldError = null;
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
          child: AdaptiveBody(
            activatesAt: WindowSizeClass.medium,
            maxWidth: AppLayoutTokens.authContentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(
                    context,
                  ).requestFocus(_confirmPasswordFocusNode),
                  decoration: InputDecoration(
                    labelText: l10n.resetPasswordNewPasswordLabel,
                    helperText: l10n.passwordRequirementHint,
                    errorText: _passwordFieldError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (_canSubmit) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: l10n.resetPasswordConfirmPasswordLabel,
                    errorText: _confirmPasswordFieldError,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                    onPressed: _canSubmit ? _submit : null,
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
      ),
    );
  }
}
