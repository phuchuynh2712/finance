-- Expense Control feature: Supabase Postgres schema + Row Level Security.
-- Sync target for the Drift-first local schema described in data-model.md.
-- Scoped to auth.uid() per the constitution's Security section ("RLS MUST be
-- enabled on every table containing user data").
--
-- This table is new and additive — it does NOT replace or migrate rows from
-- the existing `envelopes` table (specs/20260725-budget-envelopes/contracts/
-- schema.sql), which stays in place unchanged for the "Thu chi"/"Hồ sơ"
-- screens per this feature's Assumptions (research.md §3).

create table if not exists expense_control_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  parent_id uuid references expense_control_items (id),
  name text not null check (char_length(name) > 0),
  icon_key text not null check (char_length(icon_key) > 0),
  description text,
  sort_order integer not null default 0,
  -- Nullable pair: null for a group (has children), set for a leaf.
  -- The "must be null iff it has children" invariant is enforced in the
  -- Dart domain layer (research.md §5), not here — expressing "no rows
  -- reference me as parent_id" as a CHECK constraint isn't possible in
  -- standard Postgres.
  allocation_method text check (allocation_method in ('percentage', 'fixed')),
  allocation_value numeric check (allocation_value > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Per constitution Principle IV — every query is filtered by user_id
-- (RLS-scoped reads), and children are looked up by parent_id.
create index if not exists expense_control_items_user_id_idx
  on expense_control_items (user_id);
create index if not exists expense_control_items_parent_id_idx
  on expense_control_items (parent_id);

alter table expense_control_items enable row level security;

create policy expense_control_items_owner_only on expense_control_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
