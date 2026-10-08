-- Transaction corrections (specs/20261008-010940-reverse-edit-transactions):
-- delete, edit and reverse a saved transaction, with the balance moving in the
-- same step on every device.
--
-- An item's balance becomes DERIVED: balance = balance_base + the sum of the
-- effects of the item's live (not soft-deleted) transactions, where the effect
-- of a transaction is its amount (income +, expense -), negated for a
-- reversing entry. The database recomputes it in triggers, and the app does
-- the same locally, so a device and the server agree whatever order changes
-- arrive in and however often one is applied. Devices no longer push a
-- balance; one sent anyway is overwritten.
--
-- A reversing entry is an ordinary row with a positive amount and a
-- `reverses_id` pointing at the transaction it cancels (same direction, same
-- amount, same item; the opposite effect). "Reversed" is derived: a live row
-- with reverses_id = the transaction's id exists.
--
-- ROLLOUT ORDER: apply this migration BEFORE the app version that depends on
-- it is released. It is idempotent (create or replace / drop ... if exists /
-- add ... if not exists), so a repeated run or `supabase db reset` is safe.
--
-- The server never looks at the clock: the 24-hour correction window is the
-- device's decision, taken when the person acts, so an action allowed offline
-- is kept when it syncs later.

-- ---------------------------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------------------------

alter table financial_transactions
  add column if not exists reverses_id uuid references financial_transactions (id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'financial_transactions_no_self_reversal'
  ) then
    alter table financial_transactions
      add constraint financial_transactions_no_self_reversal
      check (reverses_id is null or reverses_id <> id);
  end if;
end $$;

-- A transaction can be reversed at most once, whichever device makes the
-- reversal (the index also counts soft-deleted reversals: a deleted reversal
-- only exists when its original was deleted too, and then it cannot be
-- reversed again).
create unique index if not exists financial_transactions_reverses_id_uidx
  on financial_transactions (reverses_id)
  where reverses_id is not null;

-- The recompute sums an item's transactions.
create index if not exists financial_transactions_item_idx
  on financial_transactions (expense_control_item_id);

-- The part of the balance that no transaction explains: what the item had
-- before transactions were the source of the balance (0 for a new item).
alter table expense_control_items
  add column if not exists balance_base integer not null default 0;

-- Row Level Security is unchanged: the existing owner-only policies cover the
-- new columns.

-- ---------------------------------------------------------------------------
-- 2. Functions
-- ---------------------------------------------------------------------------

create or replace function tx_effect(
  p_direction text,
  p_amount integer,
  p_reverses_id uuid
)
returns integer
language sql
immutable
as $$
  select (case p_direction when 'income' then p_amount else -p_amount end)
       * (case when p_reverses_id is null then 1 else -1 end)
$$;

-- Sets the balance of one item to balance_base + the sum of the effects of its
-- live transactions. Writes only when the value changes, so an unchanged item
-- is not touched (and does not raise a Realtime event). Runs as the caller, so
-- Row Level Security keeps scoping it to the owner's rows.
create or replace function recompute_item_balance(p_item uuid)
returns void
language plpgsql
as $$
begin
  update expense_control_items i
     set balance = d.value
    from (
      select x.id,
             x.balance_base + coalesce((
               select sum(tx_effect(t.direction, t.amount, t.reverses_id))
                 from financial_transactions t
                where t.expense_control_item_id = x.id
                  and t.deleted_at is null
             ), 0) as value
        from expense_control_items x
       where x.id = p_item
    ) d
   where i.id = d.id
     and i.balance is distinct from d.value;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Backfill: balance_base = balance - the sum of the live effects, so the
-- derived balance equals the stored one at the moment of migration (nothing a
-- person sees changes). It runs BEFORE any trigger below exists, and a repeat
-- is harmless: balance is already base + effects, so the result is the same.
-- ---------------------------------------------------------------------------

update expense_control_items i
   set balance_base = i.balance - coalesce((
     select sum(tx_effect(t.direction, t.amount, t.reverses_id))
       from financial_transactions t
      where t.expense_control_item_id = i.id
        and t.deleted_at is null
   ), 0);

-- ---------------------------------------------------------------------------
-- 4. Guards on financial_transactions (they decide every conflict the same way
-- for every device, whatever the order the changes arrive in)
--
-- Refusal codes (the app classifies them; any other error is retried):
--   TX001 invalid_reversal      the original is missing, deleted, itself a
--                               reversal, or another user's
--   TX002 reversal_immutable    a reversal cannot be changed or deleted by hand
--   TX003 transaction_reversed  the amount, direction or item of a transaction
--                               that has a live reversal cannot change
--   23505 (unique index)        already reversed
-- ---------------------------------------------------------------------------

create or replace function financial_transactions_guard()
returns trigger
language plpgsql
as $$
declare
  original financial_transactions%rowtype;
begin
  if tg_op = 'INSERT' then
    if new.reverses_id is not null then
      select * into original
        from financial_transactions
       where id = new.reverses_id;
      if not found
         or original.deleted_at is not null
         or original.reverses_id is not null
         or original.user_id <> new.user_id then
        raise exception 'invalid reversal: the original is missing, deleted, itself a reversal or not yours'
          using errcode = 'TX001';
      end if;
      -- A reversal cancels the transaction as it stands now: copy what it
      -- cancels, whatever the device sent.
      new.direction := original.direction;
      new.amount := original.amount;
      new.expense_control_item_id := original.expense_control_item_id;
      new.display_name := original.display_name;
      new.display_group_name := original.display_group_name;
      new.display_icon_key := original.display_icon_key;
    end if;
    return new;
  end if;

  -- UPDATE ------------------------------------------------------------------

  -- Delete wins: a deleted row stays exactly as it was (only updated_at moves,
  -- through the trigger that follows, so the answer still reaches the devices).
  if old.deleted_at is not null then
    new := old;
    return new;
  end if;

  -- A transaction never becomes a reversal, and a reversal never points elsewhere.
  if new.reverses_id is distinct from old.reverses_id then
    raise exception 'reverses_id cannot change'
      using errcode = 'TX002';
  end if;

  if old.reverses_id is not null then
    -- A reversal never changes ...
    if (new.amount, new.direction, new.expense_control_item_id, new.deleted_at)
         is not distinct from
       (old.amount, old.direction, old.expense_control_item_id, old.deleted_at) then
      return new;      -- ... except by repeating itself (a retried push)
    end if;
    -- ... and is deleted only by the cascade of deleting its original.
    if pg_trigger_depth() > 1
       and new.deleted_at is not null
       and (new.amount, new.direction, new.expense_control_item_id)
             is not distinct from
           (old.amount, old.direction, old.expense_control_item_id) then
      return new;
    end if;
    raise exception 'a reversal cannot be changed'
      using errcode = 'TX002';
  end if;

  -- A transaction that has a live reversal can no longer be edited (a delete
  -- is still accepted: it wins, and takes the reversal with it).
  if new.deleted_at is null
     and (new.amount, new.direction, new.expense_control_item_id)
           is distinct from
         (old.amount, old.direction, old.expense_control_item_id)
     and exists (
       select 1 from financial_transactions r
        where r.reverses_id = old.id
          and r.deleted_at is null
     ) then
    raise exception 'the transaction has been reversed and can no longer be edited'
      using errcode = 'TX003';
  end if;

  return new;
end;
$$;

-- Fires after the row is written (and after the existing updated_at trigger):
-- deleting an original deletes its reversal, then the balances of the old and
-- the new item are recomputed.
create or replace function financial_transactions_ledger()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null then
    update financial_transactions
       set deleted_at = now()
     where reverses_id = new.id
       and deleted_at is null;
  end if;

  perform recompute_item_balance(new.expense_control_item_id);
  if tg_op = 'UPDATE'
     and old.expense_control_item_id is distinct from new.expense_control_item_id then
    perform recompute_item_balance(old.expense_control_item_id);
  end if;
  return null;
end;
$$;

-- Trigger names decide the firing order: a_… (guard), then the existing
-- financial_transactions_set_updated_at, and the after-row z_… (ledger).
drop trigger if exists a_financial_transactions_guard on financial_transactions;
create trigger a_financial_transactions_guard
  before insert or update on financial_transactions
  for each row
  execute function financial_transactions_guard();

drop trigger if exists z_financial_transactions_ledger on financial_transactions;
create trigger z_financial_transactions_ledger
  after insert or update on financial_transactions
  for each row
  execute function financial_transactions_ledger();

-- ---------------------------------------------------------------------------
-- 5. Items: the balance is whatever the transactions say, and balance_base is
-- not the client's to change.
-- ---------------------------------------------------------------------------

create or replace function expense_control_items_derive_balance()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    -- A new item has no transactions and no base, whatever the client sent.
    new.balance_base := 0;
    new.balance := 0;
  else
    new.balance_base := old.balance_base;
    new.balance := new.balance_base + coalesce((
      select sum(tx_effect(t.direction, t.amount, t.reverses_id))
        from financial_transactions t
       where t.expense_control_item_id = new.id
         and t.deleted_at is null
    ), 0);
  end if;
  return new;
end;
$$;

drop trigger if exists expense_control_items_derive_balance on expense_control_items;
create trigger expense_control_items_derive_balance
  before insert or update on expense_control_items
  for each row
  execute function expense_control_items_derive_balance();
