import 'package:flutter/material.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';

/// A password input with a show/hide toggle. Autocorrect and suggestions are
/// off so the keyboard never learns or echoes a password.
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.autofillHint,
    required this.obscure,
    required this.onToggle,
    required this.textInputAction,
    required this.onChanged,
    required this.onSubmitted,
    this.helperText,
    this.errorText,
    this.autofocus = false,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? helperText;
  final String? errorText;

  /// Only where there is a hardware keyboard (a phone must not raise its
  /// on-screen keyboard by itself).
  final bool autofocus;
  final String autofillHint;
  final bool obscure;
  final VoidCallback onToggle;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [autofillHint],
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 18,
            color: semantic.fg3,
          ),
          tooltip: obscure
              ? l10n.signInShowPasswordSemantic
              : l10n.signInHidePasswordSemantic,
          onPressed: onToggle,
        ),
      ),
    );
  }
}
