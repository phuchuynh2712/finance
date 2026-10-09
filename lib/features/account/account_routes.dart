import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/features/account/presentation/account_screen.dart';
import 'package:finance/features/account/presentation/change_password_screen.dart';
import 'package:finance/features/account/presentation/forgot_password_screen.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';
import 'package:finance/features/account/presentation/pin_flow_screen.dart';
import 'package:finance/features/account/presentation/reset_password_screen.dart';
import 'package:finance/features/account/presentation/security_screen.dart';
import 'package:finance/features/account/presentation/sign_in_screen.dart';
import 'package:finance/features/account/presentation/sign_up_screen.dart';

Widget accountScreenRoute(BuildContext context, GoRouterState state) =>
    const AccountScreen();

/// The remaining "not available yet" menu rows on Hồ sơ (secure-storage-
/// routing-cleanup Tier B) — one route, keyed by [AccountPlaceholderFeature],
/// so each gets its own URL instead of sharing an unaddressable push. Bảo mật
/// is no longer one of them: it opens the real [SecurityScreen].
enum AccountPlaceholderFeature { notifications, help }

Widget accountPlaceholderRoute(BuildContext context, GoRouterState state) {
  final l10n = AppLocalizations.of(context);
  final feature = AccountPlaceholderFeature.values.byName(
    state.pathParameters['feature']!,
  );
  final (icon, title) = switch (feature) {
    AccountPlaceholderFeature.notifications => (
      LucideIcons.bell,
      l10n.accountNotificationsRowLabel,
    ),
    AccountPlaceholderFeature.help => (
      LucideIcons.helpCircle,
      l10n.accountHelpRowLabel,
    ),
  };
  return NotAvailablePlaceholderScreen(
    icon: icon,
    title: title,
    message: l10n.notAvailablePlaceholderMessage,
  );
}

/// `/account/security` — the Security screen (change password, biometric).
Widget securityRoute(BuildContext context, GoRouterState state) =>
    const SecurityScreen();

/// `/account/security/change-password`, pushed from the Security screen.
Widget changePasswordRoute(BuildContext context, GoRouterState state) =>
    const ChangePasswordScreen();

/// `/account/security/pin/:mode` (`setUp`, `change` or `turnOff`), pushed from
/// the Security screen and from the one-time PIN offer. An unknown mode falls
/// back to the Security screen instead of failing.
Widget pinFlowRoute(BuildContext context, GoRouterState state) {
  final mode = PinFlowMode.values.asNameMap()[state.pathParameters['mode']];
  return mode == null ? const SecurityScreen() : PinFlowScreen(mode: mode);
}

Widget signInRoute(BuildContext context, GoRouterState state) =>
    const SignInScreen();

Widget signUpRoute(BuildContext context, GoRouterState state) =>
    const SignUpScreen();

Widget forgotPasswordRoute(BuildContext context, GoRouterState state) =>
    const ForgotPasswordScreen();

Widget resetPasswordRoute(BuildContext context, GoRouterState state) =>
    const ResetPasswordScreen();
