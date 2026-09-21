# Data Model: App Rename and Centralized Error Mapping

This feature introduces no persisted data (no Drift table, no Supabase table, no schema migration). The one conceptual entity from spec.md's Key Entities section is computed on demand and never stored.

## Error Category (internal classification, not a persisted enum)

An internal `enum` used only inside `core/error/error_mapper.dart` to select which message to produce. Not exposed outside the mapper function's own implementation — callers only ever see the resulting `String` message.

| Category | Recognized when | Source FR |
|---|---|---|
| `invalidCredentials` | `error is AuthApiException && error.code == 'invalid_credentials'` | FR-007 |
| `emailExists` | `error is AuthApiException && (error.code == ErrorCode.emailExists.code \|\| error.code == ErrorCode.userAlreadyExists.code)` | FR-007, FR-013 |
| `weakPassword` | `error is AuthApiException && error.code == ErrorCode.weakPassword.code` (covers both a plain `AuthApiException` and the `AuthWeakPasswordException` subtype, which also carries this code) | FR-007 |
| `rateLimited` | `error is AuthApiException && error.code == ErrorCode.overEmailSendRateLimit.code` | FR-007 |
| `networkFailure` | `error is SocketException \|\| error is TimeoutException \|\| error is AuthRetryableFetchException` | FR-008 |
| `generic` | anything not matched above (`PostgrestException`, any other `AuthException` subtype, any unrelated Dart exception) | FR-009 |

State transitions: none — this is a stateless classification performed fresh on every call, not a lifecycle.

## Error Mapping Result

- **Represents**: the friendly, localized `String` message returned by `mapErrorToMessage(Object error, AppLocalizations l10n)`.
- **Attributes**: none beyond the string itself — the function signature is `Object error, AppLocalizations l10n → String`. Callers that need the raw error for logging/debugging purposes (none currently do, per Security principle's no-raw-data-in-logs rule) already have it from their own `catch (e)` binding; the mapper does not echo it back.
- **Relationships**: none — pure function, no entity graph.
- **Validation rules**: N/A (not user input).
- **Persistence**: explicitly never persisted (spec.md Key Entities: "computed on demand each time a failure occurs, never stored").

## Existing state shapes this feature edits (no new fields added)

These are pre-existing `StateNotifier` state classes; this feature changes *what value* flows into an existing field, not the shape of the state class itself:

- `IncomeFormState.writeErrorDetail` (existing `String?` field) — currently receives `e.toString()`; after this feature, the *widget-side* `ref.listen` call that reads it switches from `l10n.incomeErrorWriteFailedPrefix(next.writeErrorDetail ?? '')` to `mapErrorToMessage(...)`-produced text. Whether the field itself keeps storing the raw exception (for potential future debug use) or is repurposed is an implementation-time choice in tasks.md — either way, no new field is added to the state class.
- `ExpenseFormState.writeErrorDetail` / `ScanFormState.writeErrorDetail` (existing `String?` fields, same shape) — same treatment.
- `ExpenseControlFormState.errorMessage` (existing `String?` field, currently write-only/never displayed) — this feature adds the missing *display* (FR-012) but does not change the field's type or add a new field.
