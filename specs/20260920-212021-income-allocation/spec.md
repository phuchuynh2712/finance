# Feature Specification: Income Entry & Automatic Allocation ("Thu nhập")

**Feature Branch**: `20260920-212021-income-allocation`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Trao đổi bằng tiếng việt. viết spec, plan,... code bằng tiếng anh. Đọc tất cả nội dung trong folder \"E:\\Study\\design\\thu-nhap-package\". Lưu giữ những cái liên quan để làm reference về lâu dài. Tôi muốn làm trang thu nhập để add income (thu nhập) khi có lương và tự động phân bổ theo công thức đã lưu. Chia theo phần trăm và theo số tiền cố định từ trên xuống dưới."

## Clarifications

### Session 2026-09-20

- Q: "Chia theo phần trăm và số tiền cố định từ trên xuống dưới" — thuật toán phân bổ nên hoạt động theo thứ tự nào? → A: Theo `sortOrder` từ trên xuống, xử lý lần lượt từng khoản (không tách hai lượt fixed-rồi-percentage như logic Envelope cũ) — mỗi khoản, dù là phần trăm hay cố định, được xử lý đúng theo vị trí hiển thị của nó trên Kiểm soát chi tiêu.
- Q: Khi thu nhập không đủ chia hết theo công thức của một khoản, hệ thống nên làm gì? → A: Đây là chia tiền, không đủ thì không chia thôi — khoản đó nhận hết phần thu nhập còn lại (có thể ít hơn công thức của nó), rồi dừng; các khoản sau đó (theo `sortOrder`) không nhận gì cả. Không khoản nào bị âm từ bước phân bổ này.
- Q: Phần dư sau khi phân bổ hết công thức (ví dụ tổng % + cố định < 100% thu nhập) nên xử lý ra sao? → A: Sẽ có một khoản được đánh dấu lúc tạo là "tiết kiệm" (savings receiver) — phần dư tự động cộng vào khoản đó. Mặc định `false` khi tạo khoản mới. Toàn bộ cây chỉ được có tối đa một khoản đánh dấu; nếu không có khoản nào được đánh dấu, phần dư đơn giản là chưa được phân bổ (không tự ý cộng vào đâu). Cơ chế đánh dấu này hiện chưa tồn tại trong app — cần xây dựng trong phiên làm việc này.
- Q: Cơ chế đánh dấu "khoản nhận phần dư" áp dụng cho loại khoản nào? → A: Chỉ khoản lá (leaf, có công thức riêng) mới được đánh dấu. Một nhóm (có khoản con) không được đánh dấu, vì nhóm không có `balance`/công thức riêng của chính nó. Nếu một khoản lá đang được đánh dấu và sau đó có khoản con được thêm vào nó (biến nó thành nhóm), cờ đánh dấu tự động bị xóa kèm cảnh báo hiển thị cho người dùng.
- Q: Quy tắc "chỉ tối đa 1 khoản được đánh dấu savings receiver" nên được đảm bảo ở tầng nào, trong bối cảnh app offline-first có sync nền (hai thiết bị offline có thể mỗi bên đánh dấu một khoản khác nhau rồi cùng sync lên)? → A: Chỉ validate ở tầng ứng dụng (local) — giống cách app hiện xử lý xung đột tương tự (last-write-wins theo `updated_at`). Không thêm ràng buộc đặc biệt ở tầng dữ liệu/sync cho trường này; chấp nhận rủi ro xung đột hiếm khi đồng bộ.
- Q: Khi khoản đang được đánh dấu "nhận phần dư" có khoản con được thêm vào (cờ tự động bị xóa), cảnh báo nên hiện ngay lúc nào? → A: Ngay trên dialog tạo khoản con đó — người dùng thấy cảnh báo tại chỗ, trong lúc đang tạo/lưu khoản con, không phải sau đó khi họ mở lại khoản cha.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record income and see it distributed automatically (Priority: P1)

A user who just got paid opens "Thu nhập" from the "Thu chi" hub, enters one or more income line items (e.g. "Lương chính: 22.000.000đ", "Thu nhập phụ: 3.000.000đ"), and saves. The app immediately distributes the total across their existing Kiểm soát chi tiêu items according to each item's saved formula (percentage or fixed amount), applied top-down in the same order the items appear in Kiểm soát chi tiêu, and adds the resulting amount to each item's current balance. The user can then check "Thu chi" and see every item's balance already updated — no separate confirmation or preview step is required beyond saving.

**Why this priority**: This is the entire purpose of the feature — without automatic allocation working correctly, the screen has no value beyond being a glorified calculator.

**Independent Test**: Can be fully tested by setting up at least one percentage item and one fixed-amount item in Kiểm soát chi tiêu, entering an income amount that comfortably covers both, saving it, and confirming each item's balance on "Thu chi" increased by exactly the amount its formula specifies.

**Acceptance Scenarios**:

1. **Given** the user has at least one leaf item with a percentage formula and one with a fixed-amount formula in Kiểm soát chi tiêu, **When** they enter an income line item and tap "Lưu thu nhập", **Then** each leaf item's balance increases by its formula's share of the total income amount, processed in the same top-down order as Kiểm soát chi tiêu, and the screen returns to "Thu chi" showing the updated balances.
2. **Given** the user enters two income line items (e.g. "Lương chính" and "Thu nhập phụ"), **When** they view the total before saving, **Then** the total shown equals the sum of every line item's amount.
3. **Given** a fixed-amount item's formula (e.g. 300.000đ) is fully covered by the remaining income when its turn comes, **When** allocation runs, **Then** that item's balance increases by exactly 300.000đ.
4. **Given** a percentage item's formula (e.g. 20%) is fully covered by the remaining income when its turn comes, **When** allocation runs, **Then** that item's balance increases by exactly 20% of the total income amount entered.
5. **Given** the total income entered is 0 or the field is left blank, **When** the user attempts to save, **Then** saving is blocked with an inline validation message — no allocation happens.

---

### User Story 2 - Manage multiple income sources before saving (Priority: P2)

A user with more than one income source (e.g. a main salary and a side income) wants to name and enter each source separately before saving, so the "Thu chi" screen's future transaction history can eventually show where the money came from, and so a typo in one source's amount doesn't require re-entering all of them.

**Why this priority**: The single-income case (User Story 1) already delivers the core value; supporting multiple named sources is what the design mockup shows but is not strictly required for the first income entry to work.

**Independent Test**: Can be tested by adding a second income source via "Thêm nguồn thu nhập khác", entering a name and amount for it, removing the first source, and confirming the total recalculates correctly and only the remaining source's amount is used for allocation.

**Acceptance Scenarios**:

1. **Given** the user is on "Thu nhập" with one income source row already present, **When** they tap "Thêm nguồn thu nhập khác", **Then** a new, empty income source row appears with its own name and amount fields.
2. **Given** two or more income source rows exist, **When** the user taps the delete icon on one row, **Then** that row is removed and the total recalculates immediately to exclude it.
3. **Given** the user has entered a name and amount for at least one income source, **When** they leave a source's name blank, **Then** saving is blocked with an inline validation message identifying which row needs a name.

---

### User Story 3 - Designate one item to receive the leftover (Priority: P2)

A user who wants every đồng of their income to end up somewhere marks one leaf item in Kiểm soát chi tiêu as the "savings receiver." From then on, whenever income is saved and the formulas don't claim 100% of it, the leftover automatically lands in that item's balance instead of going untracked.

**Why this priority**: Without this, income that isn't fully claimed by percentage/fixed formulas simply isn't reflected anywhere, which most users will find surprising the first time it happens — this closes that gap, but the core allocation (User Story 1) is usable without it.

**Independent Test**: Can be tested by marking one leaf item as the savings receiver, setting up formulas that intentionally sum to less than 100%, saving an income entry, and confirming the leftover lands exactly on the marked item's balance.

**Acceptance Scenarios**:

1. **Given** the user is creating or editing a leaf item in Kiểm soát chi tiêu, **When** they view the item's form, **Then** they see a toggle to mark it as the item that receives leftover income, defaulting to off for a new item.
2. **Given** no item is currently marked, **When** the user marks a leaf item as the receiver, **Then** it becomes the sole marked item.
3. **Given** one leaf item is already marked as the receiver, **When** the user attempts to mark a second leaf item as the receiver, **Then** the attempt is blocked with an inline error explaining only one item can hold this designation, and the first item's mark is untouched.
4. **Given** a leaf item is marked as the receiver, **When** the user adds a child item under it (turning it into a group), **Then** the mark is automatically cleared and the user sees a warning explaining why, shown on the very dialog they are using to create that child item.
5. **Given** an item is marked as the receiver, **When** income is saved and the formulas claim less than 100% of the total, **Then** the unclaimed leftover is added to the marked item's balance in the same allocation pass.
6. **Given** no item is marked as the receiver, **When** income is saved and the formulas claim less than 100% of the total, **Then** the leftover is simply not allocated to any item (no error, no silent loss reported elsewhere — spec.md's Success Criteria covers how this is surfaced).

---

### Edge Cases

- What happens when Kiểm soát chi tiêu has zero leaf items set up yet? "Thu nhập" still lets the user enter and save income line items, but the total is simply not distributed anywhere (no items exist to receive it) — the user sees a message directing them to set up items first, matching the existing empty-state pattern on "Thu chi".
- What happens when every leaf item's formula is fixed-amount and their sum happens to exactly equal the income entered? Every item receives exactly its fixed amount, leftover is exactly 0, and the savings-receiver item (if any) receives nothing extra.
- What happens when the income amount is large enough that every formula is fully covered, with money left over, but the marked savings-receiver item's own formula would also have claimed a further share? The receiver first receives its own formula's share (processed in its normal `sortOrder` position), then separately receives the leftover on top, in the same allocation pass.
- What happens when a user enters a negative amount in an income source's amount field? The field rejects it via input validation — negative income amounts are not a valid concept in this feature.
- What happens when the user navigates back from "Thu nhập" without saving? Nothing is persisted — no partial income line items, no allocation — matching the existing unsaved-changes-discarded pattern used elsewhere in the app for non-critical staged input (this screen does not show the tab-switch discard prompt used by Kiểm soát chi tiêu, since it is a pushed screen, not a tab).
- What happens if two income-save operations happen in quick succession (e.g. accidental double-tap)? The save action is disabled while a save is in progress, preventing the same income from being allocated twice.
- What happens if two devices, each offline, independently mark a different leaf item as the savings receiver, and both changes later sync? Since the one-marked-item rule is enforced only at the application layer (per Clarifications), more than one item could transiently end up marked after sync. This is treated the same as any other last-write-wins field conflict already accepted elsewhere in the app — not specially detected or resolved by this feature. If it happens, the next income save's leftover-allocation behavior when more than one item is marked is out of scope to specify further here (an implementation detail `/speckit-plan` may need to pick a tie-break for, e.g. first match in `sortOrder`, but it is not a user-facing requirement of this spec).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let the user add one or more income source line items, each with a name and a positive amount in VND, before saving.
- **FR-002**: The system MUST let the user remove any income source line item before saving, as long as at least the ability to have zero rows exists (removing the last row is allowed; saving with zero rows is blocked per FR-004).
- **FR-003**: The system MUST display a running total equal to the sum of every income source line item's amount, updating live as amounts are entered or rows are added/removed.
- **FR-004**: The system MUST block saving when the total income amount is zero, blank, or any individual income source is missing a name or a positive amount, showing an inline message identifying the problem.
- **FR-005**: Upon a successful save, the system MUST distribute the total income amount across every leaf item in Kiểm soát chi tiêu that has a saved allocation formula (percentage or fixed amount), processed sequentially in the same top-down `sortOrder` used by Kiểm soát chi tiêu (traversing the tree the same way it is displayed there: top-level items and each group's children, in order).
- **FR-006**: For each leaf item processed, the system MUST compute that item's formula share (its fixed amount, or its percentage of the total income amount entered) and add the smaller of (that share) or (the income amount remaining at that point in the sequence) to the item's stored balance.
- **FR-007**: Once the income remaining reaches zero partway through the sequence, the system MUST allocate nothing further to any subsequent leaf item in that same save — no item's balance is ever decreased or left negative as a direct result of this allocation step.
- **FR-008**: The system MUST support marking exactly one leaf item across the entire Kiểm soát chi tiêu tree as the "savings receiver" — a new boolean field on a leaf item, defaulting to `false` for every newly created item.
- **FR-009**: The system MUST reject an attempt to mark a second leaf item as the savings receiver while one is already marked, leaving the existing mark unchanged, and MUST show the user why the attempt was rejected. This uniqueness rule is enforced at the application layer only (checked against the locally known state at the moment of marking) — it is not additionally enforced by a data-layer/sync-level constraint (see Edge Cases for the rare multi-device conflict this implies).
- **FR-010**: The system MUST NOT allow a group (an item with children) to be marked as the savings receiver — the marking control MUST only be reachable/settable for leaf items.
- **FR-011**: When a leaf item that is currently marked as the savings receiver gains its first child (becoming a group), the system MUST automatically clear its savings-receiver mark in the same operation that clears its formula, and MUST surface a warning to the user explaining the mark was removed, shown directly on the child-item create dialog the user is using at the moment of that creation (not deferred to a later visit to the parent item).
- **FR-012**: After every leaf item in the sequence has been processed per FR-006/FR-007, if any income remains unallocated (the formulas claimed less than the total), the system MUST add that remaining amount to the marked savings-receiver item's balance, in the same save operation — added on top of whatever share (if any) that item already received from its own formula in FR-006.
- **FR-013**: If no leaf item is marked as the savings receiver when a leftover remains after FR-006/FR-007, the system MUST leave that leftover unallocated — no item's balance changes as a result of it, and no error is raised.
- **FR-014**: The system MUST persist every leaf item's updated balance atomically as part of one save operation — either every affected item's balance reflects the new allocation, or (on failure) none of them do.
- **FR-015**: The system MUST disable the save action while a save is in progress, so repeated taps cannot allocate the same income entry more than once.
- **FR-016**: The system MUST format every currency amount (income line items, the running total, and anywhere a formula's resulting share might be shown) using the app's existing shared currency formatter.
- **FR-017**: The "Thu nhập" button on "Thu chi" MUST navigate to this new income-entry screen instead of the existing generic "not yet available" placeholder.
- **FR-018**: When Kiểm soát chi tiêu has zero leaf items set up, the system MUST still let the user enter and save income line items (per FR-001–FR-004), and MUST show a message on "Thu nhập" directing the user to set up items in Kiểm soát chi tiêu first, since there is nothing yet to allocate to.
- **FR-019**: Every new user-facing string introduced by this feature MUST ship with both Vietnamese (primary) and English translations in the same change, following the existing localization pattern.

### Key Entities

- **Income Source Line Item**: A single named amount the user enters on "Thu nhập" before saving (e.g. "Lương chính" — 22.000.000đ). Exists only transiently while the user is on this screen; once saved, only the summed total is used for allocation — no per-source line-item history is created or persisted by this feature (that belongs to a future transaction-history feature, per the prior feature's Assumptions).
- **Expense Control Item — Savings Receiver flag** (new field on the existing entity): A boolean, defaulting to `false`, settable only on a leaf item (never a group), indicating this item receives any unallocated leftover from an income save. At most one item across a user's entire tree may have this set to `true` at any time. Automatically cleared (with a user-facing warning) the moment the item gains its first child.
- **Allocation Result** (not a persisted entity): The in-memory outcome of one income save — for each leaf item processed, how much of the income it received (from its own formula, from the leftover rule, or both) — used only to update each item's `balance` field; no separate allocation-event record is created or persisted by this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can record income and see every affected item's balance updated within one save action, with zero additional confirmation steps.
- **SC-002**: 100% of currency amounts shown on "Thu nhập" use the same formatting already used elsewhere in the app.
- **SC-003**: Given a fixed set of leaf items, formulas, and an income amount, allocating that income always produces the same per-item result regardless of how many times it is computed (the algorithm is deterministic).
- **SC-004**: A user can designate a savings receiver and confirm, within one income save, that any leftover after formulas are applied lands exactly on that item — verified by comparing the item's balance before and after against the expected leftover amount.
- **SC-005**: Attempting to mark a second item as the savings receiver is rejected 100% of the time while one is already marked, with the original mark never silently overwritten.

## Assumptions

- Allocation **adds to** each leaf item's existing `balance` rather than overwriting it — consistent with income being recorded repeatedly over time (e.g. every payday) and each item's balance representing an accumulating total.
- Only **leaf items** (items with their own saved formula) are ever allocation targets; a group's displayed balance continues to be the live sum of its children's balances, unchanged by this feature (per the existing `computeItemBalance` behavior) — this feature writes only to leaf items' own stored balance.
- This feature does **not** introduce an immutable allocation-event log or per-income-entry history; it is a fire-and-forget balance update. A future feature may add a transaction/history record if needed — out of scope here, matching how "Xem lịch sử giao dịch" remains a placeholder.
- Negative balances remain an accepted, permanently-displayed state elsewhere in the app (no covering/borrowing mechanism); this feature does not introduce any new negative-balance scenario of its own, since FR-007 guarantees no item goes negative purely from being allocated to (an item can still be negative from a future expense-recording feature, which is unaffected by this one).
- The new balance write follows the existing sync-outbox pattern already used by every other write in this codebase (local write + outbox row in the same transaction) — this feature does not introduce a new sync mechanism.
- **Known gap, not resolved here**: the project's Constitution calls for balances to be server-authoritative and reconciled against a recomputed source of truth; the previous feature removed the only reconciliation mechanism that existed (built for the now-deleted `Envelope` model) and none has been rebuilt since. This feature is the first to write a real, non-zero `balance`, which makes that gap concretely relevant rather than theoretical — but rebuilding server-side reconciliation is a distinct, larger effort (a new Postgres view/function plus sync-worker logic) and is explicitly out of scope for this feature. `/speckit-plan` MUST record this as a documented, justified deviation (Complexity Tracking), not silently ignore it.
- "Thu nhập" is reached only by pushing from "Thu chi" (no bottom-nav tab of its own), matching the design package's note that it has no bottom navigation bar of its own — consistent with how the existing placeholder screen it replaces is already reached.
- Recording an actual expense (spending down a balance) remains entirely out of scope — "Chi tiêu" stays a placeholder, unaffected by this feature.
- The income-entry screen's per-source line items (name + amount, add/remove rows) are not saved as reusable templates between sessions — every time the user opens "Thu nhập," they start from a blank list, consistent with the design mockup showing no persistence affordance and no indication of pre-filled/remembered sources.
- The savings-receiver toggle is added to the existing item create/edit dialog in Kiểm soát chi tiêu (where `allocationMethod`/`allocationValue` are already edited) — no new screen or entry point is introduced for managing this flag.

### Out of scope

- Recording an actual expense (spending down a balance) — "Chi tiêu" stays a placeholder.
- Any transaction/income history log — "Xem lịch sử giao dịch" stays a placeholder; income source line items are not individually persisted once summed (see Key Entities).
- Reviving the retired "covering envelope" (cross-item borrowing) mechanic — not part of this feature under any name.
- Rebuilding server-side balance reconciliation — flagged above as a known gap, not addressed here.
- Any change to the bottom navigation, other "Thu chi" content, or Kiểm soát chi tiêu's existing formula-editing behavior beyond adding the savings-receiver toggle and re-pointing the "Thu nhập" button.
- Saving income sources as reusable templates between sessions.
