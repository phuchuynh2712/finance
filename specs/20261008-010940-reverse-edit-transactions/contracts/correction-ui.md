# Contract: Correction Screens

**Stories**: US1–US5 | **Requirements**: FR-001, FR-008, FR-009, FR-011, FR-012, FR-014, FR-018 | **Code**: `lib/features/expenses/presentation/{transaction_actions_sheet,edit_expense_dialog,transaction_history_screen,overview_screen,report_screen}.dart`

All of it uses the existing tokens (`AppTheme`, `AppSemanticColors`), the shared currency formatter, targets of at least
48 dp, the existing confirmation-dialog look, and strings from the generated localizations only (vi and en).

## 1. Opening a transaction

A row of the history and of the recent-transactions list becomes a tap target (the whole row, at least 48 dp high)
that opens `TransactionActionsSheet` (a modal bottom sheet on a phone width, a centered dialog from 600 dp up, the same
split the other pop-ups use). The sheet shows: the item name and group as recorded, the amount with its sign and color,
the recorded date and time, a "Reversed" or "Reversal of ..." line when it applies, and then the actions of
`TransactionCorrectionPolicy.availableActions`. With no action it shows the details and a short explanation.

| State of the transaction | Actions shown |
|--------------------------|---------------|
| expense inside the window | Edit, Delete |
| income entry inside the window | Delete (the note says it takes back the whole income, with its number of entries) |
| any original past the window, not reversed | Reverse (income: the whole event) |
| reversed original, or a reversal row | none, with the line that says why |

## 2. Confirmations (FR-008)

Delete and Reverse open one `AlertDialog` each: title; the amount, the item's current name and the balance it will have
afterwards (one line per item for an income event); the cancel button; the confirm button (the destructive action
colored, **not** the initial focus: Cancel has it). A balance that would become negative adds a warning line and does
not disable the confirm button. When the item was removed from the plan the line says there is no balance to restore.
Nothing is written until confirm; the confirm button is disabled while the operation runs (no double tap).

## 3. Edit (expense)

`EditExpenseDialog`: the amount (a digits-only `TextField` with a numeric keyboard; the recording screen's keypad is
private to that screen and is not reused), the item chooser (leaves only, the same chips), and a preview line "balance before → after" for
the old and the new item; a balance that would become negative adds the same warning line as the confirmations (in the
warning style of the recording screen's preview banner) and does not disable Save. Save is disabled for an empty or
zero amount (message under the field). If the window has
ended while it was open, saving shows the message and closes with nothing changed.

## 4. Results, refusals and mismatches

After success: the sheet closes and a snack bar says what happened (deleted, saved, reversed). A change the server
refused or replaced (a `SyncNotice` from the sync notices holder, see `sync-reconciliation.md`) shows one snack bar
through the `SyncNoticeHost` of the app shell the next time the person is on a screen of the app: "Your change to <item>, <amount> no longer applies because the transaction was <deleted | reversed | already
reversed | edited> on another device". The balances are already corrected by then (the local row was replaced by the server's). A balance that still differs
from the server's after one new synchronisation shows "The balance of <item> does not match the server's. Connect to
the internet and open the app again to synchronise." (`syncBalanceMismatchNotice`) once, and changes neither figure.

## 5. Rows and report figures

- A **reversed original** keeps its row and gets a "Reversed" tag; its reversal row shows with a "Reversal" tag, the
  opposite sign color, and the same item; tapping either opens the sheet with the link to the other.
- The monthly expense total on the history and the report's income and spending figures and per-item spent and
  allocated ignore reversal rows; two figures, "Refunded expenses" and "Withdrawn income", sum them for the month, shown
  only when not zero, below the totals, in a neutral style (never inside a negative number).
- Deleted transactions are shown nowhere (already the rule for `deleted_at`).

## 6. Strings (both languages; keys in `app_*.arb`, parity test extended)

`correctionActionEdit`, `correctionActionDelete`, `correctionActionReverse`, `correctionSheetReversedTag`,
`correctionSheetReversalOf`, `correctionSheetNoActionReversed`,
`correctionIncomeEventNote(count)`, `correctionDeleteTitle`, `correctionDeleteMessage(amount, item, balance)`,
`correctionReverseTitle`, `correctionReverseMessage(amount, item, balance)`, `correctionBalanceLine(item, balance)`,
`correctionNegativeBalanceWarning`, `correctionItemRemovedNote`, `correctionEditTitle`, `correctionEditAmountLabel`,
`correctionEditSave`, `correctionErrorAmount`, `correctionErrorWindowEnded`, `correctionErrorItemRemoved`, `correctionErrorNoLongerAvailable`,
`correctionDoneDeleted`, `correctionDoneEdited`, `correctionDoneReversed`, `correctionRefusedNotice(item, amount,
reason)`, `correctionRefusedReasonDeleted`, `correctionRefusedReasonReversed`, `correctionRefusedReasonAlreadyReversed`,
`correctionRefusedReasonEditedElsewhere`,
`historyTagReversed`, `historyTagReversal`, `reportRefundedExpense`, `reportWithdrawnIncome`, `syncBalanceMismatchNotice(item)`.

## 7. Layout and accessibility checks

At 320, 412, 600, 840, 1200, 1600 and 2560 dp wide, 500 dp high, 130 % text, light and dark: no overflow; the sheet and
dialogs bounded in width; every action and row at least 48 dp; each row, tag and action reachable by a screen reader
with a label that says the amount, the item and the state; the confirmation completable from a hardware keyboard
(Tab to the buttons, Enter, Escape = Cancel).
