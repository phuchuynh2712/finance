import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';

/// The route of the PIN set-up flow, pushed when the offer is accepted.
const pinSetUpRoute = '/account/security/pin/setUp';

/// Offers a PIN (`contracts/pin-ui.md` §5): a dialog with "Đặt mã PIN" (the
/// initial focus, so Enter accepts) and "Để sau". Closing it any other way
/// (Escape, a tap outside) is declining. Returns whether the person accepted.
///
/// Takes the root [navigator] rather than a screen's context: the offer comes
/// right after a sign-in, when the screen that started it is already gone.
Future<bool> showPinOfferDialog(NavigatorState navigator) async {
  if (!navigator.mounted) return false;
  final l10n = AppLocalizations.of(navigator.context);
  final accepted = await showDialog<bool>(
    context: navigator.context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.pinOfferTitle),
      content: Text(l10n.pinOfferMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.pinOfferDeclineAction),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.pinOfferAcceptAction),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// [showPinOfferDialog], then the set-up flow when accepted. The offer never
/// blocks the app: the person is already signed in and on the home screen when
/// it appears, and declining changes nothing.
Future<void> offerPinSetUp(NavigatorState navigator) async {
  final accepted = await showPinOfferDialog(navigator);
  if (accepted && navigator.mounted) {
    await GoRouter.of(navigator.context).push<bool>(pinSetUpRoute);
  }
}

/// The one-time offer (`contracts/pin-ui.md` §5), made after a successful
/// sign-in or sign-up, after the biometric offer. It does nothing unless a PIN
/// may be created here (a phone or tablet whose biometrics are unusable, never
/// the web), none is set, and this account was never offered one on this
/// device. The offer is marked as shown **before** the dialog appears, so
/// declining or closing it means it never comes back.
///
/// Takes the root [navigator] and the app's [container] instead of a screen's
/// context and `ref`: the screen that started the sign-in is gone by the time
/// the dialog before this one is answered. Never throws: a failing offer must
/// not disturb a sign-in that worked.
Future<void> maybeShowPinOfferPrompt(
  NavigatorState navigator,
  ProviderContainer container,
) async {
  if (kIsWeb) return;
  try {
    if (!await container.read(pinAvailableProvider.future)) return;
    final pins = container.read(pinLockRepositoryProvider);
    if (await pins.status() != PinStatus.none) return;
    if (!await pins.shouldOfferPin()) return;
    await pins.markOfferShown();
  } catch (_) {
    return;
  }
  await offerPinSetUp(navigator);
}
