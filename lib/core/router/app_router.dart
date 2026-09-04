import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../auth/auth_state_provider.dart';
import '../l10n/app_localizations.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/sign_in_screen.dart';
import '../../features/account/presentation/sign_up_screen.dart';
import '../../features/envelopes/presentation/envelopes_screen.dart';
import '../../features/envelopes/presentation/overview_screen.dart';
import '../../features/expenses/presentation/spending_screen.dart';

/// A bare [Listenable] that [GoRouter] watches to know when to re-evaluate
/// its [GoRouterRedirect] — fired manually via [ping] rather than wrapping a
/// raw Stream, since Riverpod's provider `.stream` accessor is deprecated in
/// favor of watching/listening to the provider itself.
class _RouterRefreshListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

final _routerRefreshListenableProvider = Provider<_RouterRefreshListenable>((
  ref,
) {
  final listenable = _RouterRefreshListenable();
  ref.listen(authStateChangesProvider, (previous, next) => listenable.ping());
  ref.onDispose(listenable.dispose);
  return listenable;
});

/// Pure auth-redirect decision (FR-025), extracted from the [GoRouterRedirect]
/// closure so it's unit-testable without constructing a real [GoRouterState].
///
/// Returns the path to redirect to, or `null` to allow the navigation as-is.
String? computeAuthRedirect({
  required bool isSignedIn,
  required String matchedLocation,
}) {
  final isSigningIn =
      matchedLocation == '/sign-in' || matchedLocation == '/sign-up';

  if (!isSignedIn && !isSigningIn) return '/sign-in';
  if (isSignedIn && isSigningIn) return '/overview';
  return null;
}

/// The app's 4-tab shell (Overview, Spending, Envelopes, Account per
/// FR-023, Overview first/default) with an auth guard (FR-025) redirecting
/// unauthenticated users to sign-in before any tab is reachable.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/overview',
    refreshListenable: ref.watch(_routerRefreshListenableProvider),
    redirect: (context, state) => computeAuthRedirect(
      isSignedIn: ref.read(isSignedInProvider),
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const OverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/spending',
                builder: (context, state) => const SpendingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/envelopes',
                builder: (context, state) => const EnvelopesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.layoutDashboard),
            label: l10n.tabOverview,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.receipt),
            label: l10n.tabSpending,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.mail),
            label: l10n.tabEnvelopes,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.user),
            label: l10n.tabAccount,
          ),
        ],
      ),
    );
  }
}
