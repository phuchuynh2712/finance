import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../auth/auth_state_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_semantic_colors.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/forgot_password_screen.dart';
import '../../features/account/presentation/reset_password_screen.dart';
import '../../features/account/presentation/sign_in_screen.dart';
import '../../features/account/presentation/sign_up_screen.dart';
import '../../features/expense_control/presentation/expense_control_providers.dart';
import '../../features/expense_control/presentation/expense_control_screen.dart';
import '../../features/expense_control/presentation/formatting.dart';
import '../../features/expenses/presentation/spending_screen.dart';
import '../widgets/not_available_placeholder_screen.dart';

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
  // isLocked/isPasswordRecovery can change independently of an auth-state
  // event (e.g. a biometric unlock — FR-011 makes no network call), so the
  // router must also re-evaluate its redirect when either changes.
  ref.listen(appLockProvider, (previous, next) => listenable.ping());
  ref.listen(isPasswordRecoveryProvider, (previous, next) => listenable.ping());
  ref.onDispose(listenable.dispose);
  return listenable;
});

/// Pure auth-redirect decision (FR-025), extracted from the [GoRouterRedirect]
/// closure so it's unit-testable without constructing a real [GoRouterState].
///
/// Returns the path to redirect to, or `null` to allow the navigation as-is.
///
/// [isLocked] and [isPasswordRecovery] default to `false`, so every prior
/// call site/test case is reproduced unchanged (FR-020/FR-021, FR-016).
String? computeAuthRedirect({
  required bool isSignedIn,
  bool isLocked = false,
  bool isPasswordRecovery = false,
  required String matchedLocation,
}) {
  // Checked first, before the ordinary signed-in branches: the password
  // recovery deep link establishes a real (if recovery-scoped) session,
  // which would otherwise make isSignedIn true and redirect straight to
  // /overview, bypassing "Set New Password" entirely.
  if (isPasswordRecovery && matchedLocation != '/reset-password') {
    return '/reset-password';
  }

  final isSigningIn =
      matchedLocation == '/sign-in' ||
      matchedLocation == '/sign-up' ||
      matchedLocation == '/forgot-password';

  if (!isSignedIn && !isSigningIn) return '/sign-in';
  // Signed in but the re-entry gate hasn't been unlocked yet (FR-020/FR-021)
  // — show the Login screen as a lock screen, reusing the same route.
  if (isSignedIn && isLocked && !isSigningIn) return '/sign-in';
  if (isSignedIn && !isLocked && isSigningIn) return '/overview';
  return null;
}

/// The app's 5-tab shell (Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo,
/// Hồ sơ per FR-020, Tổng quan first/default) with an auth guard (FR-025)
/// redirecting unauthenticated users to sign-in before any tab is
/// reachable. The old "Khoản" (Envelopes) tab is retired — Kiểm soát
/// replaces it (research.md §12).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/overview',
    refreshListenable: ref.watch(_routerRefreshListenableProvider),
    redirect: (context, state) => computeAuthRedirect(
      isSignedIn: ref.read(isSignedInProvider),
      isLocked: ref.read(appLockProvider),
      isPasswordRecovery: ref.read(isPasswordRecoveryProvider),
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
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) {
                  final l10n = AppLocalizations.of(context);
                  return NotAvailablePlaceholderScreen(
                    icon: LucideIcons.layoutDashboard,
                    title: l10n.overviewPlaceholderTitle,
                    message: l10n.notAvailablePlaceholderMessage,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expense-control',
                builder: (context, state) => const ExpenseControlScreen(),
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
                path: '/history',
                builder: (context, state) {
                  final l10n = AppLocalizations.of(context);
                  return NotAvailablePlaceholderScreen(
                    icon: LucideIcons.history,
                    title: l10n.tabHistory,
                    message: l10n.historyPlaceholderMessage,
                  );
                },
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

/// Index of the Kiểm soát branch within [appRouterProvider]'s
/// `StatefulShellRoute` — used by [_AppShellState] to discard pending
/// formula edits when the user navigates away (research.md §9).
const _expenseControlBranchIndex = 1;

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  // Guards against a second tap re-entering `_handleDestinationSelected`
  // while the FR-009 confirmation prompt from a first tap is still showing
  // — `onDestinationSelected` is `void Function(int)`, so Flutter itself
  // doesn't await or debounce it.
  bool _prompting = false;

  Future<void> _handleDestinationSelected(int index) async {
    final currentIndex = widget.navigationShell.currentIndex;
    if (_prompting) return;

    // FR-009: only intercept when actually *leaving* Kiểm soát with
    // unsaved staged edits — not when re-tapping the current tab, and not
    // when leaving any other tab.
    final hasPendingEdits = ref.read(pendingItemEditsProvider).isNotEmpty;
    if (currentIndex == _expenseControlBranchIndex &&
        index != currentIndex &&
        hasPendingEdits) {
      setState(() => _prompting = true);
      final choice = await showDialog<_DiscardPromptChoice>(
        context: context,
        builder: (_) => const _DiscardPromptDialog(),
      );
      if (!mounted) return;
      setState(() => _prompting = false);

      switch (choice) {
        case _DiscardPromptChoice.save:
          // The dialog only pops `.save` after a successful commit — a
          // blocked save keeps the dialog open with its inline error
          // instead, so reaching here means it's safe to navigate now
          // (FR-010, Scenario 2).
          break;
        case _DiscardPromptChoice.discard:
          // FR-011, Scenario 3: clear without persisting, then navigate.
          ref.read(pendingItemEditsProvider.notifier).state = {};
          break;
        case null:
        case _DiscardPromptChoice.cancel:
          // FR-009 Edge Case: neither navigates nor discards.
          return;
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIndex = widget.navigationShell.currentIndex;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      body: widget.navigationShell,
      // FR-018: a thin top border separating the bar from content above,
      // matching the app's other fixed headers (e.g.
      // expense_control_screen.dart's own header Container).
      bottomNavigationBar: DecoratedBox(
        key: const Key('bottomNavTopBorder'),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: semantic.border1)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _handleDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(LucideIcons.layoutDashboard),
              label: l10n.tabOverview,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.slidersHorizontal),
              label: l10n.tabExpenseControl,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.receipt),
              label: l10n.tabSpending,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.history),
              label: l10n.tabHistory,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.user),
              label: l10n.tabAccount,
            ),
          ],
        ),
      ),
    );
  }
}

enum _DiscardPromptChoice { save, discard, cancel }

/// FR-009–FR-012: shown when switching away from Kiểm soát with unsaved
/// staged edits. Its "Lưu" choice reuses the exact same commit path as the
/// screen's own "Lưu công thức" button (T017) — including the same
/// over-budget validation — so a blocked save here behaves identically to
/// a blocked save there, just surfaced inline in this dialog instead.
class _DiscardPromptDialog extends ConsumerStatefulWidget {
  const _DiscardPromptDialog();

  @override
  ConsumerState<_DiscardPromptDialog> createState() =>
      _DiscardPromptDialogState();
}

class _DiscardPromptDialogState extends ConsumerState<_DiscardPromptDialog> {
  bool _isSaving = false;
  double? _blockedTotal;

  Future<void> _handleSave() async {
    final pendingEdits = ref.read(pendingItemEditsProvider);
    final items = ref.read(expenseControlItemsStreamProvider).valueOrNull ?? [];
    final planService = ref.read(expenseControlPlanServiceProvider);
    final validation = planService.validateBudget(
      items,
      pendingEdits: pendingEdits,
    );
    if (!validation.isValid) {
      setState(() => _blockedTotal = validation.violatingTotal ?? 0);
      return;
    }

    setState(() => _isSaving = true);
    await ref.read(expenseControlRepositoryProvider).saveFormulas(pendingEdits);
    ref.read(pendingItemEditsProvider.notifier).state = {};
    if (!mounted) return;
    Navigator.of(context).pop(_DiscardPromptChoice.save);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blockedTotal = _blockedTotal;
    return AlertDialog(
      title: Text(l10n.expenseControlDiscardPromptTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.expenseControlDiscardPromptMessage),
          if (blockedTotal != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.expenseControlSaveFormulaBlockedMessage(
                  formatPercent(blockedTotal),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(_DiscardPromptChoice.cancel),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(_DiscardPromptChoice.discard),
          child: Text(l10n.expenseControlDiscardPromptDiscardAction),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: Text(l10n.expenseControlDiscardPromptSaveAction),
        ),
      ],
    );
  }
}
