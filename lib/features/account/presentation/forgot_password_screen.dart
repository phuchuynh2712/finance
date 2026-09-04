import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_semantic_colors.dart';

/// FR-015: request a password-reset email. Always shows the same generic
/// confirmation regardless of whether the email is registered, per
/// account-enumeration protection — the screen never learns or reveals the
/// answer either way.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailController.text.trim());
    } catch (_) {
      // FR-015: the confirmation is identical regardless of outcome — a
      // network/server failure here still shows the same generic message,
      // rather than leaking whether the email exists via a different error.
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      backgroundColor: semantic.bgApp,
      appBar: AppBar(
        backgroundColor: semantic.bgApp,
        title: Text(l10n.forgotPasswordTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _submitted
                ? [
                    Text(
                      l10n.forgotPasswordConfirmationMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: semantic.fg2),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => context.go('/sign-in'),
                      child: Text(l10n.forgotPasswordBackToSignIn),
                    ),
                  ]
                : [
                    Text(
                      l10n.forgotPasswordInstructions,
                      style: TextStyle(color: semantic.fg2),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.forgotPasswordEmailLabel,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.forgotPasswordSubmitAction),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: Text(
                          l10n.forgotPasswordBackToSignIn,
                          style: TextStyle(color: colors.primary),
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
