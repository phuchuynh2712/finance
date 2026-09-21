# Contract: `core/error/error_mapper.dart`

This is the shared interface every one of the 7 call sites (and any future feature) consumes. Since this is an internal Dart function contract, not an external API, the "contract" is the function signature plus its documented behavior per input category.

## Signature

```dart
String mapErrorToMessage(Object error, AppLocalizations l10n);
```

- **Input `error`**: whatever was caught in the call site's `catch (e)` — untyped `Object`, since Dart's `catch` clause can surface anything.
- **Input `l10n`**: the caller's already-resolved `AppLocalizations` instance (from `AppLocalizations.of(context)` for screens with `BuildContext`, or threaded through from the widget-side `ref.listen` for the 4 `StateNotifier` call sites — see research.md Decision 1).
- **Output**: a non-null, non-empty, localized `String` — always. There is no error/exception path *out of* the mapper itself; every input, recognized or not, produces some string (FR-009's fallback guarantees this).

## Behavioral contract per category (research.md Decision 2/3 for exact matching rules)

| Given `error` is... | Mapper returns... |
|---|---|
| `AuthApiException` with `code == 'invalid_credentials'` | the FR-007 "wrong email/password" friendly message |
| `AuthApiException` with `code == ErrorCode.emailExists.code` or `ErrorCode.userAlreadyExists.code` | the same text as the existing `signUpDuplicateEmailError` string (FR-013 — must not regress) |
| `AuthApiException` with `code == ErrorCode.weakPassword.code` | the FR-007 "password too weak" friendly message |
| `AuthWeakPasswordException` (any instance — matched by its OWN independent `is` check, never reached via the `AuthApiException` branch above, since `AuthWeakPasswordException extends AuthException` directly, not `AuthApiException`) | the same FR-007 "password too weak" friendly message |
| `AuthApiException` with `code == ErrorCode.overEmailSendRateLimit.code` | the FR-007 "too many requests" friendly message |
| `SocketException`, `TimeoutException`, or `AuthRetryableFetchException` | the FR-008 "couldn't reach the server" friendly message |
| anything else (`PostgrestException`, any other exception type, `null`-adjacent edge cases) | the FR-009 generic fallback friendly message |

## Call-site usage shape (unchanged call convention — only the message source changes)

**Pattern A — screens with `BuildContext` at the catch site** (`sign_in_screen.dart`, `sign_up_screen.dart`'s fallback branch, `reset_password_screen.dart`):

```dart
} catch (e) {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context);
  setState(() => _errorMessage = mapErrorToMessage(e, l10n));
}
```

**Pattern B — `StateNotifier`s with no `BuildContext`, localized widget-side** (`IncomeFormController`/`ExpenseFormController`/`ScanFormController`/`ExpenseControlFormController` + their screens):

Controller side (stores the raw error, unchanged from today):
```dart
} catch (e) {
  state = state.copyWith(saveError: ...WriteFailed, writeErrorDetail: e.toString(), isSubmitting: false);
}
```

Widget side (`ref.listen`, changes from `l10n.xxxErrorWriteFailedPrefix(raw)` to the mapper):
```dart
ref.listen(xFormControllerProvider, (previous, next) {
  if (next.saveError == XSaveError.writeFailed && previous?.saveError != XSaveError.writeFailed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mapErrorToMessage(next.writeErrorDetailAsError, AppLocalizations.of(context)))),
    );
  }
});
```

Note: Pattern B implies the state's `writeErrorDetail`/`errorMessage` field needs to carry the original `Object` (or be re-derivable to one) for the mapper to classify it — whether that means keeping the raw `Object` alongside/instead of its `.toString()`, or having the controller call the mapper itself with an `l10n` passed into `save()`, is an implementation choice for tasks.md; both satisfy this contract identically from the caller's perspective (a friendly string ends up on screen).

## Non-goals of this contract

- Does not define a logging contract — the mapper does not log; Security principle (no raw financial data/tokens in logs) is unaffected because this function never touches financial values, only exception objects.
- Does not define retry/recovery behavior — purely presentational; whether a screen offers a "retry" action after showing the message is unchanged, existing per-screen behavior.
