# Contract: PIN Lock Repository

**Stories**: US2–US6 | **Requirements**: FR-006…FR-019 | **Code**: `lib/core/auth/pin_lock_repository.dart`, `pin_rules.dart`, `pin_hasher.dart`

## 1. Interface

```text
abstract interface class PinLockRepository
  Future<PinStatus> status()                          // none | active | expired  (for the signed-in account)
  Future<int> triesLeft()                             // 5 − stored failures (5 when none stored)
  Future<void> set(String pin)                        // validates (pin_rules), writes a new record, fails = 0
  Future<PinCheckResult> verify(String pin)           // §2
  Future<void> clear()                                // deletes record and count (offer marker kept); called on sign-out, on a password
                                                      // sign-in made while signed out, and after forgot / expired / invalidated
  Future<bool> shouldOfferPin()                       // marker absent
  Future<void> markOfferShown()
```

`PinStatus { none, active, expired }`.
`PinCheckResult` is a sealed class: `PinCheckSuccess`, `PinCheckWrong(triesLeft)`, `PinCheckInvalidated` (the fifth wrong try; record
already deleted), `PinCheckUnavailable` (no active PIN: none, expired, or no signed-in account). The interface is
`PinLockRepository`; the shipped implementation is `SecurePinLockRepository(storage:, userId:, now:)`.

All methods resolve the account from the signed-in user, exactly like `isBiometricLoginEnabled`; with no signed-in user
`status()` is `none` and writes are no-ops.

## 2. `verify(pin)` (the only place a PIN is compared)

1. If `status() != active` → `unavailable`.
2. Read `fails`; if `fails >= 5` → delete the record and the count → `invalidated`.
3. Write `fails + 1`.
4. Hash `pin` with the record's salt and iteration count and compare to the stored hash in **constant time**.
5. Equal → write `fails = 0` (delete the key) → `success`. Not equal → if the stored `fails` is now 5, delete the record
   and the count → `invalidated`; else → `wrong(5 − fails)`.

Step 3 happens before step 4, so ending the process during the comparison still counts as a try.

## 3. `pin_rules` (pure functions)

```text
bool isWellFormed(String)         // exactly 6 characters, all 0-9
bool isEasy(String)               // all digits equal, or a straight +1 / −1 run
PinFormatError? validate(String)  // notSixDigits | easy | null
bool isExpired(DateTime setAt, DateTime now)   // now >= setAt + 365 days
```

## 4. `pin_hasher`

`derivePinHash(pin, salt, {iterations = 10000}) → 32 bytes` = PBKDF2-HMAC-SHA256 over the PIN's bytes (RFC 8018, through the
generic `pbkdf2HmacSha256`), built on `package:crypto`'s `Hmac`; `randomSalt()` = 16 bytes from `Random.secure()`;
`constantTimeEquals(a, b)` compares without depending on where the first difference is. Verified against published PBKDF2-HMAC-SHA256
known-answer vectors.

## 5. Guarantees (each has a test)

- The PIN, its digits or a prefix never appear in any storage value, log line, exception message or `toString`.
- A tampered or unparsable record reads as `none`.
- `set` replaces the whole record and the count (no leftover failures).
- `clear` on sign-out leaves `PIN_OFFER_SHOWN_<userId>`.
- Two accounts on one device never see each other's PIN, count or marker.
- The repository never makes a network call.

## 6. Providers (`core/auth/auth_state_provider.dart`)

`pinLockRepositoryProvider`; `pinInUseProvider` (`!kIsWeb` and `status != none`); `pinAvailableProvider` (`FutureProvider.autoDispose<bool>`, so it is read again whenever needed, because enrolling a fingerprint changes the answer: `!kIsWeb` and the biometric
`availability()` is `noHardware` or `notEnrolled`); `pinStatusProvider` (re-read after set, clear, verify).
