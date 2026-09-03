# Feature Specification: Registration & Google Sign-In

**Feature Branch**: `20260726-register-login-google-oauth`

**Created**: 2026-07-26

**Status**: Draft

**Input**: User description: "Tôi muốn làm trang đăng ký để có thể nhập email / username để login được. Nếu có thể login bằng google account (đăng nhập bằng email của google) thì càng tốt. Hãy giúp tôi đề xuất tốt nhất nhé."

## Clarifications

### Session 2026-08-03

- Q: If a user tries to sign in with Google using an email that already has a password-based account, should the system auto-link them (risking account takeover, since email confirmation is disabled) or require an explicit action? → A: Never auto-link by email match. Google sign-in with a matching email is rejected with a clear error directing the user to sign in with email/password instead. Additionally, once signed in (via either method), the user can explicitly link their Google account from the Profile/Account screen — after which future Google sign-ins with that linked account go straight into the same, already-linked account.
- Q: Follow-up discovered during planning — Supabase Auth's server-side behavior for `signInWithIdToken` (the API this feature must use) unconditionally auto-links a Google identity to any existing user sharing a *verified* email, with no project setting to disable it for the sign-in path (only the separate, opt-in explicit-linking API respects a "Manual Linking" toggle). Enforcing the "never auto-link" answer above as stated would require a custom email-lookup endpoint, which is itself a user-enumeration security risk. Given this, how should the two decisions be reconciled? → A (superseded by the next entry — see below): Re-enable email confirmation before sign-in. Further research after this answer found the reasoning behind it was incorrect (Supabase's auto-link decision checks the *incoming* Google identity's verified claim, always true, not the existing account's own confirmation state — so requiring confirmation does not gate the auto-link at all). Do not implement based on this entry; see the corrected entry below.
- Q: Second follow-up — with the above answer's reasoning found incorrect, is there any actual protection against the pre-registration takeover scenario (attacker registers `victim@gmail.com` with a password the attacker knows, hoping the real owner's later Google sign-in gets silently auto-linked into the attacker's account), and if not, should FR-015 stay reverted to "sign in immediately" or should a custom email-lookup safeguard be built? → A: Keep FR-015 as originally decided ("sign in immediately, no email confirmation required") — Supabase's GoTrue server has a *separate*, unconditional safeguard for exactly this scenario: when auto-linking to an existing user, if that existing user is not yet confirmed, GoTrue destroys that user's other identities (including their password) via `RemoveUnconfirmedIdentities` before completing the link (`internal/api/external.go`, `internal/models/user.go` — see research.md §6). Since an attacker registering a victim's email can never confirm it themselves (they don't control the victim's inbox), the attacker's fraudulent account can never escape this "unconfirmed → evicted on real owner's sign-in" state. This protection is unconditional and does not depend on the project's email-confirmation setting, so no spec change is needed beyond documenting the correct mechanism.

### Session 2026-08-04

- Q: The registration form's password field has no way for the user to verify what they typed before submitting (no show/hide toggle, no second field). Should the system add a "Confirm Password" field? → A: Yes — add a required "Confirm Password" field; registration is blocked with an inline error until it matches the Password field exactly.
- Q: Should the registration form also collect a display name and phone number? → A: Yes — add both as optional fields (may be left blank at registration and filled in later from Profile); phone number is stored as plain profile information only, with no OTP/SMS verification.
- Q: Should email/password registration require the user to confirm their email (via a link sent by email) before they can sign in, reversing the original "sign in immediately" decision? → A: Yes — require email confirmation. This is a deliberate reversal of FR-015 as originally decided in the 2026-08-03 session; the earlier decision optimized for a fast (<60s) sign-up flow on the understanding that Supabase's `RemoveUnconfirmedIdentities` mechanism (research.md §6) already closes the pre-registration-takeover risk independently of this setting. That safety analysis still holds and is unchanged — this reversal is a product/UX choice (matching the common "verify your email" pattern users expect), not a security fix. See the Assumptions section for what does and doesn't change as a result.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create an account with email and password (Priority: P1)

A new user who does not yet have an account opens the app, goes to a registration screen, enters an email address and chooses a password, and creates an account. Before they can sign in, they must confirm their email address by opening a confirmation link sent to that address.

**Why this priority**: Today the app only has a sign-in screen (`AuthRepository.signUp` exists but is never called from the UI) — there is no way for a new user to create an account at all. This is the minimum needed to unblock onboarding.

**Independent Test**: Can be fully tested by opening the app with no existing account, completing the registration form with a valid email/password, confirming a "check your email" message appears, clicking the confirmation link received by email, and then confirming the user can sign in — without needing any other user story.

**Acceptance Scenarios**:

1. **Given** the sign-in screen, **When** the user taps "Create account", **Then** the registration screen is shown.
2. **Given** the registration screen, **When** the user enters a valid, unused email, a password meeting the minimum strength rule, and a matching confirmation password (leaving name and phone number blank), and submits, **Then** the account is created (unconfirmed) and the system shows a "check your email to confirm your account" message instead of signing the user in.
3. **Given** a newly registered, unconfirmed account, **When** the user opens the confirmation link from the email Supabase sent, **Then** the account becomes confirmed and the user can subsequently sign in with their email and password.
4. **Given** a newly registered, unconfirmed account, **When** the user attempts to sign in with the correct email and password before confirming, **Then** the system shows a clear message explaining that the email must be confirmed first, with an option to resend the confirmation email.
5. **Given** the registration screen, **When** the user also fills in a display name and/or phone number before submitting, **Then** those values are saved to the new account's profile (regardless of confirmation state).
6. **Given** the registration screen, **When** the user enters an email that already has an account, **Then** the system shows a clear error and does not create a duplicate account.
7. **Given** the registration screen, **When** the user enters a password that doesn't meet the minimum strength rule, **Then** the system shows an inline validation error before submission.
8. **Given** the registration screen, **When** the confirmation password field does not match the password field, **Then** the system shows an inline validation error and does not submit.
9. **Given** the registration screen, **When** the user submits with an invalid email format, **Then** the system shows an inline validation error and does not submit.

---

### User Story 2 - Sign in and register with a Google account (Priority: P2)

A user who has a Google account can tap a single "Sign in with Google" button (shown on both the sign-in and registration screens) and, after choosing their Google account, is signed in — creating a new app account automatically the first time, or automatically joining an existing email/password account that shares the same email.

**Why this priority**: Google sign-in removes the password-creation step entirely and is the fastest path to a working account, but it's an addition on top of the P1 email/password flow, which must exist regardless.

**Independent Test**: Can be fully tested by tapping "Sign in with Google" on a device with at least one Google account configured, completing the Google account chooser, and confirming the user lands in an authenticated state — with no prior password-based registration required.

**Acceptance Scenarios**:

1. **Given** the sign-in screen, **When** the user taps "Sign in with Google" and selects a Google account whose email has no existing app account, **Then** a new app account is created using that account's Google email and the user is signed in.
2. **Given** the sign-in screen, **When** the user taps "Sign in with Google" and selects a Google account that was already used to sign in before (or already linked, per User Story 4), **Then** the user is signed into their existing account (no duplicate account is created).
3. **Given** the user starts the Google sign-in flow, **When** they cancel the Google account chooser, **Then** they are returned to the sign-in screen with no error shown and no account state change.
4. **Given** a user who registered with email/password using an address that matches their Google account's email, **When** they sign in with Google for the first time, **Then** the system automatically links the Google identity to that existing account and signs them in. This is safe against a pre-registration takeover attempt (someone else registering that email with a password they control first) because Supabase automatically evicts every prior identity — including the password — from an account whenever a new OAuth identity attaches to a still-unconfirmed row (research.md §6); an attacker who registered someone else's email can never get that row confirmed themselves, so their account is always in the state this eviction targets.

---

### User Story 4 - Link a Google account from Profile for one-tap future sign-in (Priority: P2)

A signed-in user (via email/password or Google) can go to their Profile/Account screen and explicitly link a Google account — including a Google account whose email is *different* from their app account's email (the case automatic linking, per User Story 2, cannot cover since it only matches on identical email addresses). Once linked, future Google sign-ins with that account go straight into this same app account instead of creating a new one.

**Why this priority**: Automatic linking (User Story 2) already covers the common case of a matching email. This story covers the remaining case — a user who wants to sign in with a Google account under a *different* email than the one they registered with — and lets a user see/manage their linked Google account from one place. Ships alongside Story 2 as a smaller complement to it.

**Independent Test**: Can be tested by signing in with email/password, going to Profile, linking a Google account whose email differs from the app account's email, signing out, then signing in with that same Google account and confirming it lands in the original account (not a new one).

**Acceptance Scenarios**:

1. **Given** a signed-in user on the Profile/Account screen, **When** they choose "Link Google account" and complete the Google account chooser (with any Google account, matching email or not), **Then** that Google account is recorded as linked to their app account.
2. **Given** a user has linked a Google account, **When** they sign out and later sign in with that same Google account, **Then** they are signed directly into the same app account (no error, no duplicate account).
3. **Given** a user attempts to link a Google account that is already linked to a *different* app account, **When** they complete the Google chooser, **Then** the system rejects the link attempt with a clear error and the existing linkage is unchanged.
4. **Given** a signed-in user who already has a Google account linked, **When** they view Profile, **Then** they see which Google account is linked (e.g., its email).

---

### User Story 5 - Recover from a failed or interrupted sign-up (Priority: P3)

A user who loses connectivity or closes the app mid-registration can return, retry, and complete registration without getting stuck in a broken state.

**Why this priority**: Improves robustness and reduces support burden, but the app is still usable for new users without this handling — it's a hardening pass on top of Story 1.

**Independent Test**: Can be tested by starting registration, simulating a network failure on submit, and confirming the user sees a retry-friendly error and can successfully complete registration on a subsequent attempt with the same email.

**Acceptance Scenarios**:

1. **Given** the registration form is filled in, **When** the network request fails, **Then** the system shows a retryable error message and keeps the entered email (not the password) in the form.
2. **Given** a user closes the app after submitting registration but before confirming their email, **When** they reopen the app, **Then** they land back on the sign-in screen (not signed in) and can resume by confirming their email (Scenario 3/4 of User Story 1) or requesting a new confirmation email.

### Edge Cases

- What happens when the user's device has no Google account configured, or Google Play Services is unavailable? → "Sign in with Google" button is shown but the standard Google account-chooser error is surfaced; email/password remains available.
- How does the system handle a user submitting the registration form twice in quick succession (double-tap)? → The submit control is disabled while a request is in flight (matching the existing sign-in screen's `_isSubmitting` pattern).
- What happens if a user tries to register with an email that exists but was created via Google sign-in only (no password set)? → Registration is blocked with a message directing them to use "Sign in with Google" instead.
- What happens if Google sign-in returns an email that isn't verified by Google? → Treated the same as any other new registration; Google-verified emails are trusted per Google's own verification.
- What happens if a user tries to link a Google account that is already linked to a different app account? → The link attempt is rejected with a clear error; neither account's linkage changes (see User Story 4, Scenario 3).
- What happens if Google sign-in (or Google account linking) fails after the account chooser due to a network or server error, rather than user cancellation? → A retryable error is shown (consistent with User Story 5's registration failure handling), with no partial account created and no linkage change.
- What happens if a user signs in with Google using an email that matches an *unconfirmed* existing email/password account (e.g. someone else registered that email with a password first, whether the real owner or an attacker)? → Supabase automatically removes that account's other, unconfirmed identities (including the password) and completes the link with the verified Google identity — this is the built-in defense against pre-registration account takeover (research.md §6), and applies regardless of who created the original unconfirmed row.
- What happens if a user requests a resend of the confirmation email? → A new confirmation email is sent to the same address; the system shows a confirmation that it was sent (or a retryable error if the request fails), without revealing whether the rate limit was hit (that detail is only shown as a generic retry-later message, consistent with FR-011's error handling).
- What happens if a user's email/password account was created via Google sign-in first (auto-confirmed by Google) and they never set a password? → Not applicable to the email confirmation requirement — this scenario is already covered by FR-012 (password-based registration is blocked for an existing Google-only account) before the confirmation step would ever be reached.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a registration screen reachable from the sign-in screen, accepting an email address, a password, a password confirmation, an optional display name, and an optional phone number.
- **FR-002**: The system MUST validate the email format, a minimum password length of 6 characters, and that the confirmation password matches the password field, on the client before submitting a registration request, showing inline errors for invalid input.
- **FR-019**: The system MUST accept the display name and phone number fields as optional — registration MUST succeed with either or both left blank.
- **FR-020**: The system MUST NOT verify the phone number via OTP/SMS or any other means; it is stored as plain profile information, consistent with how the display name is stored.
- **FR-003**: The system MUST reject registration attempts using an email address that already has an account, with a clear, actionable error message.
- **FR-004**: The system MUST create a new account when registration succeeds, reusing the existing `AuthRepository.signUp` capability. Per FR-015, the account is created in an unconfirmed state and the user is not signed in until they confirm their email.
- **FR-005**: The system MUST offer a "Sign in with Google" option on both the sign-in and registration screens.
- **FR-006**: The system MUST create a new account automatically the first time a user completes Google sign-in with a Google account whose email has no existing app account, using the Google account's email as the account identifier.
- **FR-007**: The system MUST sign a returning user into their existing account when they repeat Google sign-in with a Google account that is already linked to that account (via first-time Google sign-in, automatic linking per FR-008, or explicit linking per FR-016), without creating a duplicate account.
- **FR-008**: The system MUST automatically link a Google sign-in to an existing email/password account when the Google account's email matches that account's email, signing the user directly into the existing account. This is safe against pre-registration account takeover (an attacker registering someone else's email with a password first) because the platform automatically evicts every prior identity on that account — including a password the attacker set — whenever a new OAuth identity attaches to a row that is still unconfirmed; an attacker who registered someone else's email can never get that row confirmed themselves (they don't control the victim's inbox), so their account is always in the state this eviction targets, and their access is always removed the moment the real owner signs in with Google (research.md §6). This protection is unconditional and holds regardless of FR-015's email-confirmation requirement — the two are independent.
- **FR-009**: The system MUST let the user cancel the Google account chooser and return to the prior screen with no error state and no partial account created.
- **FR-010**: The system MUST disable the registration submit control while a registration request is in flight, preventing duplicate submissions.
- **FR-011**: The system MUST show a retryable error (not a dead-end) when registration fails due to a network or server error, and MUST preserve the entered email (not the password) so the user can retry without full re-entry.
- **FR-021**: On successful registration, the system MUST show a clear "check your email to confirm your account" message instead of navigating the user into the authenticated app, per FR-015.
- **FR-022**: The system MUST detect when a sign-in attempt fails specifically because the account's email is unconfirmed, and show a message distinct from a generic "wrong email/password" error, directing the user to check their email; the system MUST offer a way to resend the confirmation email from this state.
- **FR-023**: The system MUST show a retryable error (not a dead-end) when resending a confirmation email fails due to a network or server error, consistent with FR-011's pattern.
- **FR-012**: The system MUST block password-based registration for an email that already exists as a Google-only account, and direct the user to sign in with Google instead.
- **FR-013**: The registration, sign-in, and Profile/Account Google-linking screens (including all their error messages) MUST support both English and Vietnamese, consistent with the app's existing localization (`app_en.arb` / `app_vi.arb`).
- **FR-014**: The login identifier field MUST be the user's email address only; no separate username identifier is introduced. The "username" mentioned in the original request is treated as informal phrasing for "the login field."
- **FR-015**: On successful registration via email/password, the system MUST require the user to confirm their email address (via the confirmation link Supabase sends) before they can sign in. Reversed from the original "sign in immediately" decision per the 2026-08-04 Clarifications entry — this is a deliberate UX choice, not a security requirement: FR-008's safety against pre-registration account takeover comes from Supabase's `RemoveUnconfirmedIdentities` mechanism (research.md §6), which is unconditional and does not depend on whether this project requires email confirmation.
- **FR-016**: The system MUST let a signed-in user explicitly link a Google account (including one whose email differs from their app account's email) from the Profile/Account screen, after which future Google sign-ins with that Google account sign into this same app account.
- **FR-017**: The system MUST reject an attempt to link a Google account that is already linked to a different app account, leaving the existing linkage unchanged.
- **FR-018**: The system MUST display, on the Profile/Account screen, whether a Google account is linked and which Google account it is.

### Key Entities

- **Account**: A user's identity in the system — email address, optional linked Google identity, password (if registered via email/password), optional display name, optional phone number, creation timestamp. Already exists via Supabase Auth; this feature extends how it can be created and authenticated against, and adds the optional display name/phone number profile fields, not the underlying storage mechanism.
- **Google Identity Link**: An association between one Account and one Google account, created by first-time Google sign-in (new account), by automatic linking when the Google email matches an existing email/password account (FR-008, safe per research.md §6's unconfirmed-identity eviction mechanism), or by the user explicitly linking Google from Profile (FR-016, for a non-matching email). At most one Google identity per Account, and at most one Account per Google identity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can go from the sign-in screen to a submitted registration (account created, confirmation email sent) in under 60 seconds using email/password — this excludes the time the user takes to open their email and click the confirmation link, which is outside the app's control.
- **SC-002**: A new user can go from the sign-in screen to a fully authenticated account in under 15 seconds using Google sign-in (excluding the time spent in the OS-level Google account chooser).
- **SC-003**: 100% of duplicate-email registration attempts are rejected with an error that clearly explains why, with zero duplicate accounts created.
- **SC-004**: 100% of repeat Google sign-ins with an already-linked Google account (whether linked automatically per FR-008 or explicitly per FR-016) resolve to the same existing account — zero duplicate accounts created from Google sign-in.
- **SC-005**: Registration and Google sign-in are fully usable in both English and Vietnamese with no untranslated strings visible.
- **SC-006**: After linking a Google account from Profile, a user can sign in with that Google account and reach their existing data in under 15 seconds, with zero failed link-then-sign-in attempts under normal conditions.

## Assumptions

- Password strength rule follows Supabase Auth's default minimum (at least 6 characters); no additional complexity rules are required unless specified later.
- Google Sign-In is implemented as a native Google OAuth flow (Android account chooser / iOS equivalent) integrated with Supabase Auth's OAuth/identity-linking support, consistent with the existing `supabase_flutter` dependency already in `pubspec.yaml`.
- Password reset/"forgot password" is out of scope for this feature — it is a separate, pre-existing gap not introduced by this change.
- Email confirmation is required for the email/password path (FR-015, reversed 2026-08-04) — Supabase's "Enable email confirmations" project setting must be turned on in the Dashboard for this to take effect server-side; the client-side behavior (showing "check your email", handling `email_not_confirmed` on sign-in, offering resend) is built regardless, but only exercised end-to-end once that Dashboard setting is on. This requirement is independent of FR-008's safety: the platform's unconfirmed-identity eviction mechanism (research.md §6) protects against pre-registration takeover whether or not this project requires confirmation, since an attacker registering someone else's email can never confirm it themselves either way. Google sign-in emails are trusted as already verified by Google and are unaffected by this change (Google-created accounts are auto-confirmed, per Supabase's own behavior).
- The confirmation email's content, subject line, and sender address are controlled by Supabase's project-level email template settings (Dashboard → Authentication → Email Templates) — not something this feature's client code renders or controls.
- The existing `AuthRepository` (`lib/core/auth/auth_repository.dart`) is extended rather than replaced; this feature does not change how already-authenticated users are treated elsewhere in the app.
- Only one Google account can be linked per app account; unlinking a Google account is out of scope for this feature.
- Display name and phone number are stored as ordinary profile metadata (no format/region validation beyond basic non-empty-if-provided); a dedicated phone-number-format validator is out of scope unless a real need is later identified.
- Google sign-in (User Story 2) does not collect a phone number confirmation step; a Google-created account's display name defaults to the name Google provides, and phone number stays blank until the user fills it in from Profile.
