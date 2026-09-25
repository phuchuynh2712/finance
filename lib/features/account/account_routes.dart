import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'presentation/account_screen.dart';
import 'presentation/forgot_password_screen.dart';
import 'presentation/reset_password_screen.dart';
import 'presentation/sign_in_screen.dart';
import 'presentation/sign_up_screen.dart';

Widget accountScreenRoute(BuildContext context, GoRouterState state) =>
    const AccountScreen();

/// The 3 "not available yet" menu rows on Hồ sơ (secure-storage-routing-
/// cleanup Tier B) — one route, keyed by [AccountPlaceholderFeature], so
/// each gets its own URL instead of sharing an unaddressable push.
enum AccountPlaceholderFeature { notifications, security, help }

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
    AccountPlaceholderFeature.security => (
      LucideIcons.shieldCheck,
      l10n.accountSecurityRowLabel,
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

Widget signInRoute(BuildContext context, GoRouterState state) =>
    const SignInScreen();

Widget signUpRoute(BuildContext context, GoRouterState state) =>
    const SignUpScreen();

Widget forgotPasswordRoute(BuildContext context, GoRouterState state) =>
    const ForgotPasswordScreen();

Widget resetPasswordRoute(BuildContext context, GoRouterState state) =>
    const ResetPasswordScreen();
