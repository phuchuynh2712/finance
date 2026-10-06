import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/adaptive_body.dart';
import 'package:finance/features/account/application/change_password_service.dart';
import 'other_devices_notice_controller.dart';
import 'security_controller.dart';
import 'widgets/account_menu.dart';

/// "Bảo mật", opened from the Bảo mật row on Hồ sơ at `/account/security`.
/// Hosts the change-password entry, the biometric sign-in switch and, after a
/// change whose "sign out other devices" step failed, a notice with a one-tap
/// retry.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Removing a fingerprint (or adding one) happens in system settings, so the
    // switch must be re-evaluated whenever the person comes back to the app.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(securityControllerProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _openChangePassword() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await context.push<ChangePasswordOutcome>(
      '/account/security/change-password',
    );
    if (!mounted) return;

    switch (outcome) {
      case ChangePasswordOutcome.changed:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.securityPasswordChangedNotice)),
        );
      case ChangePasswordOutcome.changedOthersNotEnded:
        ref.read(otherDevicesNoticeControllerProvider.notifier).show();
      default:
        break;
    }
  }

  Future<void> _retrySigningOutOtherDevices() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(otherDevicesNoticeControllerProvider.notifier)
        .retry();
    if (result == null) return;

    final error = result.error;
    final message = result.outcome == ChangePasswordOutcome.changed
        ? l10n.securityOthersSignedOutNotice
        : error == null
        ? l10n.errorMapperGeneric
        : mapErrorToMessage(error, l10n);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _setBiometric(bool enabled) {
    ref
        .read(securityControllerProvider.notifier)
        .setEnabled(
          enabled,
          localizedReason: AppLocalizations.of(
            context,
          ).securityBiometricPromptReason,
        );
  }

  String? _biometricCaption(AppLocalizations l10n, SecuritySettings? settings) {
    return switch (settings?.availability) {
      BiometricAvailability.webUnsupported => l10n.securityBiometricReasonWeb,
      BiometricAvailability.noHardware =>
        l10n.securityBiometricReasonNoHardware,
      BiometricAvailability.notEnrolled =>
        l10n.securityBiometricReasonNotEnrolled,
      BiometricAvailability.available || null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final notice = ref.watch(otherDevicesNoticeControllerProvider);
    final security = ref.watch(securityControllerProvider);
    final settings = security.settings;

    ref.listen<SecurityNotice?>(
      securityControllerProvider.select((state) => state.notice),
      (previous, next) {
        if (next != SecurityNotice.enableFailed) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.securityBiometricEnableFailed)),
        );
        ref.read(securityControllerProvider.notifier).clearNotice();
      },
    );

    // The switch stays disabled until availability and the stored preference
    // are known (no flash of a wrong state) and while a change is running.
    final canToggle =
        (settings?.switchEnabled ?? false) && !security.isChanging;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: semantic.primarySoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                LucideIcons.shieldCheck,
                size: 17,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(l10n.securityScreenTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        children: [
          AdaptiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice != OtherDevicesNotice.hidden) ...[
                  _OtherDevicesNotice(
                    semantic: semantic,
                    isRetrying: notice == OtherDevicesNotice.retrying,
                    onRetry: _retrySigningOutOtherDevices,
                  ),
                  const SizedBox(height: 16),
                ],
                AccountMenuCard(
                  semantic: semantic,
                  children: [
                    AccountMenuRow(
                      key: const ValueKey('security-change-password-row'),
                      icon: LucideIcons.keyRound,
                      label: l10n.securityChangePasswordRow,
                      semantic: semantic,
                      showDivider: true,
                      onTap: _openChangePassword,
                    ),
                    AccountMenuRow(
                      key: const ValueKey('security-biometric-row'),
                      icon: LucideIcons.fingerprint,
                      label: l10n.securityBiometricRow,
                      semantic: semantic,
                      showDivider: false,
                      caption: _biometricCaption(l10n, settings),
                      captionKey: const ValueKey('security-biometric-caption'),
                      onTap: canToggle
                          ? () => _setBiometric(!(settings?.switchOn ?? false))
                          : null,
                      trailing: Switch(
                        key: const ValueKey('security-biometric-switch'),
                        value: settings?.switchOn ?? false,
                        onChanged: canToggle ? _setBiometric : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Password changed, but other devices could not be signed out" with a retry.
/// A live region so a screen reader announces it when it appears.
class _OtherDevicesNotice extends StatelessWidget {
  const _OtherDevicesNotice({
    required this.semantic,
    required this.isRetrying,
    required this.onRetry,
  });

  final AppSemanticColors semantic;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('security-others-notice'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: semantic.warningSoft,
          border: Border.all(color: semantic.warning),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 18,
              color: semantic.warningFg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.securityPasswordChangedOthersNotEnded,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: semantic.warningFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('security-others-retry'),
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: isRetrying ? null : onRetry,
              child: isRetrying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.securityOthersRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}
