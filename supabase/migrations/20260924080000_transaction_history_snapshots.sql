alter table financial_transactions
  add column if not exists display_name text,
  add column if not exists display_group_name text,
  add column if not exists display_icon_key text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

update financial_transactions
set updated_at = coalesce(updated_at, created_at, now())
where updated_at is null;