-- Expense Transaction Recording feature: shared history for both income
-- allocations and expense recordings, so a future Report feature has one
-- consistent, queryable source for both directions (spec.md's Key Entities,
-- research.md Decision 1). Scoped to auth.uid() per the constitution's
-- Security section ("RLS MUST be enabled on every table containing user
-- data").

create table if not exists financial_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  expense_control_item_id uuid not null references expense_control_items (id),
  direction text not null check (direction in ('income', 'expense')),
  -- Always positive regardless of direction — direction alone carries the
  -- sign meaning (research.md Decision 3).
  amount integer not null check (amount > 0),
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- The hot query for a future Report feature is "all transactions for this
-- user in month M" — indexed accordingly (research.md Decision 1).
create index if not exists financial_transactions_user_id_idx
  on financial_transactions (user_id);
create index if not exists financial_transactions_user_id_occurred_at_idx
  on financial_transactions (user_id, occurred_at);

alter table financial_transactions enable row level security;

create policy financial_transactions_owner_only on financial_transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
