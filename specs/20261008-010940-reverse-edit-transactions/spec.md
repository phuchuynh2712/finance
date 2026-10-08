# Feature Specification: Delete, Edit and Reverse Saved Transactions

**Feature Branch**: `20261008-010940-reverse-edit-transactions`

**Created**: 2026-10-08

**Status**: Draft

**Input**: User description: "Xoá hoặc sửa giao dịch đã lưu. Cần hoàn lại số dư cùng lúc. Cần được hoàn thiện việc xử lý giao dịch thêm, xóa, hoặc sửa giao dịch. Giao dịch đã qua 1 thời gian thì không được sửa, mà chỉ có thể thêm một giao dịch âm bằng số giao dịch để trừ đi có được không? Có ảnh hưởng đến logic gì không?"

## Clarifications

### Session 2026-10-08

- Q: How long after it is recorded can a transaction still be deleted or edited directly? → A: 24 hours. Past that,
  only a reversal is possible.
- Q: In which month's report does a reversing entry count? → A: The month in which the reversal is made. The report of
  an earlier month keeps what was reported; the current month shows the reversal as its own figure.
- Q: When two devices act on the same recent transaction while offline (for example one deletes it and the other edits
  its amount), what is the final result? → A: Delete always wins: the transaction ends up deleted, the balance as if
  it had never been recorded (corrected once), and the device whose change did not apply tells the person. Two edits
  of the same transaction keep the last change.
- Q: A device that is offline deletes or edits a transaction at hour 23 and only syncs at hour 30: is the action kept,
  and whose clock decides the 24-hour window? → A: It is kept. The window is judged by the device's clock at the moment
  the person acts, however late the action reaches the other devices.

## User Scenarios & Testing *(mandatory)*

Today a saved transaction is final: the "Chi tiêu" screen and the income allocation of "Thu nhập" record a transaction
and change the balance of the budget items in the same step, and nothing can undo it (the earlier expense-transaction
feature listed editing, deleting and undoing as out of scope). A slip of the finger on an amount, or a spending
recorded against the wrong item, therefore leaves a wrong balance forever.

This feature closes the loop: a person can take back or fix a transaction, and the balances move with it in the same
step. A transaction that is old enough is no longer altered in place; it can only be corrected by adding a new entry
that cancels it, so that what was once reported stays traceable. The period during which a transaction can still be
altered directly is called the **correction window** in this document.

### User Story 1 - Take back a recent transaction and get the balance back (Priority: P1)

A person records an expense of 500.000 ₫ against "Ăn uống" and a moment later realizes it was a mistake (a duplicate
tap, a wrong amount they would rather re-enter, or an expense that never happened). They open the transaction in the
history, choose to delete it, confirm, and the item's balance returns to what it was before the expense.

**Why this priority**: it is the smallest change that stops a mistake from being permanent, and everything else
(editing, reversal) builds on the rule "a change to a transaction moves the balance by exactly its effect".

**Independent Test**: record an expense on an item, open it from the history within the correction window, delete it,
and check that the item's balance equals the value before the expense, the transaction no longer appears in the
history, the overview or the monthly report, and nothing else changed.

**Acceptance Scenarios**:

1. **Given** an expense of 500.000 ₫ recorded a few minutes ago against an item whose balance went from 2.000.000 ₫ to
   1.500.000 ₫, **When** the person deletes it and confirms, **Then** the item's balance is 2.000.000 ₫ again and the
   transaction is gone from the history, the recent-transactions list and the monthly totals.
2. **Given** the same transaction, **When** the person opens the delete confirmation, **Then** it shows the amount, the
   item and the balance the item will have afterwards, and deleting happens only after they confirm.
3. **Given** the person taps delete and then cancels, **Then** nothing changes.
4. **Given** the item is already negative because of this expense, **When** the person deletes the expense, **Then**
   the balance rises by the expense's amount, whether or not it becomes positive.
5. **Given** the device is offline, **When** the person deletes a recent transaction, **Then** the balance and the
   history change immediately on the device, and the same result reaches the other devices when it reconnects.

---

### User Story 2 - Fix a recent expense instead of deleting it (Priority: P1)

A person typed 50.000 ₫ but meant 500.000 ₫, or charged "Xăng xe" when it was "Ăn uống". They open the recent expense,
change the amount and/or the item, save, and both balances are right: the old item gets its money back, the new item
(or the same item with the new amount) is charged.

**Why this priority**: fixing is what people actually want most of the time, and it must not need a delete and a
retype that would also change the time the expense was recorded.

**Independent Test**: record an expense, edit its amount, and check that the item's balance is the original balance
minus the new amount; edit its item, and check that the old item is back to its original balance and the new item is
charged; the transaction keeps its original date and time.

**Acceptance Scenarios**:

1. **Given** a recent expense of 50.000 ₫ on "Ăn uống", whose balance was 500.000 ₫ before it and 450.000 ₫ after it,
   **When** the person changes the amount to 500.000 ₫ and saves, **Then** the balance is 0 ₫ (the balance before the
   expense minus the new amount) and the history shows 500.000 ₫.
2. **Given** a recent expense on "Xăng xe", **When** the person moves it to "Ăn uống", **Then** "Xăng xe" gets its
   amount back, "Ăn uống" is charged by it, and the history shows the new item's name and group.
3. **Given** the person changes both the amount and the item, **When** they save, **Then** both balances are right in
   one step, never one without the other.
4. **Given** the new amount is empty or zero, **When** the person saves, **Then** the save is blocked with a message
   and nothing changes.
5. **Given** an edit that would leave the item negative, **When** the person saves, **Then** the app only warns, as it
   does when recording an expense, and the edit is saved.
6. **Given** an edit, **Then** the transaction keeps the date and time it was first recorded, so it stays in the same
   month.

---

### User Story 3 - Correct an old transaction with a reversing entry (Priority: P2)

A transaction was recorded long ago (past the correction window) and turns out to be wrong. It can no longer be
altered, but the person can reverse it: the app adds a new entry that cancels it, of the same amount and with the
opposite effect, linked to the original. The original stays in the history, marked as reversed, so what was once
shown is never silently rewritten, and the balance is corrected by the same amount.

**Why this priority**: it keeps old periods trustworthy while still letting a real mistake be fixed; it is secondary
to US1 and US2 because most mistakes are noticed soon.

**Independent Test**: take a transaction older than the correction window, check that it offers no delete and no edit
but does offer "reverse"; reverse it and check that the balance moved by exactly its amount in the opposite direction,
that a new linked entry exists, that the original shows as reversed, and that it cannot be reversed a second time.

**Acceptance Scenarios**:

1. **Given** an expense of 300.000 ₫ older than the correction window, **When** the person opens it, **Then** delete
   and edit are not offered and "reverse" is.
2. **Given** that expense, **When** the person reverses it and confirms (the confirmation shows the resulting
   balance), **Then** the item's balance rises by 300.000 ₫, a new entry of 300.000 ₫ linked to the original appears
   in the history, and the original is marked as reversed.
3. **Given** a reversed transaction, **When** the person opens it or its reversing entry, **Then** reversing is not
   offered again, and the two entries point to each other.
4. **Given** an income allocation older than the window, **When** it is reversed, **Then** the balances it added are
   removed (see User Story 4).
5. **Given** the reversal makes an item's balance negative, **Then** the confirmation warns about it and the person
   may still proceed.
6. **Given** a transaction that is still inside the correction window, **Then** reversing is not the way to take it
   back: delete and edit are offered instead.

---

### User Story 4 - Take back or reverse a whole income allocation (Priority: P2)

Recording income splits one amount across several items in one action, producing one entry per item. The person must
be able to take back that income as a whole, never one item's share alone, because a partial removal would leave the
split inconsistent. Inside the correction window the whole income is deleted; after it, the whole income is reversed.

**Why this priority**: income is the other half of the money model, and without it the balances could be corrected
for spending but not for income.

**Independent Test**: record an income of 10.000.000 ₫ that allocates to three items, take it back from any one of its
entries, and check that all three items return to their previous balances in one step, and that no single entry of
that income can be removed on its own.

**Acceptance Scenarios**:

1. **Given** an income recorded in one action that produced three entries, **When** the person deletes any one of them
   inside the window, **Then** all three entries disappear and all three balances return to their previous values.
2. **Given** the same income past the window, **When** the person reverses any one of its entries, **Then** one
   reversing entry per item is added, all linked to their originals, and all three balances are reduced.
3. **Given** an income entry, **Then** it cannot be edited in place; to change an income the person takes it back and
   records it again.
4. **Given** that some item of the income has since been removed from the plan, **When** the income is taken back,
   **Then** the other items still return to their previous balances and the person is told that one share had no
   balance to correct.

---

### User Story 5 - The same result on every device, even offline (Priority: P3)

A person who uses the app on a phone and in a browser, or who works offline, must see the same balances and history
after any delete, edit or reversal, and must never get a balance corrected twice.

**Why this priority**: the app already syncs; this story makes sure the new operations respect that, but the
operations are usable before it is perfect.

**Independent Test**: delete or reverse the same transaction on two devices that were both offline, reconnect both, and
check that the balance was corrected once and both devices show the same history.

**Acceptance Scenarios**:

1. **Given** two devices that both show the same recent expense, **When** both delete it while offline and then
   reconnect, **Then** the balance is restored once and both devices show the same state.
2. **Given** a device that edits an expense while another device deletes it, **When** they reconnect, **Then** the
   transaction is deleted on both, the balance is as if it had never been recorded (corrected once), and the person on
   the editing device is told that their edit no longer applies.
3. **Given** two devices that each edit the same expense while offline, **When** they reconnect, **Then** the last
   change is kept on both, the balances follow that final amount and item, never the first, and the person whose
   earlier edit was replaced is told.
4. **Given** a transaction that one device deletes inside its window while another device, judging it past the window,
   reverses it, **When** they reconnect, **Then** the transaction is deleted, the reversing entry is dropped, and the
   balance is corrected only once.
5. **Given** a delete, an edit or a reversal made on one device, **When** another device is online, **Then** it shows
   the new balances and history without being restarted.
6. **Given** a device that has finished synchronising but whose balance for an item still differs from the balance the
   server reports for it, **When** the app notices, **Then** it first tries once to synchronise that data again, and
   if the difference remains it tells the person instead of silently adopting either figure.

---

### Edge Cases

- The item a transaction was charged to has been renamed: the history keeps showing the name recorded at the time,
  and the confirmation shows the current name.
- The item was removed from the plan: a recent transaction on it can still be deleted and an old one reversed, with no
  balance to restore and a message saying so; it cannot be edited to charge a removed item.
- The correction window ends while the person has the edit screen open: saving is refused with a message and nothing
  changes (the person may reverse instead).
- A transaction is edited, then reversed or deleted: balances follow its latest values, never its first.
- A reversing entry cannot itself be reversed, edited or deleted; to undo a reversal the person records the
  transaction again.
- Partial reversal (a smaller amount than the original) is not offered.
- Two quick taps on "confirm" do not correct the balance twice.
- A transaction recorded shortly before midnight on the last day of a month can still be deleted or edited in the
  next month (the window is 24 hours): the report of the month it was recorded in then changes, because the
  transaction is taken back as if it had never been made. This is the only way a closed month's figures change; a
  reversal never changes them (FR-010).
- The device clock is wrong: the window is judged from the time recorded with the transaction and the time the device
  believes it is now (FR-002); a person who sets their own clock back can therefore keep a transaction editable
  longer, which is accepted because the data is their own.
- A delete or edit made offline inside the window is kept when it syncs after the window has ended (FR-002); the
  person is not told that it failed.
- A long history must not slow the actions: with 5,000 transactions in the history, the database work of a delete, an
  edit or a reversal takes under 0.5 second.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Opening a transaction from the history (and from the recent-transactions list) MUST give access to the
  actions that apply to it: delete or edit while it is inside the correction window, reverse once it is past it, and
  nothing for a transaction that is already reversed or is itself a reversing entry.
- **FR-002**: A transaction is **inside the correction window** from the moment it is recorded until 24 hours later.
  After that it is **past the window** and FR-006 applies. The window is the same for every transaction and is judged
  by the clock of the device on which the person acts, at the moment they act: an action that was allowed on that
  device MUST be kept when it reaches the other devices later, even more than 24 hours after the transaction was
  recorded.
- **FR-003**: Deleting a transaction inside the window MUST remove it from the history, the recent-transactions list,
  the monthly totals and the per-item report, and MUST restore the balance of the item it was charged to by exactly its
  effect (an expense returns its amount; an income entry takes its amount away), in the same step, never one without
  the other.
- **FR-004**: Editing an expense inside the window MUST allow changing its amount (greater than zero) and the item it
  is charged to; the balances of the previous and the new item MUST both be corrected in the same step; the
  transaction MUST keep its original date and time; the name and group shown in the history MUST become those of the
  new item. The date and time themselves are not editable.
- **FR-005**: Income entries MUST NOT be editable individually. Taking back an income MUST act on every entry that was
  recorded together in the same action, all or nothing: deleting inside the window, reversing past it. An individual
  entry of an income MUST NOT be deleted or reversed alone.
- **FR-006**: A transaction past the window MUST NOT be edited or deleted. It MUST be possible to **reverse** it: the
  app adds a new entry of the same amount whose effect on the balance is the opposite of the original, linked to the
  original; the original MUST stay in the history and be shown as reversed; the balance MUST be corrected in the same
  step.
- **FR-007**: A transaction MUST be reversible at most once, and a reversing entry MUST NOT be edited, deleted or
  reversed. A partial reversal MUST NOT be possible.
- **FR-008**: Before a delete or a reversal is applied, the person MUST see a confirmation showing the amount, the item
  and the balance the item will have afterwards, and nothing MUST change until they confirm. A balance that would
  become negative MUST only produce a warning, as when recording an expense; it MUST NOT block the action.
- **FR-009**: Saving an edit MUST be refused, with a message and no change, when the amount is empty or zero, when the
  chosen item is no longer in the plan, or when the transaction has meanwhile left the correction window.
- **FR-010**: A reversal MUST count in the monthly report of the month in which it is made, never in the month of the
  transaction it cancels: the report of an earlier month MUST NOT change because of a later reversal. The report MUST
  show the amounts reversed in a month as their own figures (expenses refunded, income withdrawn), separate from that
  month's income and spending, so that a reversal never makes an income, spending or per-item figure negative. A
  transaction that is reversed keeps counting in its own month as it was reported, and the report MUST NOT count a
  transaction and its reversal together in the same figure.
- **FR-011**: The history and the recent-transactions list MUST show a reversed transaction and its reversing entry
  recognizably linked, and MUST NOT show a deleted transaction at all.
- **FR-012**: When the item a transaction was charged to no longer exists, delete (inside the window) and reverse (past
  it) MUST still be possible and MUST tell the person that there is no balance to restore; edit MUST NOT allow
  charging a removed item.
- **FR-013**: Every delete, edit and reversal MUST work offline with the same immediate effect on balances and history,
  and MUST reach every other device of the same account with the same result.
- **FR-014**: The same transaction MUST NOT correct a balance more than once, whatever the number of devices,
  retries or repeated taps (idempotence). When two devices make conflicting changes to the same transaction, the
  outcome MUST be one consistent state that keeps the balances consistent with the history: a delete always wins over an
  edit or over a reversal made at the same time (the transaction ends up deleted, as if it had never been recorded, and
  the reversal is dropped so the balance is corrected once); two edits keep the last change; a reversal cancels the
  transaction as it stands once all changes are combined (its final amount and item). The person whose change did not
  apply MUST be told.
- **FR-015**: After any sequence of recording, deleting, editing and reversing, the balance of every item MUST equal the
  sum of the effects of its transactions that still count (allocations minus expenses, with deleted ones removed and
  reversals cancelling their originals), apart from what a person changed in the budget plan itself.
- **FR-016**: Only the signed-in person's own transactions MUST be changeable, and a signed-out device MUST NOT offer
  any of these actions.
- **FR-017**: Transactions that were never deleted, edited or reversed MUST be unaffected: their history rows, balances
  and the figures of every report MUST be the same as before this feature.
- **FR-018**: When a device has finished synchronising and the balance it holds for an item still differs from the
  balance the server reports for that item, the app MUST NOT silently replace its figure with the server's, or the
  other way round: it MUST first try once to synchronise that data again and, if the difference remains, MUST tell the
  person. A difference that exists only because the device still has changes waiting to be sent is not such a
  difference.

### Key Entities *(include if feature involves data)*

- **Transaction**: an income or expense entry recorded against one budget item, with an amount (greater than zero),
  a direction, the time it was recorded and the name, group and icon of the item as they were then. This feature adds
  to it a state: active, deleted, or reversed (and, for a reversing entry, a link to the transaction it cancels).
- **Reversing entry** (called a *reversal* in the plan and the code): a transaction created by a reversal; same amount
  as the original, opposite effect on the balance, linked to the original, never changeable.
- **Income event**: the set of income entries recorded together by one "Lưu thu nhập" action (one entry per allocated
  item); deleted or reversed as a whole.
- **Correction window**: the 24 hours after recording during which a transaction can be deleted or edited directly.
- **Item balance**: the running amount of a budget item, changed by recording, deleting, editing and reversing in the
  same step as the transaction.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person can delete, edit or reverse a transaction in at most three steps after opening it from the
  history (choose the action; for an edit, enter the new amount or pick the new item; confirm or save), and in under
  20 seconds.
- **SC-002**: Over any mix of recording, deleting, editing and reversing, in 100 % of cases the balance of each item
  equals the sum of the effects of the transactions that still count (FR-015), verified on randomly generated sequences.
- **SC-003**: A deleted transaction appears in none of the history, the overview, the monthly totals and the per-item
  report, and a reversed transaction and its reversal are never counted together in the same figure, in 100 % of cases.
- **SC-004**: After a delete, edit or reversal made while offline, every device of the account shows the same balances
  and history within 10 seconds of the device regaining connectivity, and the balance is corrected exactly once even
  when two devices acted on the same transaction.
- **SC-005**: No transaction past the correction window can be changed other than by reversal (zero exceptions in the
  tests that try every other path).
- **SC-006**: For an account that never uses these actions, every balance, history row and report figure is identical
  to what it was before the feature (zero differences).
- **SC-007**: A reversal never changes the report of an earlier month, and no income, spending or per-item figure of
  any month is ever negative because of a reversal (zero differences and zero negatives in the tests).
- **SC-008**: In 100 % of the tests that make a device's balance diverge from the server's after both have finished
  synchronising, the person is told within 30 seconds, and in 100 % of the tests where the difference disappears
  after the one new synchronisation, the person is not told.

## Assumptions

- The correction window is 24 hours from the time the transaction was recorded, one rule for every transaction.
- Editing covers expenses only, and only their amount and item, never the date; the date stays so that a transaction
  never moves to another month. Changing a recorded income means taking it back and recording it again.
- A reversing entry is a normal, positive-amount entry with the opposite effect, not a negative amount: this keeps the
  rule that an amount is always greater than zero and keeps income and expense totals from being reduced in place.
- Income entries recorded together by one action share the same recorded time; for transactions that exist before this
  feature, entries of income direction with the same recorded time are treated as one income event.
- Taking back an income removes the balances it added from the items it was allocated to, using the amounts that were
  recorded then, not the current allocation formulas.
- Deleted transactions are kept as removed records so that other devices learn about the deletion; the person sees
  them nowhere.
- No history of earlier values of an edited transaction is kept beyond the latest ones.
- The one-person, several-devices case is the target; sharing an account between people is out of scope.
- Searching, filtering or exporting transactions is unchanged; budget-plan editing (formulas, items) is unchanged.
- The existing warn-only rule for negative balances stays: nothing in this feature blocks a balance from going below
  zero.
- The new screens and messages follow the app's existing rules: Vietnamese and English text, the adaptive layout from
  phone to wide web window, 48 dp touch targets, larger text sizes, and keyboard use on the web.
- A deleted transaction cannot be brought back (a confirmation always comes first); to undo a delete the person records
  the transaction again. A reversal cannot be undone either (FR-007).
- Out of scope here: deleting or reversing many transactions at once, editing the date of a transaction, editing
  an income entry in place, a log of the earlier values of an edited transaction, and any behavior guarantee for a
  device that still runs a version of the app from before this feature (all devices of an account are expected to be
  kept up to date).
