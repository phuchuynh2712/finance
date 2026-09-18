# Feature Specification: Expense Control

**Feature Branch**: `20260904-144604-expense-control`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Tôi muốn làm trang kiểm soát chi tiêu, là tab thứ 2 sau trang chính. Trong trang này, người dùng sẽ tạo được các khoản tiền cần chi (kế hoạch chi tiêu). Các khoảng này có thể group lại thành nhóm để dễ kiểm soát. Ở đây mỗi khoản có 2 chế độ để config là theo phần trăm, hoặc theo số cố định. Nếu theo phần trăm, thì tất cả các khoản phần trăm cộng lại không được vượt quá 100%. Nếu theo khoản cố định thì không giới hạn. Nhưng nếu thu nhập không đủ sẽ ảnh hưởng việc phân tài chính vào các khoản này. Có thể để một ghi chú, để người dùng có thể nắm được việc này là được. Nếu vừa có cả %, vừa có cả khoản cố định. Thì tổng phần trăm không được vượt quá 100% và phải nhỏ hơn 100%, vì do có khoản cố định cần chi. Hiện tại mockup tôi để trong folder \"E:\\Study\\design\\handoff\", sau khi đọc hiểu thì hãy copy lại những cái liên quan để sử dụng refer sau này. Sau khi copy xong thì xóa folder handoff luôn không cần hỏi."

## Clarifications

### Session 2026-09-04

- Q: How does this feature relate to the existing "Khoản" (Envelope) feature, which already configures percentage/fixed allocation on a flat list with a live balance? → A: Refactor it. The existing Envelope feature is replaced by Expense Control — same underlying concept (planning the expense items to keep under control), just reorganized so items can optionally be grouped. Existing Envelope data is test-only and is discarded, not migrated. Terminology is unified: everything is referred to as an "item" (khoản) that needs to be kept under control, whether or not it belongs to a group.
- Q: The mockup implies the bottom navigation changes from today's 4 tabs to 5 (Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo, Hồ sơ) — is renaming/adding the other tabs in scope now, or only inserting the "Kiểm soát" tab? → A: Do the full 5-tab navigation now: rename "Chi tiêu" → "Thu chi", rename "Cá nhân" → "Hồ sơ", and add a new "Lịch sử/Báo cáo" tab (its content is not specified by this feature — it ships as a placeholder).
- Q: Does this feature need to wire the new grouped-item model into the real income-allocation mechanism (Overview/Thu chi actually using it to plan/track real money), or does it stop at defining and saving the formula? → A: Stops at defining and saving the formula (matches the mockup's own framing: "a formula-definition screen — it does NOT show a real balance"). Rewiring the actual income-allocation flow to consume this new model is separate follow-up work, not part of this feature.
- Q: How does a user choose an item's or group's icon? → A: The user picks it from a predefined icon set (an icon picker), matching the mockup's intentional per-item icon design.
- Q: What is the optional "sub-label" line shown under a group's name in the mockup? → A: It corresponds to an optional description the user enters when creating/editing an item or group — but that description is not displayed on the Expense Control screen itself (the mockup's visual sub-label line renders empty/absent in this feature; the description is stored for other, unspecified future views).
- Q: What should the Expense Control screen show when no items/groups exist yet (first-run empty state, not shown in the mockup)? → A: Show an empty state with guidance text and a prominent "Add new item" CTA; the allocation-totals banner is not shown in this state.

### Session 2026-09-05

- Q: [Corrects the 2026-09-04 answer above] What does a group's sub-label actually show, given that grouping clears the group's own formula (FR-004)? → A: The sub-label shows the **live sum of the group's direct children's formulas** (percent allocated + fixed-item count — the same computation and phrasing as the top-level allocation summary banner, just scoped to this one group's children), not the free-text description, and not blank. Grouping items is meant to make totals *easier* to track at a glance, not hide them — a group that displayed nothing where its children's combined weight should be would defeat that purpose. The description field itself remains stored but still not displayed anywhere on this screen (that part of the prior answer stands).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define an Expense Item's Formula (Priority: P1)

A user wants to plan how their money should be split by defining an expense item (e.g. "Rent", "Groceries", "Savings") and choosing how it's funded: either a percentage of income, or a fixed amount — so they have a clear, written-down spending plan to hold themselves to.

**Why this priority**: This is the entire value proposition of the feature. Without the ability to define and save at least one item's formula, there is nothing to control.

**Independent Test**: On the Expense Control tab, tap "Add new item", enter a name and icon, choose percentage or fixed mode, enter a value, and save. Reopen the app and confirm the item and its formula persisted.

**Acceptance Scenarios**:

1. **Given** no items exist yet, **When** the user opens the Expense Control tab, **Then** an empty state is shown with guidance text and a prominent "Add new item" CTA, and the allocation-totals banner is not shown.
2. **Given** no items exist yet, **When** the user creates an item named "Rent" set to a fixed amount of 5,000,000₫, **Then** the item is saved and listed with its fixed-amount formula, the empty state is replaced by the list, and no percentage constraint is affected.
3. **Given** existing items whose percentages sum to 60%, **When** the user creates a new item at 30%, **Then** the item saves successfully and the running summary shows 90% allocated, 10% free.
4. **Given** existing items whose percentages sum to 60%, **When** the user tries to save a new item at 45% (which would total 105%), **Then** the save is blocked, the offending total is flagged, and no item is persisted.
5. **Given** items already exist with a combined 70% allocation and at least one fixed-amount item, **When** the user tries to save a new percentage item that would bring the total to exactly 100%, **Then** the save is blocked, because the total must remain strictly below 100% whenever any fixed-amount item exists.
6. **Given** the user is configuring a fixed-amount item, **When** they view the formula section, **Then** an informational note explains that fixed-amount items have no upper limit here, but insufficient real income may prevent them from being fully funded when income is actually allocated later.
7. **Given** the user enters a percentage or fixed value of 0 or leaves it blank, **When** they try to save, **Then** the save is blocked with a validation message.

---

### User Story 2 - Group Items Into Categories (Priority: P2)

A user with many expense items wants to organize related ones under a named group (e.g. "Family", "Savings") so the plan stays easy to scan and control, instead of one long flat list.

**Why this priority**: Grouping is an organizational convenience the user explicitly asked for, layered on top of the core item-formula capability from US1. A user can already get value from US1 alone with ungrouped items; grouping improves usability for larger plans.

**Independent Test**: Create a group, add two child items to it with their own formulas, collapse and re-expand the group, and confirm both children and their formulas persist and remain associated with that group.

**Acceptance Scenarios**:

1. **Given** an item with no children currently carries its own formula (e.g. "Family" at fixed 3,000,000₫), **When** the user adds the first child item under it (e.g. "Groceries"), **Then** "Family" stops being directly editable as a formula and becomes a container; its own percentage/fixed value no longer counts toward the totals, only its children's formulas do.
2. **Given** a group has two child items, **When** the user taps the group's name, **Then** the group's children list toggles between expanded and collapsed, independent of every other group's state.
3. **Given** a group has exactly one remaining child item, **When** the user deletes that last child, **Then** the group reverts to being a leaf and can now be given its own formula again.
4. **Given** a group has child items, **When** the user adds another child via "Add item in [Group name]", **Then** the new child appears at the end of that group's children list with no formula set yet, prompting the user to configure it.

---

### User Story 3 - Edit, Reorder, and Delete Items and Groups (Priority: P2)

A user needs to keep their plan up to date as circumstances change — renaming an item, adjusting its formula, reordering groups to match their priorities, or removing items and groups that no longer apply.

**Why this priority**: A plan that can only be created but never adjusted quickly becomes stale and untrustworthy; this is expected maintenance functionality, but it is not needed for a first item to exist (US1) or for grouping to demonstrate value (US2).

**Independent Test**: Edit an existing item's name and formula value, drag-reorder two top-level groups, then delete one item and confirm the remaining state (order, names, formulas) is correct and persists after an app restart.

**Acceptance Scenarios**:

1. **Given** an existing item, **When** the user edits its name, icon, or formula (percentage/fixed and value), **Then** the change is saved and the running allocation summary updates accordingly.
2. **Given** two or more top-level groups, **When** the user drags one by its handle to a new position, **Then** the new order is saved and persists after the app is closed and reopened.
3. **Given** a group with child items, **When** the user deletes the group, **Then** the system warns that its child items will also be removed before the deletion proceeds.
4. **Given** a leaf item (top-level with no children, or a child item), **When** the user deletes it, **Then** it is removed immediately and the running allocation summary updates to reflect its removal.

---

### User Story 4 - Reach Expense Control via Updated Navigation (Priority: P3)

A user opens the app and wants "Kiểm soát" (Expense Control) available as the second tab, right after the main Overview screen, as part of the app's broader 5-tab navigation.

**Why this priority**: Necessary for discoverability, but the screen it links to (US1-US3) is where all the actual value lives; navigation wiring itself is small, low-risk, and depends on nothing else being built first from a testing standpoint.

**Independent Test**: From any tab, confirm the bottom navigation shows exactly 5 tabs in order — Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo, Hồ sơ — and that tapping "Kiểm soát" opens the Expense Control screen.

**Acceptance Scenarios**:

1. **Given** the app is open on any tab, **When** the user looks at the bottom navigation, **Then** exactly 5 tabs are shown in this order: Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo, Hồ sơ.
2. **Given** the user taps "Kiểm soát", **Then** the Expense Control screen (US1-US3) opens.
3. **Given** the user taps "Lịch sử/Báo cáo", **Then** a placeholder screen opens (its real content is out of scope for this feature).
4. **Given** the tabs previously named "Chi tiêu" and "Cá nhân", **When** the user views the navigation, **Then** they now read "Thu chi" and "Hồ sơ" respectively; their underlying screens keep running the old Envelope-based logic, which now shows empty states since Envelope records are discarded (FR-019).

---

### Edge Cases

- What happens when a save would push the percentage total above 100% (with or without fixed items present)? The save is blocked and the violating total is flagged.
- What happens when the percentage total would land at exactly 100% while a fixed-amount item also exists? The save is blocked — the total must remain strictly below 100% whenever any fixed-amount item exists.
- What happens when a group still has children but the user tries to give the group itself a formula? Not directly possible — the formula input for a top-level entry is only available while it has zero children (leaf state).
- What happens when the last child of a group is removed? The group reverts to leaf state and regains its own formula input, matching User Story 2, Scenario 3.
- What happens when a user tries to delete a group that has children? The system requires confirmation and explains that children will be removed too.
- What happens when a name is left blank, or a percentage/fixed value is zero, negative, or blank? The save is blocked with a validation message.
- What happens when the user navigates away without tapping "Lưu công thức" (Save)? Unsaved changes are discarded.
- What happens to a user who previously used the old "Khoản" (Envelope) tab? Their existing envelope data is not carried over; they start fresh in Expense Control (per Clarifications).
- What does the Expense Control screen show when no items or groups exist yet? An empty state with guidance text and a prominent "Add new item" CTA is shown; the allocation-totals banner is not shown in this state (per Clarifications).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to create a new top-level expense control item with a name and an icon chosen from a predefined icon set (icon picker) — free-form/custom icon upload is not supported.
- **FR-002**: Users MUST be able to add child items under a top-level item, turning it into a group; nesting is limited to one level (a top-level entry and its direct children — children cannot have children of their own).
- **FR-003**: A top-level item with zero children MUST carry its own allocation formula directly (percentage or fixed amount), functioning as a leaf; a top-level item with one or more children MUST NOT carry its own formula — only its children's formulas count.
- **FR-004**: When a top-level item's first child is added, the item's own formula (if any) MUST be cleared and MUST stop counting toward allocation totals from that point on.
- **FR-005**: When a group's last remaining child is removed, the group MUST revert to leaf state and become eligible to be given its own formula again.
- **FR-006**: Each leaf item (top-level with no children, or a child item) MUST support exactly one allocation mode at a time: percentage of income, or a fixed amount — switching mode replaces the item's stored value.
- **FR-007**: The sum of all percentage-mode formulas across the entire plan (leaf top-level items and child items alike) MUST NOT exceed 100%.
- **FR-008**: When at least one fixed-amount item exists anywhere in the plan, the sum of all percentage-mode formulas MUST be strictly less than 100% (not equal to 100%), leaving room for the fixed-amount items.
- **FR-009**: Fixed-amount items have no upper limit and are not capped against each other, against percentage items, or against any income figure.
- **FR-010**: The system MUST display an informational note (not a blocking error) explaining that if actual income later turns out insufficient, it will affect how much money fixed-amount items actually receive when income is allocated — this note is informational text, not a computed check against a real income value, since this feature does not track real income.
- **FR-011**: The system MUST show a running summary of the current plan's totals (percentage allocated, count of fixed-amount items, percentage still free) that updates live as the user edits.
- **FR-012**: The system MUST block saving (disable or reject the "Lưu công thức" action) whenever the plan violates FR-007 or FR-008, and MUST indicate what needs to change.
- **FR-013**: Users MUST be able to edit an existing item's or group's name, icon, and (for leaf items) formula mode/value.
- **FR-014**: Users MUST be able to reorder top-level items/groups via drag-and-drop; the new order MUST persist.
- **FR-015**: Users MUST be able to expand or collapse each group's children list independently of other groups.
- **FR-016**: Users MUST be able to delete a leaf item or a group; deleting a group MUST also delete its children, and the system MUST warn the user before this cascading deletion proceeds.
- **FR-017**: The system MUST require a name and a non-zero, non-negative formula value before an item can be saved.
- **FR-018**: All expense control items and groups MUST persist locally and remain available after the app is closed and reopened, following the app's existing offline-first data approach.
- **FR-019**: The existing "Khoản" (Envelope) feature and its data are replaced by this feature; prior envelope records are not migrated or preserved.
- **FR-020**: The bottom navigation MUST show 5 tabs in this order: Tổng quan, Kiểm soát (new — this feature's screen, replacing the old "Khoản" tab), Thu chi (renamed from "Chi tiêu"), Lịch sử/Báo cáo (new placeholder tab, content out of scope), Hồ sơ (renamed from "Cá nhân"). Tổng quan, Thu chi, and Hồ sơ keep their existing underlying screens (rename-only for Thu chi and Hồ sơ) — since those screens still run on the old Envelope-based logic (per Assumptions) and Envelope records are discarded by this feature (FR-019), they will present their existing empty states until a follow-up feature migrates them to the new Expense Control Item model.
- **FR-021**: All user-facing strings introduced by this feature (screen title, banners, buttons, validation and confirmation messages, tab labels) MUST be provided in both Vietnamese (default) and English.
- **FR-022**: Users MAY optionally provide a free-text description for an item or group at creation/edit time; the description is stored but is not displayed on the Expense Control screen itself (it is reserved for other, unspecified future views).
- **FR-023**: When no items or groups exist yet, the system MUST show an empty state with guidance text and a prominent "Add new item" call-to-action instead of the item list; the allocation-totals banner (FR-011) MUST NOT be shown in this state.
- **FR-024**: For a group (a top-level item with one or more children — FR-003), the system MUST display, as the group's sub-label, the live sum of its direct children's formulas (percent allocated + count of fixed-amount children), computed the same way as FR-011's plan-wide summary but scoped to just that group's children; this value is computed on demand and is never itself stored as the group's own formula (FR-003/FR-004 still hold — the group carries no formula of its own).

*Out of scope for this feature*: rewiring the real income-allocation/spending mechanism (today's "Plan"/allocation-preview logic and the Overview/Thu chi screens' balance tracking) to consume the new grouped-item model. That remains on the old Envelope-based logic or is deferred to a follow-up feature, per Clarifications.

### Key Entities *(include if feature involves data)*

- **Expense Control Item**: A single planned expense the user wants to keep under control. Has a name, an icon (chosen from a predefined icon set), an optional free-text description (not displayed on the Expense Control screen itself), a display order among its siblings, and an optional parent item reference (a `null` parent means it is top-level). If it has no children, it directly carries an allocation formula (mode: percentage or fixed amount, plus the corresponding value); if it has one or more children, it carries no formula of its own — it acts purely as a group, and only its children's formulas participate in the plan's totals.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can define a new expense item (with its formula) and see it reflected in the running allocation summary in under 30 seconds.
- **SC-002**: No plan can ever be saved while its percentage total violates the 100%-or-less (or strictly-less-than-100%-with-fixed-items) rule — 100% of invalid attempts are blocked before persisting.
- **SC-003**: A user can group two or more existing items together and reorder groups, with both the grouping and the order surviving an app restart, on the first attempt without external help.
- **SC-004**: From any of the app's 5 tabs, a user can reach the Expense Control screen in exactly one tap.
- **SC-005**: A user glancing at the running summary can state the current percentage allocated and percentage still free without doing their own math.

## Assumptions

- The existing "Khoản" (Envelope) feature's data is treated as test-only and is discarded as part of this refactor, per Clarifications; no data-migration path is required.
- Rewiring the real income-allocation flow (Plan / Overview / Thu chi) to use the new grouped-item model is explicitly out of scope for this feature (per Clarifications); those screens' current Envelope-dependent behavior will be addressed by follow-up work, with the concrete approach left to the implementation plan.
- The "Lịch sử/Báo cáo" tab introduced by the navigation change ships as an empty/placeholder screen in this feature — its real content is a separate, unspecified future feature.
- An item's or group's name need not be unique among siblings or across the whole plan.
- The design mockup (`reference/kiem-soat-spec.md`) specifies a 44×44px minimum touch target, while the project constitution requires ≥48×48dp; the constitution's stricter 48dp minimum takes precedence, reconciled via padding/hit-slop around the visually smaller icons where needed.
- The design mockup's visual details (spacing, colors, icons, typography) are the reference source for this screen's look, copied into `reference/` for this feature; exact pixel values are guidance for the planning/implementation phase, not restated as functional requirements here.
- The mockup's group-name "sub-label" visual slot is repurposed to show the live sum of the group's children's formulas (FR-024, per the 2026-09-05 Clarification correcting the original 2026-09-04 answer) — not the free-text description, which remains stored but unshown on this screen.
- "Income" in this feature is a concept referenced only by informational copy (FR-010) — no income figure is entered, stored, or computed against in this feature's scope.
