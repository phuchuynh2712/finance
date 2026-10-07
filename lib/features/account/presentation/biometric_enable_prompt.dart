import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';

/// FR-009: shown once, immediately after the first successful Sign Up or
/// Sign In on a device, offering to enable biometric login. A no-op if the
/// device isn't capable, or the prompt was already shown for this
/// account/device pair (data-model.md §1) — safe to call unconditionally
/// after any successful authentication.
Future<void> maybeShowBiometricEnablePrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  final authRepository = ref.read(authRepositoryProvider);
  final shouldShow = await authRepository.shouldShowBiometricEnablePrompt();
  if (!shouldShow) return;

  final capable = await ref
      .read(biometricLoginRepositoryProvider)
      .isDeviceCapable();
  await authRepository.markBiometricPromptShown();
  if (!capable || !context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.biometricEnablePromptTitle),
      content: Text(l10n.biometricEnablePromptMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.biometricEnablePromptDeclineAction),
        ),
        // The primary action has the initial focus, so Enter accepts and
        // Escape (dismissal) is "not now" (contracts/plan-screen-ui.md D6).
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.biometricEnablePromptAcceptAction),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await authRepository.setBiometricLoginEnabled(true);
  }
}
