# Feature Specification: Spending Balance Hub & Envelope Retirement ("Thu chi")

**Feature Branch**: `20260919-220007-spending-balance-hub`

**Created**: 2026-09-19

**Status**: Draft

**Input**: User description: "Trao đổi bằng tiếng việt. viết spec, plan,... code bằng tiếng anh. Đọc tất cả nội dung trong folder \"E:\\Study\\design\\thu-chi-package\". Lưu giữ những cái liên quan để làm reference về lâu dài. Tôi muốn làm trang thu chi để thực hiện xem trực tiếp số tiền từng khoản sau khi chi tiêu trong 1 thời gian. Thu nhập, chi tiêu, xem lịch sử giao dịch sẽ được làm ở spec khác. Đồng thời chỉnh lại hiển thị icon màu xanh thay cho chip xanh ở dưới navigation bar." Scope was expanded mid-session, after the user asked "Bạn định khi nào sẽ xóa Envelope?" ("When are you planning to delete Envelope?"), to also fully retire the legacy `Envelope` data model and every screen/table that depends on it — see Clarifications below.

## Clarifications

### Session 2026-09-19

- Q: A group has no allocation formula of its own (it's cleared once the group gains its first child) — what balance does the group's own row show? → A: The live sum of all its children's balances, computed on the fly (not a separately stored value), matching how Kiểm soát chi tiêu already computes a group's aggregate percentage from its children.
- Q: When the user taps "Thu nhập", "Chi tiêu", or "Xem lịch sử giao dịch" (none of which have their own spec yet), what should the "not yet available" state look like? → A: Navigate to a dedicated placeholder screen with a back action, the same pattern already used for the "Báo cáo" tab's `HistoryPlaceholderScreen`.
- Q: When is `Envelope` (the retired predecessor to Kiểm soát chi tiêu) actually going to be deleted? → A: Now, in this same feature — not deferred to a later feature.
- Q: `Envelope` has two business mechanics `ExpenseControlItem` doesn't have yet: "covering envelope" (borrowing from another envelope when one goes negative) and "rounding receiver" (the one envelope that absorbs a percentage-split's rounding remainder). How should these be handled when retiring Envelope? → A: Drop both mechanics entirely for now; a future income/expense-recording feature will redesign equivalents (or decide they're not needed) if and when it needs them. Items are simply allowed to go negative with no special handling.
- Q: `OverviewScreen` ("Tổng quan" tab) and `PlanScreen` (income-allocation confirmation, reached only via `OverviewScreen`'s FAB — not a bottom-nav tab of its own) both depend entirely on `Envelope`/`AllocationEvent`. What happens to them? → A: `PlanScreen` is deleted outright (it has no other entry point once `OverviewScreen`'s FAB is removed). `OverviewScreen` is replaced with the same "not yet available" placeholder pattern used elsewhere in this feature — a full "Tổng quan" redesign is explicitly deferred to a later feature, since the user confirmed it "chưa có gì" (has no real content yet) worth preserving or porting.
- Q: `ExpenseEntry` (an expense transaction) has a required foreign key to `Envelope`, and `ExpenseFormScreen`/`ExpenseFormController` implement the overspend/covering-envelope UI on top of it. What happens to them? → A: Deleted outright, along with their tests. A future income/expense-recording feature builds a new expense-recording flow from scratch against `ExpenseControlItem`; this feature does not attempt to carry the old form/logic forward.
- Q: `sync_worker.dart` reconciles local balances against a Supabase view (`envelope_balances`) that reads from the tables being dropped. What happens to that reconciliation logic? → A: Deleted outright along with the tables/view it depends on. A future feature redesigns reconciliation for `ExpenseControlItem.balance` if and when that becomes necessary.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View the current balance of every budget item at a glance (Priority: P1)

A user opens the "Thu chi" tab to see, for every group and item they've set up in Kiểm soát chi tiêu, how much money is actually left in it right now — not the allocation formula (%/fixed amount), but the real remaining balance after whatever income and spending has happened over time.

**Why this priority**: This is the entire purpose of the feature — a live financial snapshot the user can check at any time without doing mental math. Without it, the screen has no content.

**Independent Test**: Can be fully tested by opening the "Thu chi" tab with an existing set of Kiểm soát chi tiêu groups/items and confirming each one shows a balance value (even if that value is 0 for every item, since no transaction feature exists yet) matching the same tree structure (groups with expandable children, standalone items) already used in Kiểm soát chi tiêu.

**Acceptance Scenarios**:

1. **Given** the user has at least one top-level item and one group with children set up in Kiểm soát chi tiêu, **When** they open "Thu chi", **Then** they see every top-level item and group listed, each showing a balance amount formatted as currency (e.g., "5.150.000 đ").
2. **Given** a group has children, **When** the user taps the group's row, **Then** the group expands to reveal its children's individual balances, each formatted the same way; tapping again collapses it.
3. **Given** an item's balance is zero or positive, **When** it is displayed, **Then** the amount is shown in the app's positive/informational color (blue, matching the rest of the app's numeric displays).
4. **Given** an item's balance is negative (spending has exceeded what was available, with no covering/borrowing mechanism — negative is simply allowed and shown as-is), **When** it is displayed, **Then** the amount is shown in the app's danger/negative color and prefixed with a minus sign, so overspending is visually obvious at a glance.
5. **Given** the user has no groups or items set up yet in Kiểm soát chi tiêu, **When** they open "Thu chi", **Then** they see a message directing them to set up items in Kiểm soát chi tiêu first, with no confusing empty list.
6. **Given** the user creates a new item or group in Kiểm soát chi tiêu (saving its allocation formula), **When** they open or return to "Thu chi", **Then** the new item/group already appears in the balance list automatically, showing a balance of 0 — no separate setup or sync step is needed on "Thu chi" itself. That item's balance only changes later, once a future income-recording feature applies its formula to real income.

---

### User Story 2 - Distinguish this screen from the formula-editing screen (Priority: P2)

A user who is used to Kiểm soát chi tiêu (where they define *what percentage or fixed amount* each item should receive) needs to immediately understand that "Thu chi" shows something different: the *actual money currently sitting in each item*, not the plan for how future income should be split.

**Why this priority**: Without this distinction the two screens look confusingly similar (same groups/children tree) and a user could mistake a real balance for a formula percentage or vice versa. It's P2 because the underlying data display (User Story 1) has to exist first before this distinction can even be shown.

**Independent Test**: Can be tested by comparing the "Thu chi" screen side-by-side with the Kiểm soát chi tiêu screen and confirming a Vietnamese speaker or business stakeholder can tell, without help, which one is "hiện tại" (current/actual) and which is "kế hoạch" (formula/plan) based on wording and layout alone.

**Acceptance Scenarios**:

1. **Given** the user is on "Thu chi", **When** they view the section listing groups/items, **Then** the section is labeled to indicate these are actual current balances ("Số dư từng khoản"), not allocation formulas.
2. **Given** the user is on "Thu chi", **When** they view any group or item row, **Then** no formula-related controls (percentage/fixed-amount toggle, edit-formula affordance) appear — this screen is read-only with respect to formulas.

---

### User Story 3 - Reach the (future) income/expense actions and history from one hub (Priority: P3)

A user on "Thu chi" sees clear entry points for recording income, recording an expense, and reviewing past transactions, even though those flows are not built in this feature — so the hub screen doesn't feel like a dead end and the layout doesn't need to be reworked again when those flows ship.

**Why this priority**: These entry points are visual/navigational scaffolding for follow-up work, not core value on their own — but placing them correctly now avoids a disruptive re-layout later, and the design mockup explicitly includes them as part of this single screen's layout.

**Independent Test**: Can be tested by confirming the "Thu nhập" (income) button, "Chi tiêu" (expense) button, and "Xem lịch sử giao dịch" (view transaction history) row are all present, visually match the design, and — since their destinations are out of scope for this feature — each navigates to its own dedicated placeholder screen (with a way back), the same pattern already used for the "Báo cáo" tab.

**Acceptance Scenarios**:

1. **Given** the user is on "Thu chi", **When** the screen loads, **Then** they see two side-by-side action buttons ("Thu nhập" styled in the success/green treatment, "Chi tiêu" styled in the danger/red treatment) above the balance list.
2. **Given** the user is on "Thu chi", **When** they view the screen, **Then** they see a "Xem lịch sử giao dịch" row between the action buttons and the balance list.
3. **Given** the user taps "Thu nhập", "Chi tiêu", or "Xem lịch sử giao dịch", **When** the tap registers, **Then** the app navigates to a dedicated "not yet available" placeholder screen (matching the existing "Báo cáo" tab's placeholder pattern) with a clear way to go back to "Thu chi", rather than doing nothing, crashing, or navigating somewhere unrelated.

---

### User Story 4 - Bottom navigation shows selection with icon color, not a pill background (Priority: P2)

A user glancing at the bottom navigation bar on any screen sees the active tab's icon and label highlighted in the brand blue color — matching the design system — instead of today's filled pill/chip shape behind the icon.

**Why this priority**: This is a standalone visual correction unrelated to the "Thu chi" screen's own content, bundled into this feature because it was identified during the same design review. It's P2 (not P1) because it's a polish fix, not new functional value, but it's visible on every screen so it should not wait indefinitely.

**Independent Test**: Can be tested by opening any tab and confirming the selected tab's icon and label render in blue with no visible background shape behind the icon, then switching tabs and confirming the highlight moves correctly with no pill remaining on the previously active tab.

**Acceptance Scenarios**:

1. **Given** the bottom navigation bar is showing, **When** a tab is selected, **Then** that tab's icon and label render in the brand primary blue color, and no pill/chip background shape appears behind the icon.
2. **Given** the bottom navigation bar is showing, **When** a tab is not selected, **Then** that tab's icon and label render in the app's muted/inactive color, matching today's inactive appearance.
3. **Given** the user switches from one tab to another, **When** the switch completes, **Then** the blue highlight moves to the newly selected tab and the previously selected tab returns to the inactive color with no residual background shape.

---

### User Story 5 - Retire the legacy Envelope data model entirely (Priority: P1)

A developer (and, indirectly, every user) no longer has two parallel, disconnected systems for tracking budget balances — `Envelope` (retired from the bottom navigation but still fully alive underneath) is deleted completely: its table, every table that references it, every screen that displays or edits it, and every piece of business logic (overspend handling, covering-envelope borrowing, rounding-receiver allocation, balance reconciliation) built on top of it. `ExpenseControlItem` (extended by User Story 1 with a real `balance`) becomes the single, sole source of truth for budget balances going forward.

**Why this priority**: This is P1 alongside User Story 1 — the two are two sides of the same decision. Leaving `Envelope` alive after "Thu chi" stops reading from it would mean the app permanently carries two disconnected balance systems, one of them silently orphaned and untestable-by-neglect, which directly violates the "single source of truth" spirit the user asked for when they raised "when are you planning to delete Envelope?" as a direct challenge to the narrower original scope.

**Independent Test**: Can be tested by confirming that after this feature ships: (a) the `Envelope`/`AllocationEvent`/`AllocationEventLine`/`EnvelopeCoverage` tables and their Supabase equivalents no longer exist; (b) no file under `lib/` imports `Envelope` or any of its related types; (c) the app builds, runs, and passes its full test suite with zero references to the deleted concepts; (d) `OverviewScreen` and `PlanScreen`'s old behavior is gone, replaced per this story's scenarios below.

**Acceptance Scenarios**:

1. **Given** a user with existing local data from before this feature, **When** the app is upgraded, **Then** the local database migration removes the `Envelope`-related tables (and any rows they contained) without crashing or corrupting `ExpenseControlItem`/`ExpenseControlItems`' own data.
2. **Given** the user opens the "Tổng quan" tab, **When** the screen loads, **Then** they see the same "not yet available" placeholder pattern used by "Báo cáo" and "Thu chi"'s three scaffolded entry points (User Story 3) — not the old envelope list, not a crash, not a blank screen.
3. **Given** the user was previously able to reach "Plan" (income allocation) via "Tổng quan"'s floating action button, **When** they open "Tổng quan" now, **Then** no such button or any other path to a "Plan" screen exists anywhere in the app.
4. **Given** the app previously had a "Thêm chi tiêu" (add expense) flow reachable from "Thu chi", **When** a developer or tester looks for it now, **Then** it no longer exists — recording an expense is out of scope for the entire app until a future feature builds it against `ExpenseControlItem`.
5. **Given** the app's background sync worker runs, **When** it performs its regular reconciliation pass, **Then** it no longer attempts to read the (now-deleted) `envelope_balances` Supabase view or reconcile any `Envelope`-related balance.

---

### Edge Cases

- What happens when a group's children list is long enough to need scrolling while expanded? The screen must remain scrollable as a whole (matching Kiểm soát chi tiêu's existing scroll behavior) — no separate inner scroll region for the children list.
- What happens when an item's name or balance amount is unusually long (e.g., a very large or very negative number)? The amount must remain fully visible without being clipped or truncated, consistent with the currency-display precedent already established in Kiểm soát chi tiêu.
- What happens when a group has zero children (all children were deleted after the group was created)? The group still renders as a non-expandable row (no chevron), consistent with how Kiểm soát chi tiêu already treats a childless group as a leaf.
- What happens when the underlying Kiểm soát chi tiêu tree changes (an item is added, renamed, or deleted) while the user has "Thu chi" open? The balance list reflects the change live, the same reactive-stream pattern already used elsewhere in the app.
- What happens to a user's existing `ExpenseEntry`/`Envelope`/`AllocationEvent` rows when the database migration runs? They are deleted along with their tables — this data was already effectively orphaned (no bottom-nav tab exposed it as of the prior feature), and the user has confirmed no migration/preservation of it is needed.
- What happens if a future feature needs the "covering" or "rounding receiver" concepts again? It designs them fresh against `ExpenseControlItem`'s tree structure — nothing from `Envelope`'s flat-list implementation is preserved or intended to be reused as-is (Clarifications).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST display, for every top-level item and group defined in Kiểm soát chi tiêu, its current actual balance as a currency amount. For a group, this balance MUST be the live sum of all its children's stored balances (computed at display time, not stored separately), matching how Kiểm soát chi tiêu already aggregates a group's percentage from its children.
- **FR-002**: The system MUST render groups and their children in the same expandable/collapsible tree structure already used by Kiểm soát chi tiêu (tap a group's row to expand/collapse; a childless item/group renders without a chevron and cannot be expanded).
- **FR-003**: The system MUST format every balance amount using the app's existing shared currency formatter, so formatting is identical to amounts shown elsewhere in the app.
- **FR-004**: The system MUST display a positive or zero balance in the app's informational/positive color, and a negative balance in the app's danger color with a visible minus sign. No borrowing/covering mechanism exists — a negative balance is simply displayed as-is.
- **FR-005**: The system MUST NOT expose any control for editing an item's allocation formula (percentage or fixed-amount) on this screen — this screen is read-only with respect to formulas.
- **FR-006**: The system MUST label the balance list clearly as showing current/actual balances (e.g., "Số dư từng khoản"), distinguishing it from the formula-planning language used in Kiểm soát chi tiêu.
- **FR-007**: The system MUST display two prominent action entry points, "Thu nhập" (income) and "Chi tiêu" (expense), styled distinctly from each other (success/green vs. danger/red treatments), above the balance list.
- **FR-008**: The system MUST display a "Xem lịch sử giao dịch" (view transaction history) row between the action entry points and the balance list.
- **FR-009**: The system MUST navigate to a dedicated "not yet available" placeholder screen (with a way back to "Thu chi") when the user taps "Thu nhập", "Chi tiêu", or "Xem lịch sử giao dịch", matching the placeholder pattern already used for the "Báo cáo" tab, since their real destination screens are out of scope for this feature.
- **FR-010**: The system MUST show an empty-state message directing the user to set up items in Kiểm soát chi tiêu first when no groups or items exist yet, instead of an empty or confusing list.
- **FR-011**: The system MUST store a current actual balance value for every Kiểm soát chi tiêu item, defaulting to zero for all items until a future transaction-recording feature updates it.
- **FR-011a**: When a new leaf item is created (or an existing leaf item has its allocation formula saved) in Kiểm soát chi tiêu, the system MUST automatically give it a balance record of 0 with no separate setup step — it appears in "Thu chi" the same way every other item does. A group needs no balance record of its own (per FR-001); it automatically reflects its children's balances as soon as they exist.
- **FR-012**: The system MUST update the balance list live/reactively when the underlying Kiểm soát chi tiêu items change (added, renamed, deleted), without requiring a manual refresh.
- **FR-013**: The bottom navigation bar MUST indicate the selected tab using the brand primary blue color applied to that tab's icon and label, with no pill/chip background shape rendered behind the icon.
- **FR-014**: The bottom navigation bar MUST continue to render unselected tabs in the app's existing muted/inactive color and style, unchanged from today.
- **FR-015**: The system MUST delete the `Envelope`, `AllocationEvent`, `AllocationEventLine`, and `EnvelopeCoverage` data structures (local Drift tables and their Supabase equivalents, including the `envelope_balances` view) and every piece of application code that reads or writes them, with no remaining import of any of these types anywhere under `lib/`.
- **FR-016**: The system MUST delete `ExpenseEntry` and its supporting code (`ExpenseFormScreen`, `ExpenseFormController`, the expense repository's overspend/covering-envelope logic) entirely — recording an expense transaction is out of scope for the whole app until a future feature rebuilds it against `ExpenseControlItem`.
- **FR-017**: The system MUST replace `OverviewScreen`'s ("Tổng quan" tab) content with the same "not yet available" placeholder pattern used elsewhere in this feature (FR-009), removing its dependency on `Envelope` and its floating action button that led to "Plan".
- **FR-018**: The system MUST delete `PlanScreen` and `PlanController` entirely, along with the income-allocation-preview logic (`computeAllocationPreview`) they depend on — with `OverviewScreen`'s FAB removed (FR-017), no path to this screen remains anywhere in the app.
- **FR-019**: The system MUST remove the background sync worker's reconciliation logic that reads the `envelope_balances` Supabase view, since that view and the tables it depends on no longer exist.
- **FR-020**: The system MUST provide a local database migration that safely drops the `Envelope`-related tables (in dependency-safe order: dependent tables/views before the tables they reference) without corrupting or losing any `ExpenseControlItem`/`ExpenseControlItems` data.
- **FR-021**: The system MUST remove ARB localization strings that exist solely to support the deleted `Envelope`-related screens/flows, so no dead/unreferenced translation keys remain after this feature ships.

### Key Entities

- **Expense Control Item Balance**: The actual current amount of money associated with one existing Kiểm soát chi tiêu *leaf* item (an item with its own allocation formula, no children). One stored balance value per leaf item, independent of and separate from the item's allocation formula (percentage/fixed amount). Starts at zero for every leaf item and is only ever changed by a future income/expense-recording feature (out of scope here). A group (an item with children) has no balance of its own stored — its displayed balance is always the live sum of its children's balances.
- **(Removed) Envelope, AllocationEvent, AllocationEventLine, EnvelopeCoverage, ExpenseEntry**: These entities and their backing tables are deleted by this feature (User Story 5) — listed here only to make the removal's scope explicit, not because they remain part of the app's data model going forward.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can see the current balance of every one of their budget items within one screen load, with zero additional taps beyond opening the "Thu chi" tab.
- **SC-002**: 100% of balance amounts shown use the same currency formatting already used elsewhere in the app (verified by spot-checking against Kiểm soát chi tiêu's own currency display).
- **SC-003**: A user can distinguish, without being told, that "Thu chi" shows actual money and "Kiểm soát chi tiêu" shows a spending plan, based on on-screen wording alone.
- **SC-004**: Expanding or collapsing any group updates the visible list within the same interaction (no separate loading step), matching the responsiveness already established in Kiểm soát chi tiêu.
- **SC-005**: On every screen in the app, the selected bottom-navigation tab is visually identifiable by icon/label color alone, with no leftover pill-shaped background from the previous design.
- **SC-006**: Zero source files under `lib/` reference `Envelope`, `AllocationEvent`, `AllocationEventLine`, `EnvelopeCoverage`, or `ExpenseEntry` after this feature ships (verified by a full-repo search returning no matches outside version-control history).
- **SC-007**: A fresh install and an upgrade from the immediately prior schema version both result in a working app with no crash, no data corruption in `ExpenseControlItems`, and no visible trace of `Envelope`-era screens.

## Assumptions

- The groups/items structure to display on "Thu chi" is the same Kiểm soát chi tiêu tree that already exists (`ExpenseControlItem`/groups+children) — this feature adds a real balance value per item rather than introducing a separate item hierarchy.
- "Thu nhập", "Chi tiêu", and "Xem lịch sử giao dịch" are placeholders in this feature — their full behavior (recording a transaction, viewing history) will be specified and built in separate, later features, as the user explicitly stated. This includes the expense-recording flow itself: this feature deletes the old `ExpenseFormScreen`/`ExpenseEntry` rather than adapting them, so the future feature starts from a clean slate against `ExpenseControlItem`.
- The rule for *how* a recorded income amount gets automatically split across items according to their allocation formulas (percentage/fixed-amount) belongs entirely to that future income-recording feature. This feature's only responsibility toward that future work is making sure every item already has a balance record (starting at 0, per FR-011a) ready to be updated. Any equivalent to "covering"/"rounding receiver" mechanics, if still wanted, is that future feature's design problem to solve fresh — not a carry-over from `Envelope`.
- The existing "Thu chi" tab/route already exists in the bottom navigation (previously showing a flat, Envelope-based expense list); this feature redesigns that screen's content to match the new design and data source, it does not add a new tab.
- "Tổng quan" is explicitly *not* being redesigned in this feature — the user confirmed it currently has no real content worth preserving. It receives the same interim "not yet available" placeholder as "Báo cáo" and "Thu chi"'s three scaffolded buttons, and a proper redesign is deferred to a future, separate feature.
- The bottom-navigation icon-color fix (User Story 4) applies globally, across every tab and every screen in the app, not only to the "Thu chi" tab — consistent with how the bottom navigation bar has been treated as a single shared component in prior work on this app.
- Dark mode support follows the same color tokens already established for the rest of the app (the design package provides both light and dark specifications), consistent with how every other screen in the app already supports both.
- Deleting `Envelope`/`ExpenseEntry`/`AllocationEvent` and their tests is a clean removal of orphaned code and its coverage, not a reduction in the app's tested surface area — Constitution Principle II's testing bar applies to what remains (`ExpenseControlItem`'s extended balance logic), not to code being deleted wholesale.
