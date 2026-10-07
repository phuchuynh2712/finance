# Feature Specification: App Lock to the Banking Security Standard (Inactivity Lock and PIN Fallback)

**Feature Branch**: `20261007-170025-pin-lock-fallback`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "khóa PIN cho nền tảng không có sinh trắc học. Bạn định làm thế nào? Gửi opt vào email để xác nhận hay là thế nào?" (a PIN lock for platforms without biometrics; how do you plan to do it, an e-mail OTP or something else?). Direction given by the owner during clarification: check how Vietnamese banking apps secure the web, and "cần làm đúng chuẩn theo luật" (do it to the standard).

## Background

Observed on `master` (`3f0589b`) on 2026-10-07.

**How the app locks today.** When a signed-in person opens the app (a stored session exists), or returns to it after it was in the background for more than 5 minutes, the app shows the sign-in screen as a *lock screen* and hides all financial data behind it. There are two ways through:

- **Biometric** (fingerprint or face): only when the device has biometric hardware with something enrolled and the person switched it on. It unlocks the stored session with no network call.
- **The account password**: always available. Typing it is a real sign-in, so it needs the network. After unlocking, the person lands on Tổng quan.

**Gaps found**

1. **Nothing locks an app that is simply left open.** The only re-lock is "more than 5 minutes in the background", and in a browser that rule never fires: it relies on a "the app went to the background" signal that browsers do not send for a hidden tab (checked against the UI framework's own documentation). So on the web the app locks at page load and never again; a tab left open stays open for ever. On a phone, an app left in the foreground and unattended never locks either.
2. **A device without biometrics can only unlock with the full account password**, typed at every launch and every return, with the network.
3. The project's constitution (Security, v1.5.0) asks for an app-level lock and says the PIN path must be offered where biometrics are unavailable "(e.g. Web)". The web-enablement feature left this as deferred work.

**The standard used here.** The State Bank of Vietnam's Circular 50/2024/TT-NHNN (in force from 2025-01-01) sets the security requirements for online banking services, and it is what the Vietnamese banking apps follow. Its Articles 1–2 limit it to credit institutions, foreign bank branches, payment intermediaries and credit-information companies, so it **does not bind this app as a matter of law**; the owner asked to follow it as the reference standard. (Whether other law applies to this app, for example the personal-data protection rules, is a legal question outside this spec; it should be confirmed with whoever advises the project before a public release.) What the circular requires of an online-banking application, checked against its text:

| Control | What the circular says | Where the app stands today | This feature |
|---------|------------------------|----------------------------|--------------|
| Session control (Art. 7, cl. 6c) | the system automatically ends a session after the user does nothing for a period the institution sets (no number is fixed) | only "5 minutes in the background", and not in browsers | lock after 5 minutes without interaction, on every platform |
| Mask secrets (Art. 7, cl. 6d) | passwords and PINs used to sign in are never shown in clear | password field is masked | PIN shown as dots |
| No automatic sign-in (Art. 7, cl. 6đ) | the application prevents automatic sign-in | a stored session is restored, then the lock demands the password or biometric | unchanged; the lock stays |
| Attempt limit (Art. 7, cl. 6e; Art. 11) | a PIN or password is invalidated after consecutive wrong entries, at most 10 | none for the lock screen's password beyond the server's own | PIN invalidated after 5 |
| PIN strength (Art. 11) | at least 6 characters; valid for at most 12 months | no PIN today | 6 digits; expires after 12 months |
| Password strength (Art. 11) | at least 8 characters with digits, upper and lower case; valid for at most 12 months | 8 characters minimum, no composition rule, no expiry | **not in this feature** (see Out of Scope) |
| Other banking controls (first-login and new-device notices, transaction logs, biometric accuracy tests, OTP lifetime) | institution-specific | not applicable to a tracker that moves no money | not in this feature |

**What a PIN is, and is not, here.** Like biometric sign-in, a PIN is a *local convenience layer on a session the device already holds*, not a new identity and not a replacement for the account password. It guards against someone using an app already signed in on a device they are holding; it cannot protect data from a person who can read the device's stored files, which is also true of the stored session today (see Assumptions). A one-time code sent by e-mail is not part of it: setting a PIN needs the account password, and the account password is the way back if the PIN is forgotten.

**Where the PIN is offered.** The banking apps do not use a PIN to open their web version; they end the session after inactivity and ask for the credentials again, and they use a PIN on the phone. The same split is used here: the PIN is for phones and tablets that cannot use biometric sign-in, and the web is protected by the inactivity lock plus the password. The constitution used to say the PIN must be offered "e.g. Web"; on 2026-10-07 the owner amended it (version 1.8.0) to this split, so this feature implements the constitution as it now reads.

## Clarifications

### Session 2026-10-07

- Q: How is a forgotten PIN recovered: the account password, or a one-time code sent to the account's e-mail address? → A: The account password. The lock screen always offers it; a password sign-in after "forgot PIN" removes the old PIN and offers a new one. No e-mail code.
- Q: If biometrics become available after a PIN was set, may both be on at once? → A: Yes. The PIN keeps working, biometric sign-in can be switched on from Bảo mật, and when both are on the lock screen shows the fingerprint button next to the PIN entry.
- Q: Should the web also get the "hidden tab for more than 5 minutes" re-lock (and a PIN)? → A: Owner: "đúng chuẩn theo luật". The standard asks for automatic session end after inactivity and does not ask for a PIN on the web, so the web gets the inactivity lock (which also covers a hidden tab) and keeps the password as its only way back in; the PIN is for phones and tablets without biometric sign-in.
- Q: Should the circular's password rules (digits, upper and lower case; 12-month validity) be done now? → A: Not now. Owner: the first release is mostly for local use, so the password rules wait until server-side accounts become the main way the app is used.
- Q: On the web, does interaction in one browser tab count as activity for the other open tabs? → A: Yes, one shared timer for the whole app: the app locks only when no open window has seen interaction for 5 minutes, and locking and unlocking apply to the app as a whole (unlocking in one window unlocks the others). Matches a banking site's single shared session.
- Q: Does setting the first PIN need the account password? → A: Yes (decided from the standard's rule that credentials are issued only after customer verification, and to stop a person who briefly holds an unlocked app from setting a PIN they alone know). It needs the network once; unlocking with the PIN afterwards does not.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The app locks itself when left alone (Priority: P1) 🎯 MVP

A person stops using the app: they walk away from an open browser tab, switch to another tab for a while, or put the phone down with the app still on screen. After 5 minutes without any interaction the app hides the financial data and shows the lock screen, the same one that appears when the app is reopened. It works the same on the web and on phones.

**Why this priority**: This is the control the standard names first (the system ends a session after inactivity) and the one that is missing everywhere today; on the web it is the only protection against someone sitting down at an open tab, and it does not need a PIN.

**Independent Test**: Open the app, do nothing for 5 minutes (once with the tab or app in view, once with the tab hidden) and confirm the lock screen replaces the content; then interact continuously for more than 5 minutes and confirm it never locks.

**Acceptance Scenarios**:

1. **Given** a signed-in person using the app, **When** 5 minutes pass with no tap, click, key press or scroll, **Then** the lock screen is shown and no financial data is visible.
2. **Given** the person interacts at least once every few minutes, **Then** the app does not lock for as long as they keep interacting.
3. **Given** a browser tab that is hidden or in another window, **When** 5 minutes pass without interaction, **Then** the app is locked when the person comes back to the tab.
4. **Given** a phone with the app in the background, **When** the person returns after more than 5 minutes, **Then** the app is locked (today's rule is kept).
5. **Given** the lock screen on the web or on a device without a PIN or biometric, **Then** the account password is the way back in, as today.
6. **Given** a sync or other background work is running when the lock appears, **Then** it carries on; the lock hides data, it does not stop the app.
7. **Given** the web app open in two browser tabs, **When** the person works only in one for more than 5 minutes, **Then** neither tab locks; **When** neither sees interaction for 5 minutes, **Then** both show the lock, and unlocking in one unlocks the other.

---

### User Story 2 - Unlock a phone without biometrics using a PIN (Priority: P1)

On a phone or tablet that cannot use biometric sign-in, a person who has set a PIN sees a PIN entry on the lock screen. They type six digits, the app opens, and nothing was sent over the network. A clearly visible "use password instead" takes them to the usual password sign-in.

**Why this priority**: It is the point of the original request and what the constitution asks for: a lock quick enough to leave switched on where biometrics are not available.

**Independent Test**: With a PIN set, close and reopen the app (airplane mode on) and confirm the PIN entry appears, the correct PIN opens the app, and "use password instead" still works.

**Acceptance Scenarios**:

1. **Given** a signed-in person with a PIN set, **When** the app locks (on opening, after 5 minutes away, or after 5 minutes idle), **Then** a PIN entry is shown and no financial data is visible behind it.
2. **Given** the PIN entry, **When** the correct six digits are entered, **Then** the app opens (on Tổng quan, as after any unlock today), with no network needed.
3. **Given** the PIN entry, **When** "use password instead" is chosen, **Then** the usual password sign-in is shown and works as it does today.
4. **Given** the PIN is being typed, **Then** the digits are shown only as dots.
5. **Given** the web, or a device where biometric sign-in *is* available and no PIN was set earlier, **Then** no PIN entry, PIN row or PIN offer appears and existing behavior is unchanged.
6. **Given** a PIN set on a device that later gains biometric sign-in, **Then** the PIN entry is still shown and the PIN row is still in Bảo mật (FR-019).

---

### User Story 3 - Set up a PIN (Priority: P1)

A signed-in person on a phone or tablet without biometric sign-in opens Hồ sơ → Bảo mật and finds a "Khoá bằng mã PIN" row, off. They turn it on, confirm with their account password, type a six-digit PIN twice, and the PIN lock is active from the next time the app locks.

**Why this priority**: Without a way to set a PIN there is nothing to unlock with.

**Independent Test**: On such a device open Bảo mật, turn the row on, give the password, enter and confirm a valid PIN, then lock the app (idle or reopen) and confirm the PIN is asked for.

**Acceptance Scenarios**:

1. **Given** a signed-in person on a device where biometric sign-in is unavailable and the app is not running in a browser, **When** they open Bảo mật, **Then** a PIN row is shown, off by default.
2. **Given** the row, **When** they turn it on, **Then** they are first asked for their account password; a wrong password stops the set-up with a clear message and nothing is saved.
3. **Given** a correct password, **Then** they are asked to enter a new six-digit PIN and to enter it again.
4. **Given** the second entry differs from the first, **Then** a message says they did not match, the second entry starts over, and nothing is saved.
5. **Given** an easy PIN (all the same digit, or a straight run such as 123456 or 654321), **Then** it is refused with a short explanation.
6. **Given** a valid, confirmed PIN, **Then** the row shows as on, a short confirmation is shown, and the PIN is asked for from the next lock.
7. **Given** the PIN is typed, **Then** the digits are dots on screen and in what a screen reader announces.

---

### User Story 4 - Wrong, forgotten and expired PINs (Priority: P1)

A person types the wrong PIN: the app says so, shows how many tries remain, and clears the entry. After five wrong tries in a row the PIN is invalidated and only the password is offered. A person who forgot the PIN, or whose PIN is older than 365 days (12 months), signs in with the password and is offered a new PIN.

**Why this priority**: A six-digit PIN can be guessed without a limit; the limit, the expiry and the way out are what make the lock trustworthy and what the standard asks for.

**Independent Test**: At the lock screen enter wrong PINs five times and confirm the count, then that only the password is offered and that signing in with it leaves no PIN set.

**Acceptance Scenarios**:

1. **Given** the PIN entry, **When** a wrong PIN is entered, **Then** a message says it was wrong and how many tries remain, and the entry is cleared.
2. **Given** four wrong tries in a row, **When** a fifth wrong PIN is entered, **Then** the PIN is invalidated for this account on this device, a message explains why, and only the password sign-in is offered.
3. **Given** two wrong tries and then the app is closed and reopened, **Then** the count continues; a correct PIN resets it to zero.
4. **Given** the lock screen, **When** "forgot PIN" is chosen, **Then** the password sign-in is shown; after a successful sign-in the old PIN is removed and a new one is offered, not forced.
5. **Given** a PIN set more than 365 days (12 months) ago, **When** the app next locks, **Then** the PIN is treated as expired: the password sign-in is shown, the old PIN is removed, and a new PIN is offered.

---

### User Story 5 - Change or turn off my PIN (Priority: P2)

From Bảo mật a person can change their PIN (current PIN, then a new one twice) or turn it off (current PIN to confirm). Signing out also removes the PIN from the device.

**Why this priority**: People must be able to undo and change the lock, but the lock works without it.

**Independent Test**: With a PIN set, change it, lock the app, and confirm only the new PIN works; then turn it off and confirm the app locks with the password only.

**Acceptance Scenarios**:

1. **Given** a PIN is set and the current PIN is entered correctly, **Then** a new PIN can be set (twice, same rules) and only the new one works; its 12 months start again.
2. **Given** a wrong current PIN while changing or turning off, **Then** it counts toward the same five-try limit as at the lock screen.
3. **Given** the PIN row is turned off with the current PIN, **Then** the PIN is removed and the app locks with the password only.
4. **Given** a PIN is set, **When** the person signs out, **Then** the PIN is removed from the device and the next account on it does not inherit it.

---

### User Story 6 - Being offered a PIN after signing in (Priority: P2)

The first time a person signs in or signs up on a phone or tablet without biometric sign-in and with no PIN, a one-time offer asks whether they want a PIN lock. They can accept (Story 3) or decline, and it does not return by itself for that account on that device.

**Why this priority**: The constitution says the PIN path must be *offered*; the Bảo mật row makes it available and this makes sure people learn it exists. It mirrors the existing one-time biometric offer.

**Independent Test**: Sign in on such a device with an account that has no PIN, confirm the offer appears once, decline it, sign out and in again and confirm it does not reappear.

**Acceptance Scenarios**:

1. **Given** the conditions above, **When** the sign-in or sign-up completes, **Then** a one-time offer is shown; accepting starts Story 3.
2. **Given** it was declined once, **Then** it is not shown again for that account on that device; the Bảo mật row stays.
3. **Given** a device with available biometrics, or the web, **Then** the PIN offer is not shown.
4. **Given** the offer is on screen, **Then** it never blocks reaching the app.

---

### Edge Cases

- **Idle timing and what counts as interaction**: any tap, click, key press or scroll in the app resets the 5 minutes; time spent with the tab hidden, the window minimized or the phone in the background counts as idle. Changing the device clock never gives back tries (the wrong-tries count counts attempts, not time); the 5-minute rule keeps measuring time as today.
- **Locked in the middle of something**: a lock hides the data and takes the person to the lock screen; as with today's lock, what was being typed and not saved is not kept, and after unlocking they land on Tổng quan.
- **Reload or closing mid-set-up**: nothing is saved until the confirming entry matches; a half-finished set-up leaves no PIN behind.
- **Two tabs or windows**: they share one inactivity timer and one lock state (FR-001a): working in one tab keeps the hidden one from locking, and when the app does lock every tab shows the lock. A tab that merely loads (and so starts locked) does not lock a tab that is in use.
- **The session itself is no longer valid** (expired or revoked elsewhere): a PIN cannot unlock it; the person goes through the password sign-in, and that sign-in, made while signed out, removes any PIN left over from the earlier session.
- **Biometrics become available later**: the PIN keeps working; both may be on and the lock screen then shows the fingerprint button next to the PIN entry.
- **A different account signs in on the same device**: it starts with no PIN.
- **No network**: unlocking with the PIN and changing it work offline; setting the first PIN and every password path need the network.
- **Very small windows and large text sizes**: the lock screen's PIN entry and the set-up flow stay fully usable at 320 dp and at 130 % text, and sit in the same centered column as the rest of the app on a wide window.
- **Digits only**: the entry accepts only digits, only six of them, and never submits twice.

## Requirements *(mandatory)*

### Functional Requirements

**Inactivity lock (all platforms, the web included)**

- **FR-001**: The app MUST lock after 5 minutes without any interaction (tap, click, key press or scroll), on every platform and in every state where it is open, including a hidden or unfocused browser tab and a phone app in the background, and MUST show the same lock screen as when it is reopened. Where timers cannot run (a hidden tab, an app in the background) the lock MUST be in place by the moment the person can next see the app.
- **FR-001a**: Several open windows of the app on the web (browser tabs) MUST share one inactivity timer: interaction in any of them counts for all, so a hidden tab does not lock while the person is working in another; the app locks and unlocks as a whole, so when it locks every window shows the lock and unlocking in one window unlocks the others.
- **FR-002**: While locked, the app MUST hide all financial data and MUST keep it hidden until the account password is accepted or, where available, the PIN or biometric check passes. There MUST be no way around the lock: a direct address, the browser's Back button, a page reload, or a second tab all arrive at the lock.
- **FR-003**: The existing rules MUST keep working: the lock when the app is opened with a stored session, and the lock after returning from the background after more than 5 minutes.
- **FR-004**: The 5-minute period MUST be a single named setting of the product, not scattered through screens, so that it can be changed in one place.
- **FR-005**: Locking MUST NOT stop background work such as sync.

**PIN (phones and tablets that cannot use biometric sign-in)**

- **FR-006**: The PIN MUST be offered only where biometric sign-in cannot be used (no biometric hardware, or nothing enrolled) and the app is not running in a browser. The decision MUST come from what the device can actually do, not from the platform's name. On the web, and on a device where biometric sign-in is available and no PIN was set earlier, the PIN row, the PIN entry and the PIN offer MUST NOT appear, and existing behavior MUST be unchanged. A PIN that already exists keeps working and keeps its row in Bảo mật wherever it was set up (FR-019).
- **FR-007**: When a PIN is set, the lock screen MUST show a PIN entry first, MUST always offer the account password as an alternative with unchanged behavior, and MUST offer "forgot PIN".
- **FR-008**: A correct PIN MUST unlock the app without any network request.
- **FR-009**: Setting the first PIN MUST first require the account password to be confirmed; a wrong password MUST stop the set-up and save nothing.
- **FR-010**: A PIN MUST be exactly six digits, entered twice to be accepted; a mismatch MUST be explained and MUST NOT save anything. PINs that are all one digit, or a straight ascending or descending run, MUST be refused with a short explanation.
- **FR-011**: PIN digits MUST be shown only as dots (on screen and to assistive technology), and the PIN MUST never appear in clear in the interface, in logs, in analytics or in any request to a server.
- **FR-012**: The PIN MUST be kept on the device only, in a form from which it cannot be read back, specific to the signed-in account and the device, and never synced.
- **FR-013**: A wrong PIN MUST be reported with the number of tries left and the entry cleared; five wrong PINs in a row MUST invalidate the PIN for that account on that device and leave only the password sign-in. The count MUST survive closing the app, MUST be shared by every place the PIN is asked for (lock screen, change, turn off), and MUST reset to zero after a correct PIN.
- **FR-014**: A PIN MUST expire within 12 months of being set or last changed (the product uses 365 days); at the next lock the app MUST treat it as forgotten (FR-016).
- **FR-015**: Changing the PIN and turning it off MUST each require the current PIN.
- **FR-016**: A forgotten, expired or invalidated PIN MUST be recoverable with the account password alone (no e-mail code). A password sign-in that follows "forgot PIN", expiry or the five-tries rule MUST remove the old PIN and offer, without forcing, to set a new one; this offer is made even on a device that has since gained biometric sign-in, because the account already used a PIN there (the one exception to FR-006's "no PIN offer where biometrics are available").
- **FR-017**: Signing out MUST remove the PIN from the device. So MUST a password sign-in made while signed out (for example after the session expired or was revoked elsewhere) for any PIN left over from an earlier session of that account.
- **FR-018**: On a device with no biometric sign-in and no PIN, a one-time offer to set a PIN MUST appear after a sign-in or sign-up, MUST NOT reappear for that account on that device once dismissed, and MUST NOT block anything.
- **FR-019**: When biometrics become available after a PIN was set, the PIN MUST keep working and biometric sign-in MAY be switched on as well; when both are on, the lock screen MUST show the fingerprint button next to the PIN entry.

**All new screens**

- **FR-020**: Every new screen (PIN entry on the lock screen, set-up, change, turn off, the offer) MUST work by keyboard and by touch or pointer, MUST have touch targets of at least 48 dp, MUST be usable by a screen reader (the dots announce how many digits are entered, never the digits), and MUST adapt to compact and wide windows and to light and dark themes.
- **FR-021**: All new text MUST exist in both Vietnamese and English.

### Key Entities

- **Inactivity timer**: the time since the last interaction in the app; reset by interaction in any open window of the app; when it reaches the single named period (5 minutes) the lock engages. It exists on every platform.
- **PIN lock setting**: whether this account has a PIN on this device, when it was set (for the 12-month expiry); kept only on the device and removed with the account's sign-out. Holds enough to check a typed PIN and nothing that reveals it.
- **Wrong-tries count**: wrong PINs in a row for this account on this device; persists across restarts; reset by a correct PIN; reaching five invalidates the PIN lock setting.
- **Lock state**: the existing locked or unlocked state; this feature adds a new way to enter it (inactivity) and a new way to leave it (PIN).
- **PIN offer record**: whether the one-time offer was already shown to this account on this device.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the web and on phones, in 100 % of tests with no interaction, financial data is hidden and authentication is required within 5 minutes plus 10 seconds of the last interaction, measured at the moment the person can see the screen (for a hidden tab or an app in the background, the moment it is shown again after at least that long); and in 100 % of tests with an interaction at least every 4 minutes the app does not lock, including with two browser tabs open and the interaction only in one of them.
- **SC-002**: With a PIN set, getting past the lock takes under 5 seconds (six digits) and works with no network, compared with typing the full password today.
- **SC-003**: A person can set up a PIN in under 60 seconds including confirming the password, in no more than four steps.
- **SC-004**: In every test of five wrong PINs in a row (including ones split across an app restart) the PIN is invalidated and only the password is offered: 0 cases of a sixth try. A PIN older than 365 days is never accepted.
- **SC-005**: On every platform, after launch, after returning past the 5 minutes, or after idling 5 minutes, there are 0 ways to see financial data without the account password or, where a PIN or biometric sign-in is in use, that check (on the web: by reload, Back button, a direct address to each top-level and sub-screen, and a second tab; on a phone: by relaunching and by switching apps).
- **SC-006**: 0 occurrences of the PIN (or its digits) in the screen text exposed to assistive technology, in the log output of a full set-up and unlock run, or in any request sent to a server.
- **SC-007**: Every new screen passes the layout check at 320, 412, 600, 840, 1200 and 2560 dp wide, at 130 % text, in light and dark, with no overflow or clipped control, and is completable by keyboard alone where a keyboard exists.
- **SC-008**: On devices with available biometrics (with no PIN set earlier) and on the web, 0 changes other than the inactivity lock: the same screens, offers and unlock behavior as before.

## Assumptions

- The inactivity period is 5 minutes. The circular leaves the number to each institution; 5 minutes matches the app's existing background rule. It is one named setting (FR-004).
- "Interaction" means taps, clicks, key presses and scrolls inside the app (a drag counts as a scroll); rolling the mouse pointer over the window (hover) alone, and media or sync activity, do not count.
- The lock after inactivity is a *lock that demands authentication again*, not a sign-out: signing out would discard the stored session and could drop changes not yet synced. For the person it ends the session in the sense of the standard (nothing can be seen or done without proving who they are again).
- The PIN is exactly six digits: the circular's minimum is six characters, and six digits with a five-try limit is out of reach of guessing at the lock screen.
- A PIN is a convenience lock on a stored session, not a security boundary against someone who can read the device's or browser's stored data. The stored session already carries the risk the constitution accepted (v1.6.0, conditional on HSTS at the eventual web host); this feature neither worsens nor removes it. Making the PIN resist that kind of access needs hardware-backed or server-side checks, which are out of scope.
- **Constitution alignment**: the Security section (version 1.8.0, amended 2026-10-07 for this feature) now requires an inactivity lock on every platform, a PIN on phones and tablets without usable biometrics, and no PIN on the web (inactivity lock plus the account password). This feature implements exactly that. Its parameters here (6 digits, 5 wrong tries, 12-month expiry, 5-minute inactivity) are inside the constitution's limits.
- The one-time offer follows the biometric offer's model: shown once per account per device, never blocking.
- The cold-start lock race recorded in the earlier Security feature is a known open item; this feature must not depend on it and does not fix it.
- On the web the only way back through the lock is the account password, which needs the network. A web tab that locks while offline stays locked until the network returns, exactly as reopening the web app offline does today; making the web unlock offline would need a PIN on the web, which this feature deliberately does not offer.
- Where the person lands after unlocking (Tổng quan) and the loss of unsaved typing at a lock are today's behavior and are not changed.
- Existing screens keep their layout; only the lock screen, Bảo mật and the one-time offer gain content.

## Out of Scope

- A PIN on the web.
- An e-mail or SMS one-time code for any purpose.
- Password rules beyond today's: composition (digits, upper and lower case) and 12-month validity from the circular's Article 11. Deferred by the owner (2026-10-07): the first release is mostly for local use. They would be separate changes to sign-up, reset and change-password.
- The circular's other controls (first-login and new-device notices, device and transaction logs, biometric accuracy requirements, OTP lifetime), which belong to institutions that move money.
- A configurable lock delay in the interface, a "lock now" button, and per-screen timeouts.
- A PIN that unlocks on another device, a PIN stored on a server, hardware-backed or server-verified PINs, and defense against someone who can read the device's stored data.
- Multi-factor authentication, session lists and the other items already out of scope in the Security feature.
- Fixing the cold-start lock race.
- Windows, macOS and Linux desktop apps.
