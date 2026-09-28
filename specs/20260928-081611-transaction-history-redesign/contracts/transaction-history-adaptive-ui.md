# Internal UI Contract: Transaction History Screen Responsive Redesign

## Purpose

Define the internal application/UI contract for Transaction History's
width-cap adoption and confirmation of its existing keyboard/hover
behavior. This is an internal Flutter application contract, not a public
HTTP API. This feature is presentation-layer only.

## Gateway Contracts

**None new.** This feature reads no repository, no database, no network
call it did not already read before.
`transactionHistoryRecordsProvider(month)`,
`selectedTransactionHistoryMonthProvider`, and
`selectedTransactionHistoryFilterProvider` are all consumed unchanged in
both call shape and call site — only the view code around them gains a
width cap; no new provider is introduced.

## Presentation Contracts

### `AdaptiveBody` (existing widget — parameter contract unchanged, internal implementation fixed at its root)

- **Input**: default parameters only —
  `activatesAt: WindowSizeClass.expanded` (840dp, default),
  `maxWidth: AppLayoutTokens.contentMaxWidth` (960dp, default). This
  feature adds **no new parameter** to `AdaptiveBody` and **no new token**
  to `AppLayoutTokens` — see research.md Decision 1. The public parameter
  contract every caller already relies on (`child`, `maxWidth`,
  `activatesAt`) is unchanged; every existing call site continues to
  compile and behave identically **in every way except one** (below).
- **⚠️ Internal implementation change (research.md Decision 1a)**: this
  feature fixes a real, previously-undetected bug in `AdaptiveBody`'s
  *implementation* — crossing the `activatesAt` threshold used to change
  the widget-tree shape returned (`child` directly below the threshold, vs.
  `Center > ConstrainedBox > child` at/above it), which caused Flutter to
  dispose and remount `child`'s entire subtree on every threshold crossing,
  silently resetting any State living inside it (scroll position, text
  field content, animations). The fix makes `AdaptiveBody` **always**
  return the same shape (`Center > ConstrainedBox > child`); only the
  `ConstrainedBox`'s `maxWidth` constraint *value* changes — `double
  .infinity` (a verified layout no-op) below the threshold, the configured
  `maxWidth` at/above it. **This is the one behavioral difference every
  existing caller now gets automatically**: State inside `child` is
  preserved across a live threshold crossing, where before it was silently
  lost. See research.md Decision 1a for the full investigation, the
  empirical verification, the rejected `PageStorageKey` alternative, and
  the one visible consequence (a pre-existing but previously
  threshold-gated vertical-centering behavior for short children inside a
  `SingleChildScrollView`, e.g. Sign In / Sign Up, now applies below the
  threshold too — verified as a consistency fix, not a new regression).
- **Used by** (this feature adds one new caller to the existing 4 from
  `adaptive-layout-foundation` and `auth-screens-responsive`; the
  `AdaptiveBody` fix above applies to all 5 automatically, no per-caller
  change needed):
  | Caller | `activatesAt` | `maxWidth` |
  |---|---|---|
  | `overview_screen.dart` (existing, unchanged call site) | `expanded` (840dp, default) | `contentMaxWidth` (960dp, default) |
  | `report_screen.dart` (existing, unchanged call site) | `expanded` (840dp, default) | `contentMaxWidth` (960dp, default) |
  | `sign_in_screen.dart` (existing, unchanged call site) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `sign_up_screen.dart` (existing, unchanged call site) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `forgot_password_screen.dart` (existing, unchanged call site) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `reset_password_screen.dart` (existing, unchanged call site) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `transaction_history_screen.dart` (new, wraps the `CustomScrollView` containing the month/filter controls + transaction-group slivers + loading/error/empty-state slivers; `_HistoryHeader` stays outside) | `expanded` (840dp, default) | `contentMaxWidth` (960dp, default) |

### Keyboard/hover/focus support (verification only, no new contract surface)

- **Input**: Tab/Shift+Tab keyboard navigation, mouse hover, and
  Enter/Space activation on the back button, previous/next-month buttons,
  filter chips, and (error state only) the retry button.
- **Output**: every enabled control is reachable via Tab in visual order
  with Flutter's default focus indicator, shows Flutter's default hover
  state when a mouse is present, and activates via Enter/Space identically
  to a tap — this is Flutter's existing default `ButtonStyleButton`/
  `InkWell` behavior for `IconButton`, `OutlinedButton`, `InkWell`, and
  `FilledButton`, unchanged by this feature's code (research.md Decision
  3). The disabled next-month button is excluded from the Tab-traversal
  set entirely by the same default machinery — not landed-on-and-inert.
- **This feature introduces no new interactive control and no new
  gesture/focus-handling code** — FR-006 through FR-009's test coverage
  verifies this default behavior holds for this screen's specific controls,
  it does not build new traversal or activation logic.

## Error Contract

**None new.** `AdaptiveBody` cannot fail for any realistic input (its
parameters are plain values, not a computation that can throw). This
feature adds no new error path — the screen's existing loading/error/empty
states (`recordsAsync.when(...)`, `EmptyStateView`) are unchanged, only
their visual width.

## Navigation Contract

**None new.** Zero new routes/paths. This feature does not change how
Transaction History is reached (Overview's "see all", Overview's
negative-balance link, Expense Control) or where its back button navigates
— only the screen's own internal layout and input handling are in scope.
