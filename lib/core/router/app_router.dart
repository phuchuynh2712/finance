import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/percent_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/features/account/account_routes.dart';
import 'package:finance/features/expense_control/expense_control_routes.dart';
import 'package:finance/features/expenses/expenses_routes.dart';

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
      GoRoute(path: '/sign-in', builder: signInRoute),
      GoRoute(path: '/sign-up', builder: signUpRoute),
      GoRoute(path: '/forgot-password', builder: forgotPasswordRoute),
      GoRoute(path: '/reset-password', builder: resetPasswordRoute),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/overview', builder: overviewRoute)],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/expense-control', builder: expenseControlRoute),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/spending', builder: spendingRoute)],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: reportRoute)],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/account', builder: accountScreenRoute)],
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

/// One entry per navigation destination — the single source of truth
/// mapped to both `NavigationDestination` (compact/bottom-bar) and
/// `NavigationRailDestination` (medium-and-above/rail), so the two
/// presentations' icon/label/order can't drift apart from each other
/// (adaptive-layout-foundation research.md Decision 9, data-model.md
/// `_NavDestinationSpec`). `label` defers the `AppLocalizations` lookup to
/// build time, matching how each destination's label was already read
/// inline before this change.
typedef _NavDestinationSpec = ({
  IconData icon,
  String Function(AppLocalizations) label,
  int branchIndex,
});

String _overviewLabel(AppLocalizations l10n) => l10n.tabOverview;
String _expenseControlLabel(AppLocalizations l10n) => l10n.tabExpenseControl;
String _spendingLabel(AppLocalizations l10n) => l10n.tabSpending;
String _historyLabel(AppLocalizations l10n) => l10n.tabHistory;
String _accountLabel(AppLocalizations l10n) => l10n.tabAccount;

const _navDestinations = <_NavDestinationSpec>[
  (icon: LucideIcons.layoutDashboard, label: _overviewLabel, branchIndex: 0),
  (
    icon: LucideIcons.slidersHorizontal,
    label: _expenseControlLabel,
    branchIndex: 1,
  ),
  (icon: LucideIcons.receipt, label: _spendingLabel, branchIndex: 2),
  (icon: LucideIcons.pieChart, label: _historyLabel, branchIndex: 3),
  (icon: LucideIcons.user, label: _accountLabel, branchIndex: 4),
];

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

  // Owned by State, created once — never inside build() — so Flutter
  // reparents (State.deactivate, not dispose) rather than tearing down and
  // rebuilding widget.navigationShell when the branch below switches
  // between the bottom-bar and rail shapes at a breakpoint crossing
  // (adaptive-layout-foundation research.md Decision 2, Clarification Q2:
  // the currently-viewed screen's own local state — scroll position,
  // unsubmitted form input — must survive the switch).
  final _shellKey = GlobalKey();

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

    // FR-001/FR-002 (adaptive-layout-foundation): the navigation
    // presentation is decided purely by the available window width — never
    // by device/platform — using the shared breakpoint scale so no screen
    // re-derives its own threshold.
    final widthClass = windowSizeClassFor(MediaQuery.sizeOf(context).width);

    // Same GlobalKey-wrapped instance placed into either shape below, so
    // Flutter reparents rather than disposes it across a widthClass switch
    // (see _shellKey's own doc comment).
    final shellContent = KeyedSubtree(
      key: _shellKey,
      child: widget.navigationShell,
    );

    if (widthClass == WindowSizeClass.compact) {
      return Scaffold(
        body: shellContent,
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
              for (final d in _navDestinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label(l10n)),
            ],
          ),
        ),
      );
    }

    // widthClass is medium/expanded/large/extraLarge (>=600dp): a side
    // rail replaces the bottom bar, each destination's icon+label always
    // visible (Clarification Q1, NavigationRailLabelType.all) — no
    // navigation drawer, per the constitution.
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            key: const Key('navRailTrailingBorder'),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: semantic.border1)),
            ),
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: _handleDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _navDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label(l10n)),
                  ),
              ],
            ),
          ),
          Expanded(child: shellContent),
        ],
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
