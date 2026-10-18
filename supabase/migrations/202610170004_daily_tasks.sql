alter table public.profiles
  add column if not exists timezone text not null default 'Asia/Jakarta';

alter table public.profiles drop constraint if exists profiles_timezone_valid;
alter table public.profiles
  add constraint profiles_timezone_valid
  check (char_length(timezone) between 1 and 64 and timezone ~ '^[A-Za-z0-9_+/-]+$');

create or replace function public.validate_profile_timezone()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.timezone is distinct from old.timezone then
    if not exists (
      select 1 from pg_timezone_names where name = new.timezone
    ) then
      raise exception 'Timezone IANA tidak valid: %', new.timezone;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function public.validate_profile_timezone() from public;
revoke execute on function public.validate_profile_timezone() from anon;
revoke execute on function public.validate_profile_timezone() from authenticated;

drop trigger if exists profiles_validate_timezone on public.profiles;
create trigger profiles_validate_timezone
  before insert or update on public.profiles
  for each row
  execute function public.validate_profile_timezone();

create table if not exists public.user_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  icon text,
  position integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint user_tasks_name_length check (char_length(btrim(name)) between 1 and 100)
);

create index if not exists user_tasks_user_active_idx
  on public.user_tasks (user_id, position)
  where deleted_at is null;

create table if not exists public.task_checklists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid not null references public.user_tasks (id) on delete cascade,
  check_date date not null,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint task_checklists_unique_task_date unique (task_id, check_date)
);

create index if not exists task_checklists_user_date_idx
  on public.task_checklists (user_id, check_date);

create table if not exists public.task_daily_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid not null references public.user_tasks (id) on delete cascade,
  check_date date not null,
  name text not null,
  icon text,
  position integer not null default 0,
  is_active boolean not null default true,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint task_daily_snapshots_unique_task_date unique (task_id, check_date),
  constraint task_daily_snapshots_name_length check (char_length(btrim(name)) between 1 and 100)
);

create index if not exists task_daily_snapshots_user_date_idx
  on public.task_daily_snapshots (user_id, check_date);

drop trigger if exists user_tasks_set_updated_at on public.user_tasks;
create trigger user_tasks_set_updated_at
  before update on public.user_tasks
  for each row
  execute function public.set_updated_at();

drop trigger if exists task_checklists_set_updated_at on public.task_checklists;
create trigger task_checklists_set_updated_at
  before update on public.task_checklists
  for each row
  execute function public.set_updated_at();

drop trigger if exists task_daily_snapshots_set_updated_at on public.task_daily_snapshots;
create trigger task_daily_snapshots_set_updated_at
  before update on public.task_daily_snapshots
  for each row
  execute function public.set_updated_at();

alter table public.user_tasks enable row level security;
alter table public.task_checklists enable row level security;
alter table public.task_daily_snapshots enable row level security;

drop policy if exists tasks_select_own on public.user_tasks;
create policy tasks_select_own
  on public.user_tasks
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists tasks_insert_own on public.user_tasks;
create policy tasks_insert_own
  on public.user_tasks
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists tasks_update_own on public.user_tasks;
create policy tasks_update_own
  on public.user_tasks
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists checklists_select_own on public.task_checklists;
create policy checklists_select_own
  on public.task_checklists
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists checklists_insert_own on public.task_checklists;
create policy checklists_insert_own
  on public.task_checklists
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists checklists_update_own on public.task_checklists;
create policy checklists_update_own
  on public.task_checklists
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists snapshots_select_own on public.task_daily_snapshots;
create policy snapshots_select_own
  on public.task_daily_snapshots
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists snapshots_insert_own on public.task_daily_snapshots;
create policy snapshots_insert_own
  on public.task_daily_snapshots
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists snapshots_update_own on public.task_daily_snapshots;
create policy snapshots_update_own
  on public.task_daily_snapshots
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function public.user_timezone(p_uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select t.timezone from public.profiles t where t.id = p_uid),
    'Asia/Jakarta'
  );
$$;

create or replace function public.local_date(p_uid uuid)
returns date
language sql
stable
security definer
set search_path = public
as $$
  select (timezone(public.user_timezone(p_uid), now()))::date;
$$;

create or replace function public.get_local_today()
returns date
language sql
stable
security definer
set search_path = public
as $$
  select public.local_date(auth.uid());
$$;

create or replace function public.task_ensure_snapshot(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  v_today := public.local_date(v_uid);

  if p_date is null then
    raise exception 'Tanggal wajib diisi.';
  end if;

  if p_date > v_today then
    raise exception 'Tanggal checklist tidak boleh di masa depan.';
  end if;

  insert into public.task_daily_snapshots
    (user_id, task_id, check_date, name, icon, position, is_active, completed, completed_at)
  select
    t.user_id,
    t.id,
    p_date,
    t.name,
    t.icon,
    t.position,
    t.is_active,
    coalesce(c.completed, false),
    c.completed_at
  from public.user_tasks t
  left join public.task_checklists c
    on c.task_id = t.id
    and c.check_date = p_date
  where t.user_id = v_uid
    and t.is_active
    and (timezone(public.user_timezone(v_uid), t.created_at))::date <= p_date
    and (
      t.deleted_at is null
      or (timezone(public.user_timezone(v_uid), t.deleted_at))::date > p_date
    )
  on conflict (task_id, check_date) do nothing;
end;
$$;

create or replace function public.task_list_my()
returns setof public.user_tasks
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.user_tasks
  where user_id = auth.uid()
    and deleted_at is null
    and is_active
  order by position asc, created_at asc;
$$;

create or replace function public.task_create(p_name text, p_icon text default null)
returns public.user_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text;
  v_position integer;
  v_today date;
  v_task public.user_tasks;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  v_name := coalesce(btrim(p_name), '');

  if char_length(v_name) < 1 or char_length(v_name) > 100 then
    raise exception 'Nama task 1-100 karakter.';
  end if;

  v_today := public.local_date(v_uid);

  perform 1 from public.user_tasks where user_id = v_uid for update;

  select coalesce(max(position), -1) + 1
  into v_position
  from public.user_tasks
  where user_id = v_uid
    and deleted_at is null;

  insert into public.user_tasks (user_id, name, icon, position)
  values (v_uid, v_name, nullif(btrim(p_icon), ''), v_position)
  returning * into v_task;

  perform public.task_ensure_snapshot(v_today);

  return v_task;
end;
$$;

create or replace function public.task_update(
  p_task_id uuid,
  p_name text default null,
  p_icon text default null,
  p_icon_changed boolean default false,
  p_is_active boolean default null
)
returns public.user_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_task public.user_tasks;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_name is not null then
    if char_length(btrim(p_name)) < 1 or char_length(btrim(p_name)) > 100 then
      raise exception 'Nama task 1-100 karakter.';
    end if;
  end if;

  update public.user_tasks
  set name = coalesce(nullif(btrim(p_name), ''), name),
      icon = case
        when p_icon_changed then nullif(btrim(p_icon), '')
        else icon
      end,
      is_active = coalesce(p_is_active, is_active)
  where id = p_task_id
    and user_id = v_uid
    and deleted_at is null
  returning * into v_task;

  if not found then
    raise exception 'Task tidak ditemukan.';
  end if;

  v_today := public.local_date(v_uid);

  perform public.task_ensure_snapshot(v_today);

  if v_task.is_active then
    update public.task_daily_snapshots
    set name = v_task.name,
        icon = v_task.icon,
        position = v_task.position,
        is_active = true
    where user_id = v_uid
      and task_id = p_task_id
      and check_date = v_today;
  else
    delete from public.task_daily_snapshots
    where user_id = v_uid
      and task_id = p_task_id
      and check_date = v_today;
  end if;

  return v_task;
end;
$$;

create or replace function public.task_delete(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  update public.user_tasks
  set deleted_at = now()
  where id = p_task_id
    and user_id = v_uid
    and deleted_at is null;

  if not found then
    raise exception 'Task tidak ditemukan.';
  end if;

  v_today := public.local_date(v_uid);

  delete from public.task_daily_snapshots
  where user_id = v_uid
    and task_id = p_task_id
    and check_date = v_today;
end;
$$;

create or replace function public.task_reorder(p_task_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_count integer;
  v_index integer;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  v_count := coalesce(array_length(p_task_ids, 1), 0);

  if v_count = 0 then
    raise exception 'Daftar urutan task tidak valid.';
  end if;

  if (select count(distinct x) from unnest(p_task_ids) x) <> v_count then
    raise exception 'Daftar urutan task tidak valid.';
  end if;

  if (
    select count(*)
    from public.user_tasks
    where user_id = v_uid
      and deleted_at is null
      and is_active
  ) <> v_count then
    raise exception 'Daftar urutan task tidak valid.';
  end if;

  if exists (
    select 1
    from unnest(p_task_ids) as x(id)
    where not exists (
      select 1
      from public.user_tasks t
      where t.id = x.id
        and t.user_id = v_uid
        and t.deleted_at is null
        and t.is_active
    )
  ) then
    raise exception 'Daftar urutan task tidak valid.';
  end if;

  v_today := public.local_date(v_uid);

  perform public.task_ensure_snapshot(v_today);

  for v_index in 1 .. v_count loop
    update public.user_tasks
    set position = v_index - 1
    where id = p_task_ids[v_index]
      and user_id = v_uid;

    update public.task_daily_snapshots
    set position = v_index - 1
    where user_id = v_uid
      and task_id = p_task_ids[v_index]
      and check_date = v_today;
  end loop;
end;
$$;

create or replace function public.task_set_completed(
  p_task_id uuid,
  p_check_date date,
  p_completed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_valid boolean;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_check_date is null or p_completed is null then
    raise exception 'Tanggal dan status wajib diisi.';
  end if;

  v_today := public.local_date(v_uid);

  if p_check_date > v_today then
    raise exception 'Tanggal checklist tidak boleh di masa depan.';
  end if;

  perform public.task_ensure_snapshot(p_check_date);

  select exists (
    select 1
    from public.user_tasks t
    where t.id = p_task_id
      and t.user_id = v_uid
      and t.deleted_at is null
      and t.is_active
      and (timezone(public.user_timezone(v_uid), t.created_at))::date <= p_check_date
  ) into v_valid;

  if not v_valid then
    raise exception 'Task tidak berlaku untuk tanggal tersebut.';
  end if;

  insert into public.task_checklists
    (user_id, task_id, check_date, completed, completed_at)
  values
    (
      v_uid,
      p_task_id,
      p_check_date,
      p_completed,
      case when p_completed then now() else null end
    )
  on conflict (task_id, check_date) do update
    set completed = excluded.completed,
        completed_at = case
          when excluded.completed then coalesce(public.task_checklists.completed_at, now())
          else null
        end,
        updated_at = now();

  update public.task_daily_snapshots
  set completed = p_completed,
      completed_at = case
        when p_completed then coalesce(public.task_daily_snapshots.completed_at, now())
        else null
      end,
      updated_at = now()
  where user_id = v_uid
    and task_id = p_task_id
    and check_date = p_check_date;
end;
$$;

revoke execute on function public.user_timezone(uuid) from public;
revoke execute on function public.user_timezone(uuid) from anon;
revoke execute on function public.user_timezone(uuid) from authenticated;
revoke execute on function public.local_date(uuid) from public;
revoke execute on function public.local_date(uuid) from anon;
revoke execute on function public.local_date(uuid) from authenticated;

revoke execute on function public.get_local_today() from public;
revoke execute on function public.get_local_today() from anon;
revoke execute on function public.get_local_today() from authenticated;
grant execute on function public.get_local_today() to authenticated;

revoke execute on function public.task_ensure_snapshot(date) from public;
revoke execute on function public.task_ensure_snapshot(date) from anon;
revoke execute on function public.task_ensure_snapshot(date) from authenticated;
grant execute on function public.task_ensure_snapshot(date) to authenticated;

revoke execute on function public.task_list_my() from public;
revoke execute on function public.task_list_my() from anon;
revoke execute on function public.task_list_my() from authenticated;
grant execute on function public.task_list_my() to authenticated;

revoke execute on function public.task_create(text, text) from public;
revoke execute on function public.task_create(text, text) from anon;
revoke execute on function public.task_create(text, text) from authenticated;
grant execute on function public.task_create(text, text) to authenticated;

revoke execute on function public.task_update(uuid, text, text, boolean, boolean) from public;
revoke execute on function public.task_update(uuid, text, text, boolean, boolean) from anon;
revoke execute on function public.task_update(uuid, text, text, boolean, boolean) from authenticated;
grant execute on function public.task_update(uuid, text, text, boolean, boolean) to authenticated;

revoke execute on function public.task_delete(uuid) from public;
revoke execute on function public.task_delete(uuid) from anon;
revoke execute on function public.task_delete(uuid) from authenticated;
grant execute on function public.task_delete(uuid) to authenticated;

revoke execute on function public.task_reorder(uuid[]) from public;
revoke execute on function public.task_reorder(uuid[]) from anon;
revoke execute on function public.task_reorder(uuid[]) from authenticated;
grant execute on function public.task_reorder(uuid[]) to authenticated;

revoke execute on function public.task_set_completed(uuid, date, boolean) from public;
revoke execute on function public.task_set_completed(uuid, date, boolean) from anon;
revoke execute on function public.task_set_completed(uuid, date, boolean) from authenticated;
grant execute on function public.task_set_completed(uuid, date, boolean) to authenticated;
