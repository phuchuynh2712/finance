# Internal UI Contract: Transaction History

## Purpose

Define the application-facing data and state contract used by the Spending
transaction-history screen. This is an internal Flutter application contract,
not a public HTTP API.

## Gateway Contract

`ExpenseControlRepository` owns a user-scoped reactive history operation that
returns pure `TransactionHistoryRecord` domain records. `ExpenseControlGateway`
maps these records to Spending view inputs; neither contract exposes Drift,
Supabase, or widget types. The repository guarantees rows are constrained to
the requested local-month range and sorted by occurrence time descending.

Each record provides:

- stable transaction ID;
- direction and positive VND amount;
- occurrence timestamp;
- immutable display name, group context, and icon key;
- source item ID only for internal filter identity when needed.

## Presentation Inputs

| Input | Behavior |
|---|---|
| Selected month | Defaults to current month; previous/next controls move one calendar month; next is disabled at current month. |
| Active filter | Defaults to All; exactly one of All, Income, or a selected-month group is active. |
| History records | Filtered and grouped by date before the list renders. |
| Async result | Loading shows progress, empty shows retained selection, error shows retry with retained selection. |

## Presentation Outputs

The screen renders:

- a back action returning to Spending;
- selected localized month and expense-only total;
- horizontally scrollable single-select filters;
- date headings and rows with semantic signed amounts;
- accessible labels for the header, month controls, active filter, transaction
  identity, and retry action.

## Error Contract

Data failures surface a localized retryable error. A retry repeats the current
month/filter read and does not reset selections. No raw exception text or
financial values are logged.