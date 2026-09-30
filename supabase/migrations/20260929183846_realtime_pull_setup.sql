-- Realtime publication grant, idempotent: ALTER PUBLICATION ... ADD TABLE
-- errors if the table is already a member, which a repeated `supabase db
-- reset` in local dev would hit without this guard (research.md Decision 3).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'expense_control_items'
  ) then
    alter publication supabase_realtime add table expense_control_items;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'financial_transactions'
  ) then
    alter publication supabase_realtime add table financial_transactions;
  end if;
end $$;

-- FR-005a/research.md Decision 1: updated_at becomes server-issued and
-- trigger-enforced — no client-supplied value can reach storage, closing
-- the clock-skew risk in the constitution's last-write-wins-by-updated_at
-- policy. `create or replace function` is idempotent by nature; the
-- triggers are dropped-and-recreated for the same reset-safety reason as
-- the publication grant above.
create or replace function set_updated_at_to_now()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists expense_control_items_set_updated_at
  on expense_control_items;
create trigger expense_control_items_set_updated_at
  before insert or update on expense_control_items
  for each row
  execute function set_updated_at_to_now();

drop trigger if exists financial_transactions_set_updated_at
  on financial_transactions;
create trigger financial_transactions_set_updated_at
  before insert or update on financial_transactions
  for each row
  execute function set_updated_at_to_now();

-- No REPLICA IDENTITY change (research.md Decision 3) — the default is
-- sufficient since soft-deletes are UPDATEs, not DELETEs, and RLS filters
-- on the new row's user_id, which DEFAULT identity already includes.
