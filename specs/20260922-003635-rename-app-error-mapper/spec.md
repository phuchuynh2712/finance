# Feature Specification: App Rename to "Kiểm Soát" and Centralized Error Messages

**Feature Branch**: `20260922-003635-rename-app-error-mapper`

**Created**: 2026-09-22

**Status**: Draft

**Input**: User description: "Đổi tên hiển thị của app từ "Khai Tâm" sang "Kiểm Soát" trên toàn bộ codebase (màn đăng nhập, doc-comment trong code, và tất cả tài liệu specs/ lịch sử của các feature trước đây) — KHÔNG đổi icon/logo SVG (giữ nguyên aria-label và toàn bộ file icon, vì đó là thương hiệu chung của cả dự án), KHÔNG đổi applicationId/bundle identifier của Android/iOS (rủi ro cao, giữ nguyên "com.finance.finance"). Và gộp chung trong cùng feature này: xây dựng một cơ chế trung tâm để ánh xạ lỗi (exception) sang thông báo thân thiện, đã được localize, thay cho việc hiện thẳng exception thô ... ra màn hình người dùng — hiện có 7 chỗ trong codebase đang mắc lỗi này ..., cần một error mapper dùng chung đặt tại core/ ..., ánh xạ các mã lỗi phổ biến của Supabase Auth ... sang message tiếng Việt/Anh thân thiện qua l10n, áp dụng lại cho cả 7 điểm gọi hiện có."

## Clarifications

### Session 2026-09-22

- Q: Trong locale tiếng Anh, tên app hiển thị nên là gì? (locale vi đã rõ là "Kiểm Soát") → A: "Budget Control" (dịch nghĩa sang tiếng Anh, không roman hóa "Kiểm Soát")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the correct app name everywhere (Priority: P1)

A user opens the app and sees "Kiểm Soát" as the app's name on the sign-in screen, instead of the old name "Khai Tâm" (which now belongs to a different, unrelated student-management app and would confuse users about which app they're using).

**Why this priority**: The old name actively misleads users about what app they're using, and now collides with a different product's identity. This is a simple, low-risk, high-clarity fix and should ship first.

**Independent Test**: Can be fully tested by opening the sign-in screen and confirming the displayed app name reads "Kiểm Soát", with no other screen or document still describing the app as "Khai Tâm".

**Acceptance Scenarios**:

1. **Given** the app is freshly launched and not signed in, **When** the sign-in screen renders, **Then** the app name displayed is "Kiểm Soát" in the Vietnamese locale and "Budget Control" in the English locale (an English translation of the meaning, not a diacritics-stripped transliteration), not "Khai Tâm"/"Khai Tam".
2. **Given** the project's historical feature documentation (the `specs/` directory), **When** any prior feature's spec, plan, research, or other doc references the app's name in prose, **Then** it reads "Kiểm Soát" instead of "Khai Tâm", so the documentation is internally consistent with the shipped app.
3. **Given** the app's visual brand icon/logo, **When** a user or developer inspects it, **Then** it is unchanged — the icon/logo artwork and its embedded metadata are explicitly out of scope for this rename (see Out of Scope).

---

### User Story 2 - Understand why an action failed, in plain language (Priority: P1)

A user tries to sign in with the wrong password, and instead of seeing a raw technical error like `AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)`, they see a clear, localized sentence explaining what went wrong and, where possible, what to do next (e.g., "Sai email hoặc mật khẩu. Vui lòng thử lại.").

**Why this priority**: This is a trust and usability problem that touches every major write action in the app (sign-in is the most common one a user hits first). Equal priority to the rename because both are simple, contained, user-facing clarity fixes with no architectural risk.

**Independent Test**: Can be fully tested by triggering each of the app's known failure points (wrong password, duplicate email on sign-up, weak password, saving income/expense while offline, etc.) and confirming every one shows a friendly, localized message instead of raw exception text.

**Acceptance Scenarios**:

1. **Given** a user enters an email/password combination that doesn't match any account, **When** they submit the sign-in form, **Then** they see a short, localized message describing the problem (invalid credentials), not a raw exception string.
2. **Given** a user tries to register with an email that's already in use, **When** they submit the sign-up form, **Then** they see the existing friendly "already registered" message (already correct today) — this case must keep working exactly as it does now.
3. **Given** a user tries to register with a password the backend rejects as too weak, **When** they submit the sign-up form, **Then** they see a localized message describing the password requirement, not raw exception text.
4. **Given** a user requests a password reset and the backend call fails for any reason, **When** the failure happens, **Then** they see a localized, friendly message, not raw exception text.
5. **Given** a user saves an income entry or an expense transaction and the write fails (e.g., no network connectivity), **When** the failure happens, **Then** they see a localized, friendly message describing that the save failed and, where the underlying cause is recognizable (e.g., no network), what kind of problem it was — not raw exception text.
6. **Given** a failure type the system has no specific friendly message for (an unrecognized/unexpected error), **When** it occurs anywhere covered by this feature, **Then** the user still sees a generic, localized, friendly fallback message ("Đã có lỗi xảy ra. Vui lòng thử lại." or equivalent) — never raw exception text, even for cases not explicitly enumerated.

---

### User Story 3 - Future write actions get friendly errors for free (Priority: P2)

A developer adding a new screen that saves data to the backend (a future feature) can reuse the same error-to-message mapping instead of reinventing a "prefix + raw exception" pattern, so new features don't reintroduce this problem.

**Why this priority**: This is the structural payoff of centralizing the mapping — it prevents the bug from recurring, but it's a developer-facing outcome, not something an end user directly experiences today, so it's lower priority than the two user-facing fixes above.

**Independent Test**: Can be tested by confirming a single, reusable mapping function/class exists in a shared location and that every one of the 7 known call sites (sign-in, sign-up, reset-password, income save, expense save from both its manual-entry and scan-receipt paths, and the expense-control item form) uses it rather than each keeping its own ad hoc `e.toString()` handling.

**Acceptance Scenarios**:

1. **Given** the shared error-mapping mechanism exists, **When** any of the 7 known failure points in the app throws an exception, **Then** that call site produces its message by calling the shared mechanism rather than formatting the exception itself.
2. **Given** the expense-control item create/edit form, which today captures a raw exception into state but never displays it, **When** a save fails there, **Then** the user now sees a friendly, localized message on-screen (closing this previously-silent gap) using the same shared mechanism.

---

### Edge Cases

- What happens when the failure is a network/connectivity problem (no internet, timeout) rather than a server-rejected request? The friendly message should reflect "can't reach the server" rather than implying the user's input was wrong.
- What happens when an exception type the mapping doesn't recognize occurs (e.g., a new Supabase error code introduced after this feature ships, or a completely unrelated Dart exception)? The user must still see a generic friendly fallback message, never the raw exception (Scenario 6 above).
- What happens to the already-correct duplicate-email-on-sign-up message? It must continue to work exactly as today — this feature generalizes the mechanism, it does not regress an existing correct case.
- What happens to historical `specs/` documents for features that are already complete and shipped? Their prose mentions of the old app name are updated for consistency, but this is a documentation-only change with no effect on runtime behavior or already-shipped functionality.
- What happens to the Android/iOS platform-level app name and bundle identifiers? They already use a generic placeholder ("finance"/"Finance", `com.finance.finance`) rather than "Khai Tâm" today, so no rename is needed there, and the bundle identifier is explicitly not touched by this feature (see Out of Scope) to avoid app-store/publishing risk.

## Requirements *(mandatory)*

### Functional Requirements

**App rename**

- **FR-001**: The system MUST display "Kiểm Soát" as the app's name on the sign-in screen in the Vietnamese locale, and "Budget Control" (an English translation of the meaning) in the English locale, replacing "Khai Tâm"/"Khai Tam".
- **FR-002**: The system MUST NOT change the app's icon/logo artwork or any of its embedded metadata (e.g., accessibility labels inside the icon source files) — the visual brand mark is shared across the whole project and stays as-is.
- **FR-003**: The system MUST NOT change the Android `applicationId` or iOS bundle identifier as part of this rename.
- **FR-004**: All prose references to the app's old name within the project's historical feature documentation (the `specs/` directory) MUST be updated to the new name, so documentation stays internally consistent with the running app. This includes narrative mentions of the app name and any embedded reference-design metadata fields that state the app name, but excludes file paths/filenames that happen to contain the old name in slug form (renaming those is not required) and excludes the shared icon source files (per FR-002).
- **FR-005**: Any non-user-facing internal documentation comment in the source code (e.g., a code comment describing which brand palette a theme is "built from") that names the app MUST be updated to the new name for consistency, even though it has no runtime effect.

**Centralized error mapping**

- **FR-006**: The system MUST provide one shared mechanism that takes a caught exception/error and produces a localized, human-friendly message string, usable from any feature in the app.
- **FR-007**: The shared mechanism MUST recognize and produce a specific friendly message for each of the following common authentication failure situations: wrong email/password combination, email already registered, password rejected as too weak, and too many requests in a short time (rate-limited).
- **FR-008**: The shared mechanism MUST recognize network/connectivity failures (e.g., no internet reachability, request timeout) as a distinct category and produce a friendly message that reflects "couldn't reach the server," not a generic "something went wrong."
- **FR-009**: The shared mechanism MUST produce a generic, localized, friendly fallback message for any exception it does not specifically recognize, so no failure path ever surfaces raw exception text to the user.
- **FR-010**: All messages produced by the shared mechanism MUST be localized (available in both Vietnamese and English, matching the app's existing locale-switching behavior) rather than hardcoded in one language.
- **FR-011**: Every one of the following 7 existing failure-handling call sites MUST be updated to use the shared mechanism instead of its own ad hoc raw-exception formatting: sign-in, sign-up (for its non-duplicate-email fallback path), reset-password, income-entry save, expense-transaction save (manual-entry path), expense-transaction save (scan-receipt path), and the expense-control item create/edit form.
- **FR-012**: The expense-control item create/edit form, which today captures a save failure into state but has no widget displaying it, MUST be updated to actually show the resulting friendly message to the user when a save fails.
- **FR-013**: The existing "email already registered" friendly message on sign-up MUST continue to be shown for that specific case after this feature ships — this feature generalizes the surrounding mechanism without regressing that already-correct behavior.

### Key Entities

- **Error Mapping Result**: A friendly, localized message string (and implicitly, an internal category such as "invalid credentials," "duplicate account," "weak password," "rate limited," "network failure," or "unrecognized/generic") produced from a caught exception. Not a persisted entity — computed on demand each time a failure occurs, never stored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the 7 known write-failure call sites in the app show a localized, human-readable sentence on failure — zero raw exception text (e.g., class names, status codes, internal error codes) is visible to the user in any of them.
- **SC-002**: A user who enters the wrong password can, from the error message alone, understand that their credentials were the problem, without needing to see any technical detail.
- **SC-003**: The sign-in screen and every historical feature document under `specs/` consistently name the app "Kiểm Soát" — zero remaining prose references to "Khai Tâm" outside the explicitly-excluded icon source files and filename slugs.
- **SC-004**: A failure type not explicitly covered by the mapping still produces a friendly, localized message (never raw exception text) — verified by simulating at least one deliberately-unrecognized error type.

## Assumptions

- "Kiểm Soát" is confirmed as the new app display name (short for the app's purpose: personal expense/budget control); no other candidate name is in consideration for this feature.
- The app's visual icon/logo (the lotus-mark artwork) is explicitly staying as the shared brand icon for the whole project regardless of this display-name change — this was confirmed directly by the user and is not a judgment call left to implementation.
- Android's `android:label` and iOS's `CFBundleDisplayName` (the OS-level app name shown on the home screen/app switcher) already read a generic placeholder ("finance"/"Finance") rather than "Khai Tâm" today, so no platform-level app name change is required by this feature; if the user later wants the OS-level name to also say "Kiểm Soát," that is a separate, explicitly-deferred decision (see Out of Scope).
- The Supabase Auth error codes this feature maps to friendly messages (invalid credentials, duplicate email, weak password, rate limit) are the common ones already encountered by this app's existing sign-in/sign-up/reset-password flows; mapping every possible Supabase error code is not required — the generic fallback (FR-009) covers anything not explicitly enumerated.
- "Network/connectivity failure" detection relies on the kind of exception typically thrown by the app's existing HTTP/Supabase client when it cannot reach the server (e.g., a socket/connection exception), not on building new network-reachability detection infrastructure.
- The existing per-screen localized "prefix" strings (e.g., "Đăng nhập thất bại: {error}") are superseded by this feature's friendly messages where they currently interpolate raw exception text; screens may keep a short static localized label alongside the friendly message, but the raw `{error}`-interpolation pattern goes away everywhere it's used for these 7 call sites.
- While working on the app-rename naming polish, a related English-locale inconsistency was fixed directly (already applied, outside `/speckit-implement`): the "Thu chi" bottom-nav tab's English label was "Income & Expense" (3 words), inconsistent with every other tab label being 1-2 words ("Overview", "Control", "History", "Profile"). Changed to "My Wallet" (2 words) per direct user decision. This is a same-spirit, already-completed change, not a pending task for the implementation phase.

### Out of Scope

- Renaming the Android `applicationId` or iOS bundle identifier (`com.finance.finance`) — explicitly excluded per user instruction, due to publishing/update risk.
- Changing the app's icon/logo artwork, or any embedded metadata within the icon source files (e.g., accessibility labels) — explicitly excluded per user instruction; the icon is shared project branding, not tied to the display name.
- Renaming any `specs/` filenames, folder names, or path segments that happen to contain the old app name in slug form (e.g., a file named with "khai-tam" in its path) — only prose content is updated, not file/folder names, to avoid breaking historical file references.
- Mapping every conceivable exception type from every library in the app — only the enumerated common cases (FR-007, FR-008) get a specific message; everything else uses the generic fallback (FR-009).
- Introducing new error *codes* or backend-side changes — this feature is purely about how already-occurring failures are *presented* to the user on the client.
- Renaming the OS-level Android/iOS app label (currently a separate generic placeholder, not "Khai Tâm") — deferred; not part of this feature unless separately requested.
