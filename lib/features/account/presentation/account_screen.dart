import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'account_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final controller = ref.read(accountControllerProvider.notifier);
    final isSigningOut = ref.watch(accountControllerProvider);

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
                LucideIcons.user,
                size: 17,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(l10n.accountTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        children: [
          _AccountIdentityHeader(semantic: semantic),
          const SizedBox(height: 22),
          _AppearanceCard(semantic: semantic),
          const SizedBox(height: 16),
          _LanguageRow(semantic: semantic),
          const SizedBox(height: 16),
          _MenuCard(semantic: semantic),
          const SizedBox(height: 16),
          _SignOutRow(
            semantic: semantic,
            isLoading: isSigningOut,
            onTap: controller.signOut,
          ),
        ],
      ),
    );
  }
}

/// FR-009: signed-in user's identity. Falls back to deriving a name/initial
/// from the email's local part (the substring before `@`) when no display
/// name is set (spec.md Edge Cases).
class _AccountIdentityHeader extends ConsumerWidget {
  const _AccountIdentityHeader({required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(accountAuthActionsProvider);
    final email = auth.currentEmail;
    final displayName =
        auth.currentDisplayName ?? email?.split('@').first ?? '';
    final avatarUrl = auth.currentAvatarUrl;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '';

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: semantic.primarySoft,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (email != null)
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.fg3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _MenuRow(
            icon: LucideIcons.bell,
            label: l10n.accountNotificationsRowLabel,
            semantic: semantic,
            showDivider: true,
            onTap: () => _openPlaceholder(
              context,
              icon: LucideIcons.bell,
              title: l10n.accountNotificationsRowLabel,
              message: l10n.notAvailablePlaceholderMessage,
            ),
          ),
          _MenuRow(
            icon: LucideIcons.shieldCheck,
            label: l10n.accountSecurityRowLabel,
            semantic: semantic,
            showDivider: true,
            onTap: () => _openPlaceholder(
              context,
              icon: LucideIcons.shieldCheck,
              title: l10n.accountSecurityRowLabel,
              message: l10n.notAvailablePlaceholderMessage,
            ),
          ),
          _MenuRow(
            icon: LucideIcons.helpCircle,
            label: l10n.accountHelpRowLabel,
            semantic: semantic,
            showDivider: false,
            onTap: () => _openPlaceholder(
              context,
              icon: LucideIcons.helpCircle,
              title: l10n.accountHelpRowLabel,
              message: l10n.notAvailablePlaceholderMessage,
            ),
          ),
        ],
      ),
    );
  }
}

void _openPlaceholder(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => NotAvailablePlaceholderScreen(
        icon: icon,
        title: title,
        message: message,
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.semantic,
    required this.showDivider,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppSemanticColors semantic;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: semantic.border1)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: semantic.fg2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: semantic.fg3),
          ],
        ),
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({
    required this.semantic,
    required this.isLoading,
    required this.onTap,
  });

  final AppSemanticColors semantic;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isLoading ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: semantic.border1),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.error,
                  ),
                )
              else
                Icon(
                  LucideIcons.logOut,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
              const SizedBox(width: 12),
              Text(
                l10n.accountSignOutAction,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(LucideIcons.sunMoon, size: 18, color: semantic.fg2),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.accountAppearanceLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _AppearanceToggle(
            mode: mode,
            onChanged: notifier.setThemeMode,
            semantic: semantic,
          ),
        ],
      ),
    );
  }
}

class _AppearanceToggle extends StatelessWidget {
  const _AppearanceToggle({
    required this.mode,
    required this.onChanged,
    required this.semantic,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppearanceChip(
            label: l10n.accountAppearanceLightOption,
            isActive: mode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
            semantic: semantic,
          ),
          const SizedBox(width: 2),
          _AppearanceChip(
            label: l10n.accountAppearanceDarkOption,
            isActive: mode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
            semantic: semantic,
          ),
        ],
      ),
    );
  }
}

String _languageLabel(AppLocalizations l10n, Locale locale) {
  return switch (locale.languageCode) {
    'en' => l10n.accountLanguageEnglish,
    _ => l10n.accountLanguageVietnamese,
  };
}

class _LanguageRow extends ConsumerWidget {
  const _LanguageRow({required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showLanguagePicker(context, locale, notifier.setLocale),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: semantic.border1),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.languages, size: 18, color: semantic.fg2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.accountLanguageLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _languageLabel(l10n, locale),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: semantic.fg3,
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 16, color: semantic.fg3),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showLanguagePicker(
  BuildContext context,
  Locale current,
  ValueChanged<Locale> onSelected,
) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.accountLanguageDialogTitle),
      children: [
        for (final locale in AppLocalizations.supportedLocales)
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onSelected(locale);
            },
            child: Row(
              children: [
                Expanded(child: Text(_languageLabel(l10n, locale))),
                if (locale == current) const Icon(LucideIcons.check, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
}

class _AppearanceChip extends StatelessWidget {
  const _AppearanceChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.semantic,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isActive ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          // /speckit-analyze finding G1: was minHeight: 28 only, below the
          // constitution's >=48x48dp minimum.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? theme.colorScheme.onPrimary : semantic.fg2,
            ),
          ),
        ),
      ),
    );
  }
}
