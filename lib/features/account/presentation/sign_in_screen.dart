import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_semantic_colors.dart';
import 'biometric_enable_prompt.dart';

/// Login screen (FR-003) — also reused, unchanged, as the app's cold-start
/// / background-resume re-entry gate (FR-020/FR-021): when the router
/// redirects here because [appLockProvider] is locked rather than because
/// the user is fully signed out, the fingerprint button (when available)
/// unlocks the already-valid session directly, with no network call.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _biometricButtonVisible = false;

  @override
  void initState() {
    super.initState();
    _refreshBiometricAvailability();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// FR-008: the fingerprint button only ever appears when (a) the device
  /// has biometric hardware with something enrolled, AND (b) biometric
  /// login is enabled for the currently signed-in account on this device.
  /// [AuthRepository.isBiometricLoginEnabled] naturally resolves `false`
  /// when there is no current session, so this is also naturally `false`
  /// on a genuine signed-out Sign In (only ever `true` on the lock-gate
  /// case, where a session already exists).
  Future<void> _refreshBiometricAvailability() async {
    final capable = await ref
        .read(biometricLoginRepositoryProvider)
        .isDeviceCapable();
    final enabled = await ref
        .read(authRepositoryProvider)
        .isBiometricLoginEnabled();
    if (!mounted) return;
    setState(() => _biometricButtonVisible = capable && enabled);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    var succeeded = false;
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(
            email: _identifierController.text.trim(),
            password: _passwordController.text,
          );
      succeeded = true;
      if (mounted) ref.read(appLockProvider.notifier).unlock();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = mapErrorToMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    // FR-009: offered after the submit spinner has already cleared, not
    // while it's still spinning — the prompt can stay open awaiting the
    // user's answer without the button looking stuck.
    if (succeeded && mounted) {
      await maybeShowBiometricEnablePrompt(context, ref);
    }
  }

  /// FR-011/FR-012/FR-014: biometric fast path on the lock gate. Never
  /// makes a network call to authenticate — it only unlocks a session
  /// [AuthRepository] already holds, after confirming (FR-011, session-
  /// death Clarification) that session is still genuinely valid.
  Future<void> _signInWithBiometric() async {
    final l10n = AppLocalizations.of(context);
    final authRepository = ref.read(authRepositoryProvider);
    try {
      final didAuthenticate = await ref
          .read(biometricLoginRepositoryProvider)
          .authenticate(localizedReason: l10n.signInWithBiometricAction);
      if (!didAuthenticate) return; // user cancelled — stay on this screen
      await authRepository.verifySessionAlive();
      if (!mounted) return;
      ref.read(appLockProvider.notifier).unlock();
      await maybeShowBiometricEnablePrompt(context, ref);
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          // FR-014: enrollment was removed after being enabled — stop
          // offering the button and clear the stale preference.
          await authRepository.setBiometricLoginEnabled(false);
          if (!mounted) return;
          setState(() => _biometricButtonVisible = false);
        default:
          // FR-012: lockout/cancel/timeout/other — fall back silently to
          // the password fields already on screen, no data lost.
          break;
      }
    } catch (_) {
      // The biometric check itself succeeded locally but the underlying
      // session is actually dead (verifySessionAlive threw) — fall back to
      // the password form rather than showing a false "signed in" state.
      // The stale device preference is cleared once the user re-enters
      // their password successfully (FR-014a's re-enrollment expectation).
      if (!mounted) return;
      await authRepository.setBiometricLoginEnabled(false);
      if (!mounted) return;
      setState(() => _biometricButtonVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      backgroundColor: semantic.bgApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LogoBlock(l10n: l10n, semantic: semantic, colors: colors),
                const SizedBox(height: 36),
                Text(
                  l10n.signInIdentifierLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: semantic.fg2,
                  ),
                ),
                const SizedBox(height: 6),
                _InputField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  semantic: semantic,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.signInPasswordLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: semantic.fg2,
                  ),
                ),
                const SizedBox(height: 6),
                _InputField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  semantic: semantic,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                      color: semantic.fg3,
                    ),
                    tooltip: _obscurePassword
                        ? l10n.signInShowPasswordSemantic
                        : l10n.signInHidePasswordSemantic,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => context.go('/forgot-password'),
                    child: Text(
                      l10n.signInForgotPasswordAction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: colors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 14),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.signInSubmit,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                if (_biometricButtonVisible) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(color: semantic.border1, height: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            l10n.signInOrDivider,
                            style: TextStyle(fontSize: 12, color: semantic.fg3),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: semantic.border1, height: 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(width: 1.5, color: semantic.border2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _signInWithBiometric,
                      icon: Icon(
                        LucideIcons.fingerprint,
                        size: 18,
                        color: semantic.fg2,
                      ),
                      label: Text(
                        l10n.signInWithBiometricAction,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: semantic.fg2,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => context.go('/sign-up'),
                    child: Text(
                      l10n.signInNavigateToSignUp,
                      style: TextStyle(fontSize: 13, color: semantic.fg3),
                    ),
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

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({
    required this.l10n,
    required this.semantic,
    required this.colors,
  });

  final AppLocalizations l10n;
  final AppSemanticColors semantic;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/icon/appicon.png',
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.signInAppName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.signInAppSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: semantic.fg3),
        ),
      ],
    );
  }
}

/// Shared input styling (FR-003/FR-004): height 50, 1.5px border, 6px
/// radius, per reference/login-signup-spec.md.
class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.semantic,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final AppSemanticColors semantic;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(fontSize: 15, color: semantic.fg2),
        decoration: InputDecoration(
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
    );
  }
}
