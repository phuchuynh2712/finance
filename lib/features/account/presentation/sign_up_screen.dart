import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_semantic_colors.dart';
import 'biometric_enable_prompt.dart';
import 'sign_up_validation.dart';

/// Sign Up screen (FR-004). Signs the account in immediately on success —
/// no email-confirmation step (FR-019).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _termsAccepted = false;
  String? _emailFieldError;
  String? _passwordFieldError;
  String? _confirmPasswordFieldError;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // FR-006: email is always required, unlike the mockup's visual
    // optional-style label (spec.md Assumptions) — it remains the only
    // supported authentication credential.
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
    var succeeded = false;
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email,
            password: password,
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
          );
      succeeded = true;
    } catch (e) {
      if (!mounted) return;
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() => _errorMessage = _mapSignUpError(e, l10n));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    // FR-019/FR-009: offered after the submit spinner has already cleared —
    // the prompt can stay open awaiting the user's answer without the
    // button looking stuck.
    if (succeeded && mounted) {
      await maybeShowBiometricEnablePrompt(context, ref);
    }
  }

  /// FR-003: duplicate email is the only special-cased Sign Up error left
  /// once Google is removed — no more "or sign in with Google" fallback
  /// mention (research.md §7).
  String _mapSignUpError(Object error, AppLocalizations l10n) {
    if (error is AuthApiException &&
        (error.code == 'email_exists' || error.code == 'user_already_exists')) {
      return l10n.signUpDuplicateEmailError;
    }
    return mapErrorToMessage(error, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      backgroundColor: semantic.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            _Header(l10n: l10n, colors: colors, semantic: semantic),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormField(
                      label: l10n.signUpNameLabel,
                      controller: _nameController,
                      semantic: semantic,
                    ),
                    const SizedBox(height: 14),
                    _FormField(
                      label: l10n.signUpPhoneLabel,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      semantic: semantic,
                    ),
                    const SizedBox(height: 14),
                    _FormField(
                      label: l10n.signUpEmailLabel,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailFieldError,
                      semantic: semantic,
                    ),
                    const SizedBox(height: 14),
                    _FormField(
                      label: l10n.signUpPasswordLabel,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      errorText: _passwordFieldError,
                      semantic: semantic,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                          size: 17,
                          color: semantic.fg3,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FormField(
                      label: l10n.signUpConfirmPasswordLabel,
                      controller: _confirmPasswordController,
                      obscureText: true,
                      errorText: _confirmPasswordFieldError,
                      semantic: semantic,
                    ),
                    const SizedBox(height: 4),
                    _TermsCheckbox(
                      value: _termsAccepted,
                      onChanged: (value) =>
                          setState(() => _termsAccepted = value),
                      l10n: l10n,
                      semantic: semantic,
                      colors: colors,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: colors.error, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: (_isSubmitting || !_termsAccepted)
                            ? null
                            : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.signUpSubmit,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => context.go('/sign-in'),
                        child: Text(
                          l10n.signUpNavigateToSignIn,
                          style: TextStyle(fontSize: 13, color: semantic.fg3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.l10n,
    required this.colors,
    required this.semantic,
  });

  final AppLocalizations l10n;
  final ColorScheme colors;
  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: semantic.border1)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.signUpBackSemantic,
            icon: Icon(LucideIcons.chevronLeft, size: 22, color: semantic.fg2),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/sign-in'),
          ),
          const SizedBox(width: 4),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: semantic.primarySoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(LucideIcons.userPlus, size: 17, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.signUpTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.semantic,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final AppSemanticColors semantic;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: semantic.fg2,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(fontSize: 14, color: semantic.fg2),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              errorText: errorText,
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(width: 1.5, color: semantic.border2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(width: 1.5, color: semantic.border2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  width: 1.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// FR-007: gates the primary submit button. The two link spans render as
/// styled text only — no real Terms/Privacy destination in this feature
/// (spec.md Assumptions).
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.l10n,
    required this.semantic,
    required this.colors,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l10n;
  final AppSemanticColors semantic;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(width: 1.5, color: colors.primary),
                  ),
                  child: value
                      ? const Icon(
                          LucideIcons.check,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13, right: 4),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: semantic.fg2,
                    ),
                    children: [
                      TextSpan(text: l10n.signUpTermsPrefix),
                      TextSpan(
                        text: l10n.signUpTermsOfServiceLink,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: l10n.signUpTermsMiddle),
                      TextSpan(
                        text: l10n.signUpPrivacyPolicyLink,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
