-- Add the savings-receiver flag used by income allocation (FR-008–FR-012):
-- marks the single leaf item that receives any leftover income after every
-- formula has been applied. No RLS policy statement needed — the new
-- column inherits expense_control_items' existing row-level policy
-- automatically.

ALTER TABLE expense_control_items
  ADD COLUMN is_savings_receiver boolean NOT NULL DEFAULT false;
