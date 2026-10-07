import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/adaptive_body.dart';
import 'change_password_controller.dart';
import 'widgets/password_field.dart';

/// "Đổi mật khẩu": current password, new password and its confirmation.
///
/// Pops with the [ChangePasswordOutcome] (`changed` or
/// `changedOthersNotEnded`) so the Security screen can confirm it. The typed
/// passwords live only in this screen's text controllers: they are cleared on
/// success and when the screen is left, never stored and never logged.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  /// Lets the password manager save the new password only once it was really
  /// changed; leaving the form any other way cancels the autofill context.
  bool _changed = false;

  @override
  void dispose() {
    for (final controller in [
      _currentController,
      _newController,
      _confirmController,
    ]) {
      controller.clear();
      controller.dispose();
    }
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final outcome = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(
          current: _currentController.text,
          newPassword: _newController.text,
          confirm: _confirmController.text,
        );
    if (!mounted || outcome == null) return;

    _currentController.clear();
    _newController.clear();
    _confirmController.clear();
    setState(() => _changed = true);
    context.pop(outcome);
  }

  void _onEdited(String _) =>
      ref.read(changePasswordControllerProvider.notifier).clearIssues();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final state = ref.watch(changePasswordControllerProvider);
    final canSubmit = !state.isSubmitting && !_changed;

    return Scaffold(
      backgroundColor: semantic.bgApp,
      appBar: AppBar(
        backgroundColor: semantic.bgApp,
        title: Text(l10n.changePasswordTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AdaptiveBody(
            activatesAt: WindowSizeClass.medium,
            maxWidth: AppLayoutTokens.authContentMaxWidth,
            child: AutofillGroup(
              onDisposeAction: _changed
                  ? AutofillContextAction.commit
                  : AutofillContextAction.cancel,
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordField(
                      fieldKey: const ValueKey('change-password-current'),
                      controller: _currentController,
                      focusNode: _currentFocus,
                      label: l10n.changePasswordCurrentLabel,
                      errorText: state.currentIssue?.message(l10n),
                      autofillHint: AutofillHints.password,
                      obscure: !_showCurrent,
                      onToggle: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      textInputAction: TextInputAction.next,
                      onChanged: _onEdited,
                      onSubmitted: (_) => _newFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      fieldKey: const ValueKey('change-password-new'),
                      controller: _newController,
                      focusNode: _newFocus,
                      label: l10n.changePasswordNewLabel,
                      helperText: l10n.passwordRequirementHint,
                      errorText: state.newIssue?.message(l10n),
                      autofillHint: AutofillHints.newPassword,
                      obscure: !_showNew,
                      onToggle: () => setState(() => _showNew = !_showNew),
                      textInputAction: TextInputAction.next,
                      onChanged: _onEdited,
                      onSubmitted: (_) => _confirmFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      fieldKey: const ValueKey('change-password-confirm'),
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      label: l10n.changePasswordConfirmLabel,
                      errorText: state.confirmIssue?.message(l10n),
                      autofillHint: AutofillHints.newPassword,
                      obscure: !_showConfirm,
                      onToggle: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      textInputAction: TextInputAction.done,
                      onChanged: _onEdited,
                      onSubmitted: (_) {
                        if (canSubmit) _submit();
                      },
                    ),
                    if (state.bannerIssue != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.bannerIssue!.message(l10n),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('change-password-submit'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: canSubmit ? _submit : null,
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.changePasswordSubmit),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
