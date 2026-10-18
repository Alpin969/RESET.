create table if not exists public.savings_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  transaction_type text not null,
  amount bigint not null,
  note text,
  transaction_date timestamptz not null default now(),
  idempotency_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint savings_transactions_type_valid
    check (transaction_type in ('deposit', 'withdrawal')),
  constraint savings_transactions_amount_positive
    check (amount > 0 and amount <= 1000000000000000),
  constraint savings_transactions_note_length
    check (note is null or char_length(note) between 1 and 200),
  constraint savings_transactions_key_length
    check (idempotency_key is null or char_length(idempotency_key) between 8 and 64)
);

create unique index if not exists savings_transactions_user_key_uidx
  on public.savings_transactions (user_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists savings_transactions_user_date_idx
  on public.savings_transactions (user_id, transaction_date desc, id desc);

drop trigger if exists savings_transactions_set_updated_at on public.savings_transactions;
create trigger savings_transactions_set_updated_at
  before update on public.savings_transactions
  for each row
  execute function public.set_updated_at();

alter table public.savings_transactions enable row level security;

drop policy if exists savings_select_own on public.savings_transactions;
create policy savings_select_own
  on public.savings_transactions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.savings_lock(p_uid uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('savings:' || p_uid::text, 1));
end;
$$;

create or replace function public.savings_total(p_uid uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    sum(
      case
        when transaction_type = 'deposit' then amount
        else -amount
      end
    ),
    0
  )::bigint
  from public.savings_transactions
  where user_id = p_uid;
$$;

create or replace function public.savings_validate_amount(p_amount bigint)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_amount is null then
    raise exception 'Nominal wajib diisi.';
  end if;

  if p_amount <= 0 then
    raise exception 'Nominal harus lebih besar dari nol.';
  end if;

  if p_amount > 1000000000000000 then
    raise exception 'Nominal maksimal Rp1.000.000.000.000.000.';
  end if;
end;
$$;

create or replace function public.savings_validate_note(p_note text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_note is not null and char_length(v_note) > 200 then
    raise exception 'Catatan maksimal 200 karakter.';
  end if;

  return v_note;
end;
$$;

create or replace function public.savings_add_transaction(
  p_transaction_type text,
  p_amount bigint,
  p_note text default null,
  p_transaction_date timestamptz default null,
  p_idempotency_key text default null
)
returns public.savings_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_type text;
  v_amount bigint;
  v_note text;
  v_date timestamptz;
  v_key text;
  v_balance bigint;
  v_effect bigint;
  v_log public.savings_transactions;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  v_type := coalesce(btrim(p_transaction_type), '');

  if v_type not in ('deposit', 'withdrawal') then
    raise exception 'Jenis transaksi tidak valid.';
  end if;

  perform public.savings_validate_amount(p_amount);
  v_amount := p_amount;
  v_note := public.savings_validate_note(p_note);
  v_date := coalesce(p_transaction_date, now());
  v_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');

  if v_key is not null and (char_length(v_key) < 8 or char_length(v_key) > 64) then
    raise exception 'Idempotency key harus 8-64 karakter.';
  end if;

  if v_date > now() + interval '1 day' then
    raise exception 'Tanggal transaksi tidak boleh jauh di masa depan.';
  end if;

  perform public.savings_lock(v_uid);

  if v_key is not null then
    select * into v_log
    from public.savings_transactions
    where user_id = v_uid
      and idempotency_key = v_key;

    if found then
      if v_log.transaction_type = v_type
        and v_log.amount = v_amount
        and v_log.note is not distinct from v_note
        and v_log.transaction_date = v_date
      then
        return v_log;
      end if;

      raise exception 'Idempotency key sudah dipakai dengan data transaksi berbeda.';
    end if;
  end if;

  v_balance := public.savings_total(v_uid);
  v_effect := case when v_type = 'deposit' then v_amount else -v_amount end;

  if v_type = 'withdrawal' and v_amount > v_balance then
    raise exception 'Saldo tidak mencukupi untuk penarikan.';
  end if;

  if v_balance + v_effect > 9000000000000000000 then
    raise exception 'Saldo melebihi batas maksimum.';
  end if;

  insert into public.savings_transactions
    (user_id, transaction_type, amount, note, transaction_date, idempotency_key)
  values
    (v_uid, v_type, v_amount, v_note, v_date, v_key)
  returning * into v_log;

  return v_log;
end;
$$;

create or replace function public.savings_update_transaction(
  p_id uuid,
  p_amount bigint default null,
  p_note text default null,
  p_clear_note boolean default false
)
returns public.savings_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_log public.savings_transactions;
  v_old_effect bigint;
  v_new_amount bigint;
  v_new_note text;
  v_new_effect bigint;
  v_balance bigint;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_id is null then
    raise exception 'Transaksi tidak ditemukan.';
  end if;

  perform public.savings_lock(v_uid);

  select * into v_log
  from public.savings_transactions
  where id = p_id
    and user_id = v_uid
  for update;

  if not found then
    raise exception 'Transaksi tidak ditemukan.';
  end if;

  v_new_amount := coalesce(p_amount, v_log.amount);
  perform public.savings_validate_amount(v_new_amount);

  if p_clear_note then
    v_new_note := null;
  elsif p_note is not null then
    v_new_note := public.savings_validate_note(p_note);
  else
    v_new_note := v_log.note;
  end if;

  v_old_effect := case
    when v_log.transaction_type = 'deposit' then v_log.amount
    else -v_log.amount
  end;

  v_new_effect := case
    when v_log.transaction_type = 'deposit' then v_new_amount
    else -v_new_amount
  end;

  v_balance := public.savings_total(v_uid);

  if v_balance - v_old_effect + v_new_effect < 0 then
    raise exception 'Perubahan transaksi akan membuat saldo menjadi negatif.';
  end if;

  if v_balance - v_old_effect + v_new_effect > 9000000000000000000 then
    raise exception 'Saldo melebihi batas maksimum.';
  end if;

  update public.savings_transactions
  set amount = v_new_amount,
      note = v_new_note
  where id = p_id
    and user_id = v_uid
  returning * into v_log;

  return v_log;
end;
$$;

create or replace function public.savings_delete_transaction(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_log public.savings_transactions;
  v_effect bigint;
  v_balance bigint;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_id is null then
    raise exception 'Transaksi tidak ditemukan.';
  end if;

  perform public.savings_lock(v_uid);

  select * into v_log
  from public.savings_transactions
  where id = p_id
    and user_id = v_uid
  for update;

  if not found then
    raise exception 'Transaksi tidak ditemukan.';
  end if;

  v_effect := case
    when v_log.transaction_type = 'deposit' then v_log.amount
    else -v_log.amount
  end;

  v_balance := public.savings_total(v_uid);

  if v_balance - v_effect < 0 then
    raise exception 'Penghapusan transaksi akan membuat saldo menjadi negatif.';
  end if;

  delete from public.savings_transactions
  where id = p_id
    and user_id = v_uid;
end;
$$;

create or replace function public.savings_balance()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select public.savings_total(auth.uid());
$$;

create or replace function public.savings_balance_before(p_date date)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    sum(
      case
        when transaction_type = 'deposit' then amount
        else -amount
      end
    ),
    0
  )::bigint
  from public.savings_transactions
  where user_id = auth.uid()
    and (timezone(public.user_timezone(auth.uid()), transaction_date))::date < p_date;
$$;

create or replace function public.savings_get(p_id uuid)
returns public.savings_transactions
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_log public.savings_transactions;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  select * into v_log
  from public.savings_transactions
  where id = p_id
    and user_id = v_uid;

  if not found then
    raise exception 'Transaksi tidak ditemukan.';
  end if;

  return v_log;
end;
$$;

create or replace function public.savings_list_my(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  user_id uuid,
  transaction_type text,
  amount bigint,
  note text,
  transaction_date timestamptz,
  transaction_local_date date,
  idempotency_key text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  return query
  select
    t.id,
    t.user_id,
    t.transaction_type,
    t.amount,
    t.note,
    t.transaction_date,
    (timezone(public.user_timezone(v_uid), t.transaction_date))::date,
    t.idempotency_key,
    t.created_at,
    t.updated_at
  from public.savings_transactions t
  where t.user_id = v_uid
  order by t.transaction_date desc, t.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.savings_transactions_between(p_from date, p_to date)
returns table (
  id uuid,
  user_id uuid,
  transaction_type text,
  amount bigint,
  note text,
  transaction_date timestamptz,
  transaction_local_date date,
  idempotency_key text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_from is null or p_to is null then
    raise exception 'Tanggal wajib diisi.';
  end if;

  if p_from > p_to then
    raise exception 'Rentang tanggal tidak valid.';
  end if;

  return query
  select
    t.id,
    t.user_id,
    t.transaction_type,
    t.amount,
    t.note,
    t.transaction_date,
    (timezone(public.user_timezone(v_uid), t.transaction_date))::date,
    t.idempotency_key,
    t.created_at,
    t.updated_at
  from public.savings_transactions t
  where t.user_id = v_uid
    and (timezone(public.user_timezone(v_uid), t.transaction_date))::date between p_from and p_to
  order by t.transaction_date asc, t.id asc;
end;
$$;

revoke execute on function public.savings_lock(uuid) from public;
revoke execute on function public.savings_lock(uuid) from anon;
revoke execute on function public.savings_lock(uuid) from authenticated;

revoke execute on function public.savings_total(uuid) from public;
revoke execute on function public.savings_total(uuid) from anon;
revoke execute on function public.savings_total(uuid) from authenticated;

revoke execute on function public.savings_validate_amount(bigint) from public;
revoke execute on function public.savings_validate_amount(bigint) from anon;
revoke execute on function public.savings_validate_amount(bigint) from authenticated;

revoke execute on function public.savings_validate_note(text) from public;
revoke execute on function public.savings_validate_note(text) from anon;
revoke execute on function public.savings_validate_note(text) from authenticated;

revoke execute on function public.savings_add_transaction(text, bigint, text, timestamptz, text) from public;
revoke execute on function public.savings_add_transaction(text, bigint, text, timestamptz, text) from anon;
revoke execute on function public.savings_add_transaction(text, bigint, text, timestamptz, text) from authenticated;
grant execute on function public.savings_add_transaction(text, bigint, text, timestamptz, text) to authenticated;

revoke execute on function public.savings_update_transaction(uuid, bigint, text, boolean) from public;
revoke execute on function public.savings_update_transaction(uuid, bigint, text, boolean) from anon;
revoke execute on function public.savings_update_transaction(uuid, bigint, text, boolean) from authenticated;
grant execute on function public.savings_update_transaction(uuid, bigint, text, boolean) to authenticated;

revoke execute on function public.savings_delete_transaction(uuid) from public;
revoke execute on function public.savings_delete_transaction(uuid) from anon;
revoke execute on function public.savings_delete_transaction(uuid) from authenticated;
grant execute on function public.savings_delete_transaction(uuid) to authenticated;

revoke execute on function public.savings_balance() from public;
revoke execute on function public.savings_balance() from anon;
revoke execute on function public.savings_balance() from authenticated;
grant execute on function public.savings_balance() to authenticated;

revoke execute on function public.savings_balance_before(date) from public;
revoke execute on function public.savings_balance_before(date) from anon;
revoke execute on function public.savings_balance_before(date) from authenticated;
grant execute on function public.savings_balance_before(date) to authenticated;

revoke execute on function public.savings_get(uuid) from public;
revoke execute on function public.savings_get(uuid) from anon;
revoke execute on function public.savings_get(uuid) from authenticated;
grant execute on function public.savings_get(uuid) to authenticated;

revoke execute on function public.savings_list_my(integer, integer) from public;
revoke execute on function public.savings_list_my(integer, integer) from anon;
revoke execute on function public.savings_list_my(integer, integer) from authenticated;
grant execute on function public.savings_list_my(integer, integer) to authenticated;

revoke execute on function public.savings_transactions_between(date, date) from public;
revoke execute on function public.savings_transactions_between(date, date) from anon;
revoke execute on function public.savings_transactions_between(date, date) from authenticated;
grant execute on function public.savings_transactions_between(date, date) to authenticated;
