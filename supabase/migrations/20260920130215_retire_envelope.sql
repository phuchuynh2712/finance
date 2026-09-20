-- Retire the legacy Envelope data model (FR-015, FR-020): add the
-- expense_control_items.balance column, then drop the envelope_balances
-- view and every Envelope-related table in dependency-safe order
-- (data-model.md's Drop order). No RLS policy statement is needed for the
-- drops — Postgres removes a table's RLS policies automatically when the
-- table itself is dropped.

ALTER TABLE expense_control_items
  ADD COLUMN balance integer NOT NULL DEFAULT 0;

DROP VIEW IF EXISTS envelope_balances;
DROP TABLE IF EXISTS envelope_coverages;
DROP TABLE IF EXISTS allocation_event_lines;
DROP TABLE IF EXISTS allocation_events;
DROP TABLE IF EXISTS expense_entries;
DROP TABLE IF EXISTS envelopes;
