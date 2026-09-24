# Feature Specification: Home Overview Screen

**Feature Branch**: `20260924-095043-home-overview`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "Trao đổi bằng tiếng việt. viết spec, plan,... code bằng tiếng anh. Đọc tất cả nội dung trong folder E:\Study\design\tong-quan-package. Lưu giữ những cái liên quan để làm reference về lâu dài. Tôi muốn làm trang tổng quan(home) để khi đăng nhập vào app là sẽ thấy một số điểm lưu ý."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See total balance and warnings at a glance (Priority: P1)

A signed-in user opens the app and lands on the Overview tab. Without navigating anywhere else, they immediately see how much money they have left across every account, and whether any account has gone negative.

**Why this priority**: This is the core promise of the feature — "một số điểm lưu ý" (key things to watch) visible the moment the app opens. Without this, the screen has no value over the existing placeholder.

**Independent Test**: Sign in with a user who has at least one account with a negative balance; verify the total balance card and the negative-balance warning both render correctly with no other screen changes required.

**Acceptance Scenarios**:

1. **Given** a signed-in user with two or more accounts, **When** the Overview tab loads, **Then** the user sees one combined total balance figure (rounded/compact form, e.g. "12,4 triệu ₫") with the exact amount shown alongside it (e.g. "12.400.000 ₫").
2. **Given** at least one account currently has a negative balance, **When** the Overview tab loads, **Then** a warning banner names one of the negative accounts and offers a way to see that account's own recent transactions.
3. **Given** no account currently has a negative balance, **When** the Overview tab loads, **Then** no warning banner is shown.

---

### User Story 2 - Scan accounts and recent activity without switching tabs (Priority: P2)

The user wants a quick read on how each of their accounts is doing and what happened recently, without opening the Kế hoạch or Thu chi tabs.

**Why this priority**: This turns the Overview tab from a single number into a working dashboard — it's the "some points to note" beyond just the total.

**Independent Test**: With sample data seeded (multiple accounts, multiple transactions), verify the accounts list and recent-transactions list both render with correct amounts, without needing the warning banner or navigation to be present.

**Acceptance Scenarios**:

1. **Given** the user has one or more accounts, **When** the Overview tab loads, **Then** each account appears as a card showing its name and its current balance, scrollable horizontally if there are more than fit on screen.
2. **Given** the user has recorded income or expense transactions, **When** the Overview tab loads, **Then** the most recent transactions appear in a list, each showing what it was for, which account/group it belongs to, when it happened, and the amount (visually distinct for income vs. expense).
3. **Given** the user has no accounts yet, **When** the Overview tab loads, **Then** the accounts section shows an empty-state message instead of an empty scroll area.
4. **Given** the user has no transactions yet, **When** the Overview tab loads, **Then** the recent-transactions section shows an empty-state message instead of an empty list.

---

### User Story 3 - Personalized greeting on entry (Priority: P3)

The user sees their own name in the header so the screen feels personal, matching the rest of the app's tone.

**Why this priority**: Nice-to-have polish consistent with the design reference; lowest risk and lowest effort of the three stories, and not blocking for the dashboard to deliver value.

**Independent Test**: Sign in with an account that has a display name set, and separately with one that does not; verify the header shows the display name in the first case and a sensible fallback in the second.

**Acceptance Scenarios**:

1. **Given** the signed-in user has a display name on their profile, **When** the Overview tab loads, **Then** the header reads "Xin chào, {tên}" using that name.
2. **Given** the signed-in user has no display name set, **When** the Overview tab loads, **Then** the header falls back to the portion of their email before "@", matching the fallback already used on the Hồ sơ screen.

---

### Edge Cases

- What happens when the total balance is exactly zero, or every account is at zero? → Total balance card still renders with "0 ₫"; no warning banner (zero is not negative).
- What happens when more than one account is negative at the same time? → The warning banner names one negative account (the design shows a single-line banner); the "see detail" action on the banner opens that specific account's transactions (see FR-003), and the accounts list below already shows every account's status so the rest remain discoverable.
- What happens when the compact balance would round to the same display at two different exact values (e.g. 12,449,000 and 12,450,000 both showing "12,4 triệu")? → Acceptable; the exact figure underneath disambiguates.
- What happens while account and transaction data are still loading? → The screen shows a loading placeholder for the combined balance-and-accounts data, and a separate loading placeholder for the recent-transactions list — these are the screen's two independent sources (see FR-010) — rather than blocking the whole screen.
- What happens if loading accounts or transactions fails (e.g. no network, offline-first sync not yet available)? → Each of the two independent sources (balance+accounts together, or recent-transactions) shows its own retry-capable error state; a failure in one does not block the other from rendering.
- What happens when the user is offline? → Overview reads from local data first (consistent with the rest of the app's offline-first behavior) and does not require a live network connection to render.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST replace the current Overview tab placeholder with a real, scrollable home dashboard shown immediately after sign-in and whenever the user selects the "Tổng quan" tab.
- **FR-002**: The system MUST display a single combined total balance across all of the signed-in user's accounts, in both a compact form (e.g. "12,4 triệu ₫") and the exact full amount (e.g. "12.400.000 ₫").
- **FR-003**: The system MUST show a warning when at least one account currently has a negative balance, naming the account, and MUST show no such warning when no account is negative. The warning MUST offer a "see detail" action that opens that account's own transactions (the existing transaction-history screen, pre-filtered to that account/group) — not a way to edit its allocation plan, since a negative balance is explained by recorded spending, not by the plan configuration.
- **FR-004**: The system MUST list the user's accounts with each account's name and current balance, visually indicating at a glance whether a given account's balance is negative, positive, or zero.
- **FR-005**: The system MUST show a "see all" entry point from the accounts list that navigates to the existing Kế hoạch tab (formerly labeled "Kiểm soát" — see FR-015).
- **FR-006**: The system MUST list the user's most recent transactions (across all accounts), each showing a name/description, its account or group, a relative time ("Hôm nay", "Hôm qua", …), and the amount, with income and expense amounts visually distinguished.
- **FR-007**: The system MUST show a "see all" entry point from the recent-transactions list that navigates to the existing transaction-history screen.
- **FR-008**: The system MUST greet the signed-in user by name in the screen header, falling back to the email-prefix convention already used elsewhere in the app when no display name is set.
- **FR-009**: The system MUST show an empty-state message (not a blank area) when the user has no accounts, and separately when the user has no transactions.
- **FR-010**: The system MUST show independent loading and retry-capable error states for the screen's two independent data sources: (a) the combined total-balance-and-accounts-list data — these two always load, fail, and retry together, since the total balance is computed as the sum of the same accounts the list shows, by design (see Assumptions) — and (b) the recent-transactions list. A failure or delay in the recent-transactions list MUST NOT prevent the total balance and accounts list from rendering, and vice versa.
- **FR-011**: The system MUST support both light and dark themes and both Vietnamese and English localization for all new Overview content, consistent with the rest of the app.
- **FR-012**: The header MUST include a notification entry point (bell icon) that navigates to a separate full-screen "not available yet" placeholder — the same one already used by the Hồ sơ tab's notification menu row; no notification content, list, or read/unread state is in scope.
- **FR-013**: The system MUST NOT allow creating, editing, or deleting accounts or transactions from the Overview screen — all data mutation remains on the Kế hoạch and Thu chi tabs; Overview is read-only.
- **FR-014**: The system MUST keep the total balance, accounts list, and recent-transactions list up to date as underlying data changes, without requiring the user to manually refresh the screen.
- **FR-015**: The system MUST rename the bottom-navigation tab currently labeled "Kiểm soát" (English: "Control") to "Kế hoạch" (English: "Plan"), in both languages. This is a display-label change only — the tab's underlying route, screen, and code identifiers are unchanged; this requirement exists because Overview's own copy and the FR-005/FR-003 navigation targets above refer to that tab by name.

### Key Entities

- **Overview Summary**: A read-only, derived view combining the total balance across all accounts and the set of currently-negative accounts. Not persisted; computed from existing account balances.
- **Account Summary Card**: A read-only projection of an existing account (owned by the Kế hoạch feature) showing just its name, icon, and current balance for display in a horizontal list.
- **Recent Transaction Item**: A read-only projection of an existing transaction record (owned by the transaction-history feature) showing description, account/group, relative time, direction (income/expense), and amount, for display in a chronological list capped to the most recent entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A signed-in user can see their total balance across all accounts within 1 second of the Overview tab becoming visible, using locally available data (no network wait).
- **SC-002**: 100% of accounts with a negative balance result in a visible warning on the Overview screen; 0% of the time is a warning shown when no account is negative.
- **SC-003**: A user with existing transaction history can identify their 5 most recent transactions (what, where, when, how much) without leaving the Overview tab.
- **SC-004**: The Overview screen renders correctly (no crashes, no unbounded blank areas) for all four combinations of {has accounts / no accounts} × {has transactions / no transactions}.
- **SC-005**: The Overview screen matches the provided design reference's layout, spacing, and color intent in both light and dark themes, verified by manual or golden-test visual comparison.

## Assumptions

- "Đăng nhập vào app" refers to the existing sign-in flow; this feature only replaces what is shown on the already-scaffolded "Tổng quan" tab (`/overview` route) — no changes to authentication itself.
- "Một số điểm lưu ý" (key things to watch) is interpreted, per the design reference, as: total balance, a negative-balance warning, an accounts-at-a-glance list, and a recent-activity list. No additional "insight" types (e.g. budget-pace alerts, spending trends) are in scope for this feature.
- Recent transactions shows up to 5 most recent entries across all accounts (design reference shows 3 as an example; 5 is a reasonable ceiling that still fits one screen without scrolling excessively). Full history remains available via the existing transaction-history screen's "see all" link.
- Compact balance formatting follows the "X,Y triệu ₫" pattern shown in the design for magnitudes at or above 1,000,000 ₫; amounts below that threshold display in full (no existing compact-currency formatter exists yet in the codebase — this feature adds one).
- "Total balance across all accounts" and "which accounts are negative" are new read-only computations layered on top of the existing per-account balance calculation (`ExpenseControlPlanService.computeItemBalance`); no new persisted data or schema change is required.
- The accounts and recent-transactions sections read from the existing local-first data sources already used by the Kế hoạch and Thu chi tabs; this feature does not introduce a new sync mechanism.
- This feature does not include marking notifications as read, a notification list screen, or any notification content — only the entry point placement, per the design. See Clarifications for the exact behavior of that entry point.
- Screen readers / accessibility semantics follow the same conventions already established on the Thu chi and Kế hoạch screens (existing semantic label patterns), not spelled out again here.
- FR-010 originally described three independently-failing sections. `/speckit-analyze` caught that this contradicted the deliberate two-source architecture (plan.md, data-model.md's total-always-equals-sum invariant), under which the total balance and accounts list share one provider by design so they can never disagree. FR-010 was corrected to describe two sources, matching the chosen architecture, rather than changing the architecture to match the original three-way wording.

## Clarifications

### Session 2026-09-24

- Q: Chuông thông báo (bell icon) ở header nên hoạt động thế nào trong phạm vi tính năng này? → A: Bấm vào chuông điều hướng sang một màn hình riêng (push một route mới) hiển thị "chưa khả dụng" — giống hệt hành vi hiện có ở menu "Thông báo" trên tab Hồ sơ; không xây nội dung/danh sách thông báo thật ở bước này.
- Q: Khi danh sách "Các khoản" hoặc "Giao dịch gần đây" rỗng (chưa có khoản/giao dịch nào), màn Tổng quan nên hiển thị gì? → A: Hiện thông điệp trạng thái rỗng (empty-state) ngay trong từng khu vực tương ứng — vẫn giữ tiêu đề section, không ẩn cả section và không để trống trơn.
- Q: Hai liên kết "Xem tất cả" (của "Các khoản" và của "Giao dịch gần đây") nên dẫn tới đâu? → A: "Các khoản → Xem tất cả" dẫn tới tab Kế hoạch hiện có (trước đây gọi là "Kiểm soát" — xem FR-015); "Giao dịch gần đây → Xem tất cả" dẫn tới màn Lịch sử giao dịch (transaction-history) đã xây ở tính năng trước.
- Q: Nút "Xem chi tiết →" trên banner cảnh báo âm quỹ nên dẫn tới đâu — tab Kế hoạch (nơi cấu hình công thức phân bổ) hay màn Lịch sử giao dịch (nơi xem giao dịch thật)? → A: Dẫn tới màn Lịch sử giao dịch, lọc sẵn theo đúng nhóm/khoản đang âm — vì một khoản âm là do đã *chi* vượt số được phân bổ, nguyên nhân luôn nằm ở các giao dịch đã ghi nhận, không nằm ở công thức phân bổ (tab Kế hoạch không giải thích được "tại sao âm").
