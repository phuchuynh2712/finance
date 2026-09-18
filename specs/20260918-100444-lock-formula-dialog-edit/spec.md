# Feature Specification: Lock Inline Formula Input, Move to Dialog Edit

**Feature Branch**: `20260727-lock-formula-dialog-edit`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "Khóa ô nhập giá trị công thức (%/₫) inline trong danh sách "Kiểm soát chi tiêu" — không cho gõ trực tiếp tại chỗ nữa. Việc sửa công thức của một khoản (bao gồm cả tên/icon/mô tả) chuyển hẳn vào dialog mở qua nút edit (pencil), dialog đã có sẵn cho tên/icon/mô tả thì nay cho sửa cả công thức luôn. Bấm "Lưu" trong dialog chỉ áp dụng tạm thời vào state hiển thị (cập nhật banner tổng quan, chạy validate vượt ngân sách) — chưa ghi xuống database. Bấm nút lớn "Lưu công thức" ở cuối trang mới thực sự ghi chính thức xuống database, giữ nguyên cơ chế pending-edit hiện có. Thêm mới: nếu đang có pending edit chưa lưu chính thức mà người dùng bấm chuyển sang tab khác (Tổng quan, Thu chi, Lịch sử, Hồ sơ), phải hiện hộp thoại xác nhận hỏi có muốn lưu trước khi rời đi hay không, thay vì âm thầm hủy pending edit như hiện tại. Ngoài ra sửa layout: ô giá trị và toggle %/₫ trong dialog nên chiếm gần hết bề ngang có sẵn, không để khoảng trắng thừa, vì giá trị nhập có thể dài (số tiền cố định lớn)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit a formula through the dialog instead of inline (Priority: P1)

A user viewing the "Kiểm soát chi tiêu" (Expense Control) list wants to change an item's allocation formula (percentage or fixed amount). Today they type directly into a small inline field next to each item; going forward, that field is locked (read-only, not focusable, not tappable for input) and the only way to change the formula is to open the same edit dialog already used for the item's name/icon/description, which now also includes the formula fields.

**Why this priority**: This is the core behavior change the whole feature exists for — it fixes a real usability problem (users can accidentally edit values while just browsing the list, and the fixed-width field truncates longer amounts) reported by hands-on review of the current app on a real device.

**Independent Test**: Open the Expense Control screen, attempt to tap/type directly into an item's inline value field — it must not accept input. Tap the item's edit (pencil) button — a dialog opens containing the item's name, icon, description, AND its formula (mode toggle + value), all editable there.

**Acceptance Scenarios**:

1. **Given** the Expense Control list is showing items with formulas, **When** the user taps directly on an item's inline value field, **Then** no cursor appears and no keyboard opens — the field does not accept input.
2. **Given** an item's edit dialog is closed, **When** the user taps that item's edit (pencil) icon, **Then** a dialog opens pre-filled with the item's current name, icon, description, allocation mode (%/₫), and allocation value, all editable.
3. **Given** the edit dialog is open for a leaf item, **When** the user changes the allocation mode and/or value and taps "Lưu" (Save) inside the dialog, **Then** the dialog closes and the list's inline value field (still read-only) immediately reflects the new value, the allocation-summary banner updates accordingly, and the "Lưu công thức" (Save Formula) button becomes enabled — but no data has been written to the database yet.
4. **Given** a formula change is only staged (per Scenario 3) and not yet committed, **When** the user reopens the same item's edit dialog, **Then** it shows the staged (pending) value, not the last-committed database value.

---

### User Story 2 - Commit staged formula changes explicitly (Priority: P1)

A user has staged one or more formula edits via the dialog (User Story 1) and wants those changes to actually persist. They must take a separate, explicit action — pressing "Lưu công thức" — for the changes to be written to the database. This mirrors and extends the existing pending-edit mechanism already in place, so multiple staged edits across several items can be reviewed together (via the live allocation-summary banner) before being committed as one batch.

**Why this priority**: Without this, User Story 1's staged edits would have no way to become permanent, making the dialog-only editing path incomplete. This preserves an already-valuable existing behavior (batch review before commit) that the user explicitly wants kept.

**Independent Test**: Stage formula edits for two different items via their dialogs (User Story 1, Scenario 3), confirm neither is in the database yet (e.g., by checking the list still shows old values elsewhere, or that navigating away and back — without saving — reverts them), then press "Lưu công thức" and confirm both are now persisted.

**Acceptance Scenarios**:

1. **Given** one or more items have staged (pending) formula edits, **When** the user presses "Lưu công thức", **Then** all staged edits are written to the database in one action, the pending state is cleared, and the button becomes disabled again until a new edit is staged.
2. **Given** the combined staged allocation (existing values + all pending edits) would exceed the allowed budget, **When** the user presses "Lưu công thức", **Then** the save is blocked, an error message identifies the offending total, and no data is written — matching today's existing over-budget validation behavior for the batch commit.
3. **Given** no formula edits are currently staged, **Then** the "Lưu công thức" button is not shown (or is disabled), matching today's existing behavior.

---

### User Story 3 - Warn before losing unsaved staged edits by switching tabs (Priority: P2)

A user has staged formula edits (via dialogs) but has not yet pressed "Lưu công thức". If they tap a different bottom-navigation tab (Tổng quan, Thu chi, Lịch sử, Hồ sơ), the app must not silently discard their staged changes. Instead, it must ask them to confirm whether to save first, discard, or cancel the navigation.

**Why this priority**: This is a data-loss guard that only matters once User Stories 1 and 2 exist (there must be a staging mechanism for it to protect). It's explicitly requested as a follow-up safety net once the dialog-based staging flow existed, so it depends on but does not block the first two stories.

**Independent Test**: Stage a formula edit via a dialog, then tap a different bottom-nav tab. A confirmation prompt must appear before navigation completes. Confirming "save" commits the staged edit(s) to the database and then navigates; confirming "discard" clears the staged edit(s) without committing and then navigates; cancelling keeps the user on the Expense Control tab with the staged edit(s) intact.

**Acceptance Scenarios**:

1. **Given** at least one formula edit is currently staged, **When** the user taps a different bottom-navigation tab, **Then** a confirmation dialog appears offering to save the staged edits, discard them, or cancel the tab switch — navigation does not happen until the user picks save or discard.
2. **Given** the confirmation dialog from Scenario 1 is showing, **When** the user chooses to save, **Then** the same validation and persistence behavior as "Lưu công thức" (User Story 2) applies, and only after it succeeds does the tab switch proceed.
3. **Given** the confirmation dialog from Scenario 1 is showing, **When** the user chooses to discard, **Then** all staged edits are cleared without being written to the database, and the tab switch proceeds immediately.
4. **Given** no formula edits are currently staged, **When** the user taps a different bottom-navigation tab, **Then** navigation happens immediately with no confirmation prompt — matching today's existing behavior for the no-pending-edits case.

---

### Edge Cases

- What happens if the user stages a formula edit, opens the dialog again for the *same* item, and changes it a second time before ever pressing "Lưu công thức"? → The second dialog edit replaces the first staged edit for that item; only the latest staged value per item is kept (matches today's existing pending-edit map behavior, keyed by item id).
- What happens if the user stages edits for multiple items and the tab-switch confirmation (User Story 3) fires — does "save" attempt to commit only the currently-open item's edit, or all staged edits across the whole list? → All staged edits across the whole list, the same set "Lưu công thức" would have committed (this is a screen-level guard, not a per-item guard).
- What happens if committing via the tab-switch confirmation's "save" fails validation (over-budget)? → The confirmation dialog surfaces the same over-budget error as User Story 2 Scenario 2, does not clear the staged edits, and does not navigate — the user remains on the Expense Control tab to fix the value.
- What happens to a staged formula edit for an item that gets deleted (by another interaction) before it's committed? → Out of scope for this feature; existing deletion behavior is unchanged and not specifically tested here.
- Does locking the inline field change how it displays an already-staged (pending) value? → No — the field remains read-only for input purposes but continues to visually reflect the current value (committed or staged), matching today's display behavior.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST prevent the allocation-value input field shown inline in the Expense Control item list from accepting keyboard focus or text input; tapping it MUST NOT open a keyboard or place a cursor.
- **FR-002**: The system MUST prevent the inline %/₫ mode toggle shown next to the allocation-value field from being changed by direct interaction with the list; changing the mode MUST only be possible through the edit dialog.
- **FR-003**: The item edit dialog (opened via the pencil/edit icon) MUST include, in addition to its existing name/icon/description fields, the item's allocation mode (%/₫) and allocation value as editable fields.
- **FR-004**: Pressing "Lưu" (Save) inside the edit dialog for a leaf item MUST stage the name/icon/description AND the formula changes together as a single pending edit for that item, without writing any of it to the database.
- **FR-005**: Staging a formula edit via the dialog (FR-004) MUST immediately update the on-screen allocation-summary banner and the read-only inline value display to reflect the new pending value, exactly as today's inline-typing mechanism does.
- **FR-006**: The system MUST run the same over-budget validation used by "Lưu công thức" against the dialog's staged formula value before allowing it to be staged, surfacing the same style of error message inline in the dialog if it would push the total over budget — reusing the dialog's existing budget-validation display for this feature.
- **FR-007**: The "Lưu công thức" button MUST remain the only action that writes staged formula edits to the database, and MUST behave exactly as it does today (enabled only when at least one edit is staged, running full over-budget validation across all staged edits, clearing pending state on success).
- **FR-008**: Re-opening the edit dialog for an item that has a staged (not-yet-committed) formula edit MUST pre-fill the dialog with the staged value, not the last-committed database value.
- **FR-009**: When at least one formula edit is staged and the user attempts to navigate away from the Expense Control tab via bottom navigation, the system MUST intercept that navigation and present a confirmation choice: save staged edits and proceed, discard staged edits and proceed, or cancel and remain on the Expense Control tab.
- **FR-010**: Choosing "save" in the navigation-confirmation prompt (FR-009) MUST apply the identical persistence and validation behavior as pressing "Lưu công thức" (FR-007); if that validation fails, the prompt MUST surface the error, keep the staged edits intact, and MUST NOT navigate away.
- **FR-011**: Choosing "discard" in the navigation-confirmation prompt (FR-009) MUST clear all staged formula edits without persisting them, then complete the navigation.
- **FR-012**: When zero formula edits are staged, navigating away from the Expense Control tab MUST proceed immediately with no confirmation prompt, matching current behavior.
- **FR-013**: The edit dialog's layout for the allocation value field and the %/₫ mode toggle MUST use the available horizontal width efficiently (no more than a small fixed gap between them), rather than leaving significant unused blank space, so that longer fixed-amount values remain fully visible while being entered.

### Key Entities

- **Expense Control Item (leaf)**: An existing entity (no new fields) whose `allocationMethod` (percentage or fixed) and `allocationValue` are, after this feature, only ever changed via the edit dialog's staged-edit flow — never via direct inline text entry.
- **Pending Formula Edit**: The existing in-memory (not persisted) staged-edit concept, keyed by item id, extended to be populated by the edit dialog's "Lưu" action instead of (or in addition to) direct inline typing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can no longer alter an allocation value by tapping or typing into the list directly — 100% of such attempts result in no visible change and no keyboard appearing.
- **SC-002**: 100% of formula changes are staged (not persisted) until "Lưu công thức" — or the save option in the navigation-confirmation prompt — is explicitly pressed, verified by the value in the database remaining unchanged immediately after a dialog "Lưu" until one of those two actions occurs.
- **SC-003**: Users attempting to switch tabs with unsaved staged formula edits are prompted every time (no missed prompts, no accidental silent data loss) across all four other bottom-navigation destinations.
- **SC-004**: A fixed-amount value of at least 9 digits (e.g., 999,999,999) remains fully visible without being clipped or scrolled out of view while being entered in the edit dialog's value field.

## Assumptions

- The existing pending-edit data structure (a map of item id → staged formula edit) is reused as-is; this feature only changes *how* entries get added to it (via dialog "Lưu" instead of inline `onChanged`) and adds one new consumer (the navigation-confirmation prompt) that reads/clears it.
- Group items (which have no formula of their own) are unaffected by this feature beyond no longer showing an inline-editable child row — this feature only concerns leaf items' own formulas.
- The tab-switch confirmation only applies to the five main bottom-navigation destinations already in the app (Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo, Hồ sơ); it does not apply to other navigation actions (e.g., opening the "Thêm khoản mới" dialog, or the system back button) unless those are later found to bypass the same in-app tab state.
- This feature does not change the existing "Thêm khoản mới" (create) dialog's behavior — creating a brand-new item still writes directly on save, as it does not yet have a value to stage against; only editing an *existing* item's formula goes through the new staged-then-committed flow described here. (This matches today's dialog already distinguishing create from edit via `isFormulaEditable`.)
- No new automated-testing framework or approach is introduced; this feature is verified with the same `flutter test` unit/widget-test conventions already used elsewhere in this codebase.
