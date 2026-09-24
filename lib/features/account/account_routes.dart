import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/account_screen.dart';
import 'presentation/forgot_password_screen.dart';
import 'presentation/reset_password_screen.dart';
import 'presentation/sign_in_screen.dart';
import 'presentation/sign_up_screen.dart';

Widget accountScreenRoute(BuildContext context, GoRouterState state) =>
    const AccountScreen();

Widget signInRoute(BuildContext context, GoRouterState state) =>
    const SignInScreen();

Widget signUpRoute(BuildContext context, GoRouterState state) =>
    const SignUpScreen();

Widget forgotPasswordRoute(BuildContext context, GoRouterState state) =>
    const ForgotPasswordScreen();

Widget resetPasswordRoute(BuildContext context, GoRouterState state) =>
    const ResetPasswordScreen();
