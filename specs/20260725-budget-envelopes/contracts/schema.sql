-- Budget Envelopes feature: Supabase Postgres schema + Row Level Security.
-- This is the sync target for the Drift-first local schema described in
-- data-model.md. Every table is scoped to auth.uid() per the constitution's
-- Security section ("RLS MUST be enabled on every table containing user data").

create table if not exists envelopes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  name text not null check (char_length(name) > 0),
  allocation_method text not null check (allocation_method in ('percentage', 'fixed')),
  allocation_value numeric not null check (allocation_value > 0),
  balance bigint not null default 0,
  is_rounding_receiver boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- At most one rounding-remainder receiver per user (research.md §3).
create unique index if not exists envelopes_one_rounding_receiver_per_user
  on envelopes (user_id)
  where is_rounding_receiver and deleted_at is null;

-- Per constitution Principle IV ("Persisted local data access MUST be indexed
-- for the query patterns the app actually uses") — every table below is
-- filtered by user_id on nearly every query (RLS-scoped reads), and the
-- expense/coverage tables are additionally filtered by envelope_id.
create index if not exists envelopes_user_id_idx on envelopes (user_id);

create table if not exists allocation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  event_date timestamptz not null default now(),
  income_amount bigint not null check (income_amount > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists allocation_events_user_id_idx on allocation_events (user_id);

create table if not exists allocation_event_lines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  allocation_event_id uuid not null references allocation_events (id),
  envelope_id uuid not null references envelopes (id),
  amount bigint not null,
  is_rounding_remainder_line boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists allocation_event_lines_user_id_idx on allocation_event_lines (user_id);
create index if not exists allocation_event_lines_envelope_id_idx on allocation_event_lines (envelope_id);

create table if not exists expense_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  envelope_id uuid not null references envelopes (id),
  amount bigint not null check (amount > 0),
  entry_date date not null,
  note text,
  entry_method text not null default 'manual' check (entry_method in ('manual', 'scanned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists expense_entries_user_id_idx on expense_entries (user_id);
create index if not exists expense_entries_envelope_id_idx on expense_entries (envelope_id);

create table if not exists envelope_coverages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  expense_entry_id uuid not null references expense_entries (id) on delete cascade,
  source_envelope_id uuid not null references envelopes (id),
  covering_envelope_id uuid not null references envelopes (id),
  amount bigint not null check (amount > 0),
  covered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists envelope_coverages_user_id_idx on envelope_coverages (user_id);
create index if not exists envelope_coverages_source_envelope_id_idx on envelope_coverages (source_envelope_id);
create index if not exists envelope_coverages_covering_envelope_id_idx on envelope_coverages (covering_envelope_id);

-- Source-of-truth balance recomputation, independent of the materialized
-- `envelopes.balance` column (research.md §2). The sync worker reconciles
-- against this view rather than trusting the synced column as final.
create or replace view envelope_balances as
select
  e.id as envelope_id,
  e.user_id,
  coalesce(allocations.total, 0)
    - coalesce(expenses.total, 0)
    - coalesce(covered_out.total, 0)
    + coalesce(covered_in.total, 0) as computed_balance
from envelopes e
left join (
  select envelope_id, sum(amount) as total
  from allocation_event_lines
  where deleted_at is null
  group by envelope_id
) allocations on allocations.envelope_id = e.id
left join (
  select envelope_id, sum(amount) as total
  from expense_entries
  where deleted_at is null
  group by envelope_id
) expenses on expenses.envelope_id = e.id
left join (
  select source_envelope_id as envelope_id, sum(amount) as total
  from envelope_coverages
  where deleted_at is null
  group by source_envelope_id
) covered_out on covered_out.envelope_id = e.id
left join (
  select covering_envelope_id as envelope_id, sum(amount) as total
  from envelope_coverages
  where deleted_at is null
  group by covering_envelope_id
) covered_in on covered_in.envelope_id = e.id
where e.deleted_at is null;

-- Row Level Security: every table scoped to its owning user.
alter table envelopes enable row level security;
alter table allocation_events enable row level security;
alter table allocation_event_lines enable row level security;
alter table expense_entries enable row level security;
alter table envelope_coverages enable row level security;

create policy envelopes_owner_only on envelopes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy allocation_events_owner_only on allocation_events
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy allocation_event_lines_owner_only on allocation_event_lines
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy expense_entries_owner_only on expense_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy envelope_coverages_owner_only on envelope_coverages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
