import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import 'account_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _avatarController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _avatarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(accountControllerProvider);
    final controller = ref.read(accountControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _avatarController,
            decoration: InputDecoration(labelText: l10n.accountAvatarUrlLabel),
          ),
          const SizedBox(height: 8),
          if (state.avatarSaved)
            Text(
              l10n.accountAvatarSavedMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          if (state.avatarErrorMessage != null)
            Text(
              l10n.accountAvatarErrorPrefix(state.avatarErrorMessage!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: state.isSubmittingAvatar
                ? null
                : () => controller.updateAvatar(_avatarController.text),
            child: Text(l10n.accountAvatarSaveAction),
          ),
          const Divider(height: 48),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.accountNewPasswordLabel,
            ),
          ),
          const SizedBox(height: 8),
          if (state.passwordSaved)
            Text(
              l10n.accountPasswordSavedMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          if (state.passwordErrorMessage != null)
            Text(
              l10n.accountPasswordErrorPrefix(state.passwordErrorMessage!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: state.isSubmittingPassword
                ? null
                : () => controller.changePassword(_passwordController.text),
            child: Text(l10n.accountPasswordSaveAction),
          ),
          const Divider(height: 48),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.accountBiometricToggleLabel),
            value: state.isBiometricEnabled,
            onChanged: (enabled) => controller.setBiometricEnabled(enabled),
          ),
          const Divider(height: 48),
          OutlinedButton(
            onPressed: controller.signOut,
            child: Text(l10n.accountSignOutAction),
          ),
        ],
      ),
    );
  }
}
