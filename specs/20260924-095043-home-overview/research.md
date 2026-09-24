# Phase 0 Research: Home Overview Screen

## Decision 1 — Where new code lives

**Decision**: All new application/presentation code lives under `lib/features/expenses/` (not a new top-level feature, not `expense_control/`).

**Rationale**: `expenses/` already plays this exact role for cross-account read models — `application/balance_view_service.dart` and `application/transaction_history.dart` both already project `expense_control`'s domain into view-ready shapes for the Thu chi tab. Overview needs the same kind of projection, one level higher (across all accounts instead of within one). `test/unit/architecture/architecture_boundary_test.dart` enforces that a feature may only import another feature's `domain/`/`data/` (never its `presentation/`); placing Overview in `expenses/` and importing only `expense_control`'s `domain/` (`ExpenseControlPlanService`, `ExpenseControlNode`, `TransactionHistoryRepository`) keeps it compliant, exactly like the existing `balance_view_service.dart` does today.

**Alternatives considered**: A new `lib/features/overview/` feature — rejected because it would need to import both `expenses/application` (for nothing it doesn't already have access to) and `expense_control/domain`, adding a third feature directory with no code that isn't already naturally at home in `expenses/`.

## Decision 2 — Total balance & negative-accounts computation

**Decision**: Add `OverviewSummaryService` in `lib/features/expenses/application/overview_summary_service.dart`. It takes the same `List<ExpenseControlNode>` root list already exposed by `expenseControlTreeProvider` and, for each root node, calls the existing `ExpenseControlPlanService.computeItemBalance(node)` (`expense_control_plan_service.dart:182-188`) — the same per-root loop `BalanceViewService.prepare()` already does. The service returns an `OverviewSummary` (total = fold of per-root balances, accounts = one `OverviewAccountSummary` per root with name/icon/balance carried through for the card list).

**Rationale**: No existing service sums across all roots or flags negative ones (confirmed: `BalanceViewService.prepare()` returns a flat per-root list without folding; `computeItemBalance` only ever handles one node at a time). Reusing `computeItemBalance` per root avoids re-implementing group-vs-leaf balance rules a second time — that logic (leaf balance is stored; group balance is the live sum of children) is exactly what `computeItemBalance` already encodes, and it is the same rule `BalanceViewService` uses for the per-account cards, so both sections agree with each other by construction.

**Alternatives considered**: Adding a `sumTree()`/`negativeAccounts()` method directly onto `ExpenseControlPlanService` (`expense_control` domain) — rejected because the fold/filter is Overview-specific presentation-adjacent logic, not a rule of the expense-control domain itself; keeping it in `expenses/application` matches where `BalanceViewService` already put the equivalent per-account logic, and avoids growing `expense_control`'s domain surface for a need that has exactly one caller today.

## Decision 3 — Recent transactions across all accounts

**Decision**: Add one new method to the existing domain interface `TransactionHistoryRepository` (`lib/features/expense_control/domain/transaction_history_repository.dart`):

```dart
Stream<List<TransactionHistoryRecord>> watchRecent({required int limit});
```

Implemented in `ExpenseControlRepositoryImpl` (`lib/features/expense_control/data/expense_control_repository_impl.dart`) with the same `where`/`orderBy` chain as the existing `watchTransactionHistory` (`userId.equals(_userId) & deletedAt.isNull()`, `OrderingTerm.desc(occurredAt)` then `createdAt`), dropping the `start`/`end` range clause and adding Drift's `.limit(limit)` (confirmed available on `SimpleSelectStatement` in the project's Drift `^2.22.1`).

**Rationale**: The only existing read path (`watchTransactionHistory(start, end)`) requires a date range — there is no "N most recent regardless of date" query today. Faking it by widening the range and slicing in Dart (e.g. "last 90 days, then `.take(5)`") would fetch and stream far more rows than needed and would silently miss a user's most recent transactions if they happen to be older than the arbitrary window (e.g. a user who hasn't transacted in 4 months). A dedicated `.limit()` query is the constitutionally-correct choice here — Principle IV requires local queries to be "indexed for the query patterns the app actually uses," and this adds a genuine new query pattern (most-recent-N) rather than repurposing the month-range one. The existing `(user_id, occurred_at)` index (established in the transaction-history feature's migration) already serves this query's `WHERE`/`ORDER BY` shape.

**Alternatives considered**: Reuse `watchTransactionHistory` with a wide date range + `.take(N)` client-side — rejected for the correctness and performance reasons above.

## Decision 4 — Relative time labels ("Hôm nay" / "Hôm qua" / "N ngày trước")

**Decision**: A pure function `buildOverviewRecentItems(List<TransactionHistoryRecord>, {required DateTime now})` in a new `lib/features/expenses/application/overview_recent_transactions.dart` maps each record to an `OverviewTransactionItem` carrying a discriminated `OverviewRelativeDay` (`today` / `yesterday` / `daysAgo(int)`) rather than a formatted string. The presentation widget (which has `BuildContext`/`AppLocalizations`) turns that into the localized label at render time.

**Rationale**: Constitution Principle III requires all user-facing strings to go through `AppLocalizations` — an application-layer pure function must not hardcode "Hôm nay"/"Today" text. Passing `now` as a parameter (rather than reading `DateTime.now()` inside the function) matches the existing testability pattern already used for month boundaries in `transaction_history.dart`, keeping the date-bucketing logic unit-testable without wall-clock flakiness.

**Alternatives considered**: Returning a pre-formatted Vietnamese string from the application layer — rejected as a Principle III violation and because it would need a parallel English implementation duplicating the same date-bucketing logic instead of sharing one pure function.

## Decision 5 — Compact currency formatting

**Decision**: Add one additive method to the existing `lib/core/formatting/currency_formatter.dart`:

```dart
String formatCompact(int amountInVnd);
```

For `vi`: amounts ≥ 1,000,000 render as `"X,Y triệu ₫"` (one decimal place, comma as the decimal separator, matching the design reference); amounts below that threshold fall back to the existing `format()` (full grouped form) since there is nothing to abbreviate. For `en` (and any other locale): fall back to `format()` unconditionally — the design reference has no English compact-notation example, and FR-002 already requires the exact full amount to be shown alongside the compact one, so an `en` user is never missing information, only the extra abbreviation.

**Rationale**: No compact/abbreviated formatter exists anywhere in the codebase today (confirmed: `CurrencyFormatter` has exactly one method). The change is additive to the class's public surface — none of its ~7 existing call sites (`expense_screen.dart`, `income_screen.dart`, `spending_screen.dart`, `transaction_history_screen.dart`, `expense_control/presentation/formatting.dart`) need to change, since they simply won't call the new method.

**Alternatives considered**: A `NumberFormat.compactCurrency` (from `intl`) — rejected after inspection because its default English-style abbreviations ("12M") don't match the Vietnamese "X,Y triệu" convention the design specifies, and customizing it per-locale would end up being the same hand-written branch this decision already describes, just routed through an ill-fitting API.

## Decision 6 — Display name for the greeting (architecture-boundary fix)

**Decision**: Read the display name via the existing core-level `authRepositoryProvider` (`lib/core/auth/auth_state_provider.dart:9`, `Provider<AuthRepository>`) directly — `ref.watch(authRepositoryProvider).currentDisplayName` — falling back to the email-prefix convention (`currentEmail?.split('@').first ?? ''`) exactly as `account_screen.dart:81-84` already does.

**Rationale**: The obvious-looking option, `accountAuthActionsProvider`, is declared in `lib/features/account/presentation/account_controller.dart:28` — a **different feature's presentation layer**. Importing it from `expenses/` would fail `architecture_boundary_test.dart`'s cross-feature presentation-import check. Inspecting that provider's own body shows it is a one-line narrowing (`Provider<AccountAuthActions> => ref.watch(authRepositoryProvider)`) purely for the account feature's own test ergonomics; the actual dependency it wraps, `authRepositoryProvider`, is already declared in `core/auth/` and returns `AuthRepository`, which implements `AccountAuthActions`. Watching it directly from `expenses/` needs no new provider and stays entirely within `core/`, satisfying both the architecture-boundary test and the constitution's "something belongs in `core/` only if used by two or more features" rule (this dependency now legitimately serves two features).

**Alternatives considered**: Declaring a second, `expenses`-local copy of an "auth actions" provider — rejected as needless duplication once the existing core provider was found to already do the job.

## Decision 7 — Touch target for the header notification button

**Decision**: Implement the bell as a stock Flutter `IconButton` with `iconSize: 18` (matching the design's 18×18px glyph) and its default `constraints`/padding left untouched — do not shrink them to force a 44×44 visual footprint. `IconButton` already enforces a minimum interactive dimension of 48×48dp by default (`kMinInteractiveDimension`), so its actual on-screen tap area is 48dp without any extra widget wrapping; only the surrounding 44×44 circular background decoration (color, `BoxShape.circle`) needs to visually match the design token, which is independent of the button's own hit-test box.

**Rationale**: The project constitution (Principle III) mandates touch targets ≥48×48dp; the design system's own token (`touchTargetMinPx: 44`) and the mockup's literal 44×44px spec are both below that. This is the one interactive element in the design small enough for the two numbers to appear to conflict — but they don't actually require any bespoke technique to reconcile: Flutter's own `IconButton` default already satisfies the larger number, so the fix is simply "use `IconButton` normally, don't override its constraints down to 44," not a custom hit-area expansion.

**Alternatives considered**: A `SizedBox(width: 48, height: 48)` explicitly wrapping a smaller custom tappable widget — unnecessary once `IconButton`'s own default was confirmed to already meet 48dp; adding an explicit wrapper would be redundant, not incorrect.

## Decision 8 — Loading and error/empty presentation

**Decision**: Reuse existing, already-established patterns rather than introduce new shared widgets:
- Loading: `CircularProgressIndicator()` per section (matches `transaction_history_screen.dart`'s existing loading branch) — no skeleton/shimmer component exists in the codebase, and this feature does not need to introduce the first one.
- Error (retry-capable): `EmptyStateView` with `actionLabel`/`onAction` set (matches `transaction_history_screen.dart:47-53`'s existing error branch, which reuses the same widget for this purpose).
- Empty (no data, no error): `EmptyStateView` with `actionLabel`/`onAction` omitted (suppresses the button; `empty_state_view.dart:39`).

**Rationale**: `lib/core/widgets/empty_state_view.dart` already serves both the "genuinely empty" and "failed, retry available" cases elsewhere in the app; introducing a second, near-duplicate widget for Overview would violate the "no screen may invent a bespoke pattern where an existing one applies" line in Principle III.

## Decision 9 — Navigation targets

**Decision**:
- Accounts "Xem tất cả" → `context.go('/expense-control')` (switches the existing `StatefulShellRoute` branch to the Kế hoạch tab, formerly labeled "Kiểm soát" — see Decision 10 — the same GoRouter path already registered at `app_router.dart:111-115`, unchanged).
- Recent-transactions "Xem tất cả" → `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()))`, replicating exactly the existing call in `spending_screen.dart:79-83` — there is no registered `GoRoute` for the transaction-history screen to target instead.
- Notification bell → the same placeholder push pattern already used by `account_screen.dart`'s notification menu row (`Navigator.push` → `NotAvailablePlaceholderScreen`).
- Negative-balance banner "Xem chi tiết →" → **opens the transaction-history screen pre-filtered to that account's group**, not the Kế hoạch tab. Rationale for this destination specifically: a negative balance means recorded *spending* exceeded what the plan allocated to that account; the Kế hoạch tab only shows/edits the allocation formula and cannot answer "what did I spend" — only the transaction-history screen can. Mechanism: wrap the pushed screen in a nested `ProviderScope` overriding `selectedTransactionHistoryFilterProvider` for that subtree only:
  ```dart
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ProviderScope(
      overrides: [
        selectedTransactionHistoryFilterProvider.overrideWith(
          (ref) => TransactionHistoryFilter.group(accountName),
        ),
      ],
      child: const TransactionHistoryScreen(),
    ),
  ));
  ```
  This requires **zero changes** to `TransactionHistoryScreen`, `transaction_history_providers.dart`, or `transaction_history.dart` — `TransactionHistoryFilter.group(String groupName)` already exists and `buildTransactionHistoryView` already filters by it (`transaction_history.dart:74-82`); only the Overview call site needs this override. `selectedTransactionHistoryMonthProvider` is intentionally left un-overridden (defaults to the current month, same as opening the screen normally); a known limitation is that if the transactions which caused the negative balance predate the current month, the filtered view may show no rows until the user navigates back a month — the group filter persists across month navigation (independent providers), so recovering from this is one or two taps, not a dead end.

  Two further known limitations, both pre-existing behavior of the
  transaction-history feature (not introduced by Overview): the group filter
  only matches `expense` records (`transaction_history.dart:79-82`) — correct
  for this use case, since income cannot cause a negative balance, but it
  means the filtered view excludes income allocated into the account, not
  just expenses from other accounts. And `displayGroupName` is an immutable
  snapshot captured at transaction-record time (per the transaction-history
  feature's snapshot model); if the account was renamed after some of its
  transactions were recorded, `TransactionHistoryFilter.group(accountName)`
  (built from the account's *current* name) will not match those older
  records' frozen former name, so a renamed account's filtered view may
  appear incomplete for transactions recorded before the rename.

**Rationale**: Every target reuses an existing, already-correct navigation path or existing, already-built filter capability; none require adding a new route, and the one non-trivial case (negative-balance detail) needs only a provider override at the call site, not new screen/provider code.

**Alternatives considered**:
- Sending the banner to the Kế hoạch tab (this feature's original draft decision) — rejected once the user clarified that tab governs allocation *planning*, not recorded *spending*; it cannot explain a negative balance.
- Deep-linking into the Kế hoạch tab to scroll to/highlight the specific account — rejected: confirmed directly (`expense_control_routes.dart:6-7`) that `expenseControlRoute` takes no parameters and builds `ExpenseControlScreen()` unconditionally; no item-id-addressable state exists there to hook into, and building one is materially more work than the filtered-history approach for a destination that would still not explain "why negative."
- Adding a constructor parameter to `TransactionHistoryScreen` itself (e.g. `initialFilter`) instead of a `ProviderScope` override — functionally equivalent but unnecessary: since `selectedTransactionHistoryFilterProvider` is a plain (non-family) `StateProvider.autoDispose`, overriding it at the push site achieves the same seeding without touching the screen's own file at all.

## Decision 10 — Rename the "Kiểm soát" tab to "Kế hoạch"

**Decision**: Change exactly one ARB key pair — `tabExpenseControl` (`vi`: "Kiểm soát" → "Kế hoạch"; `en`: "Control" → "Plan") — and nothing else. Confirmed by grep that this key is used in exactly one place, the bottom-navigation label (`app_router.dart:233`); no `AppBar` title or other screen text duplicates the string. Route path (`/expense-control`), screen class (`ExpenseControlScreen`), repository/provider/file names, and every other code identifier are unchanged (FR-015).

**Rationale**: The user pointed out that "Kiểm soát" (Control) mischaracterizes what that tab does — it configures allocation *plans* (formulas for how future income splits across accounts), not day-to-day control/monitoring of spending. Since Overview's own copy and navigation now explicitly reference this tab by name (FR-005) and explicitly distinguish it from where spending is explained (FR-003), getting the label right matters for Overview's own clarity, not only as a cosmetic fix elsewhere.

**Alternatives considered**: A deeper rename (route path, class/file names, provider names) for full internal consistency — explicitly deferred by the user to a separate, later spec, since it touches a larger, already-shipped feature's code identifiers for no user-visible benefit beyond what the label-only change already delivers.

## Summary of NEEDS CLARIFICATION status

None remain. All three spec-level clarifications were resolved with the user during `/speckit-clarify` (see spec.md's Clarifications section) before this research began; the decisions above are purely technical/implementation choices within the boundaries those answers set.
