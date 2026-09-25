import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/overview_screen.dart';
import 'presentation/report_screen.dart';
import 'presentation/spending_screen.dart';

Widget spendingRoute(BuildContext context, GoRouterState state) =>
    const SpendingScreen();

Widget overviewRoute(BuildContext context, GoRouterState state) =>
    const OverviewScreen();

Widget reportRoute(BuildContext context, GoRouterState state) =>
    const ReportScreen();
