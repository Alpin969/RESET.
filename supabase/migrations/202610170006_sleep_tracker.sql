create extension if not exists btree_gist with schema extensions;

create table if not exists public.sleep_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  sleep_start timestamptz not null,
  wake_time timestamptz not null,
  duration_minutes integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sleep_logs_wake_after_start check (wake_time > sleep_start),
  constraint sleep_logs_duration_range check (duration_minutes between 1 and 1440),
  constraint sleep_logs_no_overlap exclude using gist (
    user_id with =,
    tstzrange(sleep_start, wake_time, '[)') with &&
  )
);

create index if not exists sleep_logs_user_wake_idx
  on public.sleep_logs (user_id, wake_time desc);

create or replace function public.sleep_logs_compute_duration()
returns trigger
language plpgsql
as $$
begin
  new.duration_minutes := round(
    extract(epoch from (new.wake_time - new.sleep_start)) / 60.0
  )::integer;
  return new;
end;
$$;

drop trigger if exists sleep_logs_compute_duration on public.sleep_logs;
create trigger sleep_logs_compute_duration
  before insert or update on public.sleep_logs
  for each row
  execute function public.sleep_logs_compute_duration();

drop trigger if exists sleep_logs_set_updated_at on public.sleep_logs;
create trigger sleep_logs_set_updated_at
  before update on public.sleep_logs
  for each row
  execute function public.set_updated_at();

alter table public.sleep_logs enable row level security;

drop policy if exists sleep_select_own on public.sleep_logs;
create policy sleep_select_own
  on public.sleep_logs
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists sleep_insert_own on public.sleep_logs;
create policy sleep_insert_own
  on public.sleep_logs
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists sleep_update_own on public.sleep_logs;
create policy sleep_update_own
  on public.sleep_logs
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists sleep_delete_own on public.sleep_logs;
create policy sleep_delete_own
  on public.sleep_logs
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.sleep_validate_range(
  p_sleep_start timestamptz,
  p_wake_time timestamptz
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_minutes integer;
begin
  if p_sleep_start is null or p_wake_time is null then
    raise exception 'Waktu tidur dan bangun wajib diisi.';
  end if;

  if p_wake_time <= p_sleep_start then
    raise exception 'Waktu bangun harus setelah waktu mulai tidur.';
  end if;

  v_minutes := round(
    extract(epoch from (p_wake_time - p_sleep_start)) / 60.0
  )::integer;

  if v_minutes < 1 then
    raise exception 'Durasi tidur minimal 1 menit.';
  end if;

  if v_minutes > 1440 then
    raise exception 'Durasi tidur maksimal 24 jam.';
  end if;

  return v_minutes;
end;
$$;

create or replace function public.sleep_find_overlap(
  p_uid uuid,
  p_sleep_start timestamptz,
  p_wake_time timestamptz,
  p_exclude_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.sleep_logs l
    where l.user_id = p_uid
      and (p_exclude_id is null or l.id <> p_exclude_id)
      and l.sleep_start < p_wake_time
      and p_sleep_start < l.wake_time
  );
$$;

create or replace function public.sleep_create(
  p_sleep_start timestamptz,
  p_wake_time timestamptz
)
returns public.sleep_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_duration integer;
  v_log public.sleep_logs;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  v_duration := public.sleep_validate_range(p_sleep_start, p_wake_time);

  select * into v_log
  from public.sleep_logs
  where user_id = v_uid
    and sleep_start = p_sleep_start
    and wake_time = p_wake_time;

  if found then
    return v_log;
  end if;

  if public.sleep_find_overlap(v_uid, p_sleep_start, p_wake_time) then
    raise exception 'Catatan tidur ini bertumpang tindih dengan catatan lain.';
  end if;

  begin
    insert into public.sleep_logs (user_id, sleep_start, wake_time, duration_minutes)
    values (v_uid, p_sleep_start, p_wake_time, v_duration)
    returning * into v_log;
  exception
    when exclusion_violation then
      raise exception 'Catatan tidur ini bertumpang tindih dengan catatan lain.';
  end;

  return v_log;
end;
$$;

create or replace function public.sleep_update(
  p_id uuid,
  p_sleep_start timestamptz,
  p_wake_time timestamptz
)
returns public.sleep_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_duration integer;
  v_log public.sleep_logs;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_id is null then
    raise exception 'Catatan tidur tidak ditemukan.';
  end if;

  v_duration := public.sleep_validate_range(p_sleep_start, p_wake_time);

  if public.sleep_find_overlap(v_uid, p_sleep_start, p_wake_time, p_id) then
    raise exception 'Catatan tidur ini bertumpang tindih dengan catatan lain.';
  end if;

  begin
    update public.sleep_logs
    set sleep_start = p_sleep_start,
        wake_time = p_wake_time,
        duration_minutes = v_duration
    where id = p_id
      and user_id = v_uid
    returning * into v_log;
  exception
    when exclusion_violation then
      raise exception 'Catatan tidur ini bertumpang tindih dengan catatan lain.';
  end;

  if not found then
    raise exception 'Catatan tidur tidak ditemukan.';
  end if;

  return v_log;
end;
$$;

create or replace function public.sleep_delete(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  delete from public.sleep_logs
  where id = p_id
    and user_id = v_uid;

  if not found then
    raise exception 'Catatan tidur tidak ditemukan.';
  end if;
end;
$$;

create or replace function public.sleep_get(p_id uuid)
returns public.sleep_logs
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_log public.sleep_logs;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  select * into v_log
  from public.sleep_logs
  where id = p_id
    and user_id = v_uid;

  if not found then
    raise exception 'Catatan tidur tidak ditemukan.';
  end if;

  return v_log;
end;
$$;

create or replace function public.sleep_latest()
returns public.sleep_logs
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_log public.sleep_logs;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  select * into v_log
  from public.sleep_logs
  where user_id = v_uid
  order by wake_time desc
  limit 1;

  return v_log;
end;
$$;

create or replace function public.sleep_list_my(
  p_limit integer default 400,
  p_offset integer default 0
)
returns table (
  id uuid,
  user_id uuid,
  sleep_start timestamptz,
  wake_time timestamptz,
  duration_minutes integer,
  wake_local_date date,
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
    l.id,
    l.user_id,
    l.sleep_start,
    l.wake_time,
    l.duration_minutes,
    (timezone(public.user_timezone(v_uid), l.wake_time))::date,
    l.created_at,
    l.updated_at
  from public.sleep_logs l
  where l.user_id = v_uid
  order by l.wake_time desc, l.id desc
  limit least(greatest(coalesce(p_limit, 400), 1), 1000)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.sleep_logs_between(p_from date, p_to date)
returns table (
  id uuid,
  user_id uuid,
  sleep_start timestamptz,
  wake_time timestamptz,
  duration_minutes integer,
  wake_local_date date,
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
    l.id,
    l.user_id,
    l.sleep_start,
    l.wake_time,
    l.duration_minutes,
    (timezone(public.user_timezone(v_uid), l.wake_time))::date,
    l.created_at,
    l.updated_at
  from public.sleep_logs l
  where l.user_id = v_uid
    and (timezone(public.user_timezone(v_uid), l.wake_time))::date between p_from and p_to
  order by l.wake_time desc, l.id desc;
end;
$$;

revoke execute on function public.sleep_validate_range(timestamptz, timestamptz) from public;
revoke execute on function public.sleep_validate_range(timestamptz, timestamptz) from anon;
revoke execute on function public.sleep_validate_range(timestamptz, timestamptz) from authenticated;

revoke execute on function public.sleep_find_overlap(uuid, timestamptz, timestamptz, uuid) from public;
revoke execute on function public.sleep_find_overlap(uuid, timestamptz, timestamptz, uuid) from anon;
revoke execute on function public.sleep_find_overlap(uuid, timestamptz, timestamptz, uuid) from authenticated;

revoke execute on function public.sleep_create(timestamptz, timestamptz) from public;
revoke execute on function public.sleep_create(timestamptz, timestamptz) from anon;
revoke execute on function public.sleep_create(timestamptz, timestamptz) from authenticated;
grant execute on function public.sleep_create(timestamptz, timestamptz) to authenticated;

revoke execute on function public.sleep_update(uuid, timestamptz, timestamptz) from public;
revoke execute on function public.sleep_update(uuid, timestamptz, timestamptz) from anon;
revoke execute on function public.sleep_update(uuid, timestamptz, timestamptz) from authenticated;
grant execute on function public.sleep_update(uuid, timestamptz, timestamptz) to authenticated;

revoke execute on function public.sleep_delete(uuid) from public;
revoke execute on function public.sleep_delete(uuid) from anon;
revoke execute on function public.sleep_delete(uuid) from authenticated;
grant execute on function public.sleep_delete(uuid) to authenticated;

revoke execute on function public.sleep_get(uuid) from public;
revoke execute on function public.sleep_get(uuid) from anon;
revoke execute on function public.sleep_get(uuid) from authenticated;
grant execute on function public.sleep_get(uuid) to authenticated;

revoke execute on function public.sleep_latest() from public;
revoke execute on function public.sleep_latest() from anon;
revoke execute on function public.sleep_latest() from authenticated;
grant execute on function public.sleep_latest() to authenticated;

revoke execute on function public.sleep_list_my(integer, integer) from public;
revoke execute on function public.sleep_list_my(integer, integer) from anon;
revoke execute on function public.sleep_list_my(integer, integer) from authenticated;
grant execute on function public.sleep_list_my(integer, integer) to authenticated;

revoke execute on function public.sleep_logs_between(date, date) from public;
revoke execute on function public.sleep_logs_between(date, date) from anon;
revoke execute on function public.sleep_logs_between(date, date) from authenticated;
grant execute on function public.sleep_logs_between(date, date) to authenticated;
