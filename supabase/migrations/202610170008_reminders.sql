alter table public.profiles
  add column if not exists notifications_enabled boolean not null default true;

alter table public.profiles
  add column if not exists reminder_default_time time not null default '08:00';

create table if not exists public.notification_push_config (
  id integer primary key,
  vapid_public_key text not null default '',
  updated_at timestamptz not null default now(),
  constraint notification_push_config_single_row check (id = 1)
);

insert into public.notification_push_config (id)
values (1)
on conflict (id) do nothing;

create or replace function public.reminder_days_valid(p_frequency text, p_days smallint[])
returns boolean
language sql
immutable
as $$
  select case
    when p_frequency = 'daily' then
      p_days is null
    when p_frequency = 'specific_days' then
      p_days is not null
      and coalesce(array_length(p_days, 1), 0) between 1 and 7
      and p_days <@ array[0, 1, 2, 3, 4, 5, 6]::smallint[]
      and (select count(distinct d) from unnest(p_days) d) = array_length(p_days, 1)
    else false
  end;
$$;

create table if not exists public.task_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid not null references public.user_tasks (id) on delete cascade,
  time_of_day time not null,
  frequency text not null default 'daily',
  days_of_week smallint[],
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint task_reminders_frequency_valid check (frequency in ('daily', 'specific_days')),
  constraint task_reminders_days_valid check (public.reminder_days_valid(frequency, days_of_week)),
  constraint task_reminders_unique_time unique (task_id, time_of_day)
);

alter table public.task_reminders
  drop constraint if exists task_reminders_days_valid;

alter table public.task_reminders
  add constraint task_reminders_days_valid
  check (public.reminder_days_valid(frequency, days_of_week));

create index if not exists task_reminders_user_idx
  on public.task_reminders (user_id, created_at);

create index if not exists task_reminders_enabled_idx
  on public.task_reminders (user_id)
  where is_enabled;

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  device_name text,
  user_agent text,
  failure_count integer not null default 0,
  last_success_at timestamptz,
  expired_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_subscriptions_endpoint_valid check (endpoint ~ '^https://'),
  constraint push_subscriptions_keys_valid check (
    char_length(p256dh) between 20 and 200
    and char_length(auth) between 20 and 200
  ),
  constraint push_subscriptions_device_name_valid check (
    device_name is null or char_length(device_name) <= 100
  ),
  constraint push_subscriptions_user_agent_valid check (
    user_agent is null or char_length(user_agent) <= 400
  )
);

create index if not exists push_subscriptions_user_idx
  on public.push_subscriptions (user_id)
  where expired_at is null;

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  reminder_id uuid references public.task_reminders (id) on delete set null,
  subscription_id uuid references public.push_subscriptions (id) on delete set null,
  idempotency_key text not null unique,
  local_date date not null,
  scheduled_for timestamptz not null,
  payload jsonb not null,
  status text not null default 'pending',
  attempt integer not null default 0,
  locked_by text,
  locked_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_deliveries_status_valid check (
    status in ('pending', 'sending', 'sent', 'skipped', 'failed')
  ),
  constraint notification_deliveries_attempt_valid check (attempt between 0 and 10)
);

create index if not exists notification_deliveries_due_idx
  on public.notification_deliveries (scheduled_for)
  where status in ('pending', 'failed');

create index if not exists notification_deliveries_user_idx
  on public.notification_deliveries (user_id, created_at);

drop trigger if exists task_reminders_set_updated_at on public.task_reminders;
create trigger task_reminders_set_updated_at
  before update on public.task_reminders
  for each row
  execute function public.set_updated_at();

drop trigger if exists push_subscriptions_set_updated_at on public.push_subscriptions;
create trigger push_subscriptions_set_updated_at
  before update on public.push_subscriptions
  for each row
  execute function public.set_updated_at();

drop trigger if exists notification_deliveries_set_updated_at on public.notification_deliveries;
create trigger notification_deliveries_set_updated_at
  before update on public.notification_deliveries
  for each row
  execute function public.set_updated_at();

alter table public.task_reminders enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.notification_push_config enable row level security;

drop policy if exists reminders_select_own on public.task_reminders;
create policy reminders_select_own
  on public.task_reminders
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists push_subscriptions_select_own on public.push_subscriptions;
create policy push_subscriptions_select_own
  on public.push_subscriptions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists push_config_select on public.notification_push_config;
create policy push_config_select
  on public.notification_push_config
  for select
  to authenticated
  using (true);

create or replace function public.validate_reminder_schedule(p_frequency text, p_days smallint[])
returns void
language plpgsql
set search_path = public
as $$
begin
  if p_frequency is null or p_frequency not in ('daily', 'specific_days') then
    raise exception 'Frekuensi reminder tidak valid.';
  end if;

  if p_frequency = 'daily' then
    if p_days is not null then
      raise exception 'Frekuensi harian tidak memerlukan daftar hari.';
    end if;
    return;
  end if;

  if p_days is null
    or coalesce(array_length(p_days, 1), 0) < 1
    or coalesce(array_length(p_days, 1), 0) > 7
    or not (p_days <@ array[0, 1, 2, 3, 4, 5, 6]::smallint[])
    or (select count(distinct d) from unnest(p_days) d) <> array_length(p_days, 1) then
    raise exception 'Daftar hari tidak valid.';
  end if;
end;
$$;

create or replace function public.reminder_list_my()
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', r.id,
    'user_id', r.user_id,
    'task_id', r.task_id,
    'task_name', t.name,
    'task_is_active', t.is_active,
    'task_deleted', t.deleted_at is not null,
    'time_of_day', to_char(r.time_of_day, 'HH24:MI'),
    'frequency', r.frequency,
    'days_of_week', coalesce(r.days_of_week, '{}'::smallint[]),
    'is_enabled', r.is_enabled,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  )
  from public.task_reminders r
  join public.user_tasks t on t.id = r.task_id
  where r.user_id = auth.uid()
  order by r.time_of_day asc, r.created_at asc;
$$;

create or replace function public.reminder_create(
  p_task_id uuid,
  p_time time,
  p_frequency text default 'daily',
  p_days smallint[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_frequency text := coalesce(p_frequency, 'daily');
  v_reminder public.task_reminders;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_task_id is null or p_time is null then
    raise exception 'Task dan waktu wajib diisi.';
  end if;

  if p_time < time '00:00' or p_time > time '23:59' then
    raise exception 'Waktu reminder tidak valid.';
  end if;

  perform public.validate_reminder_schedule(v_frequency, p_days);

  if not exists (
    select 1 from public.user_tasks
    where id = p_task_id
      and user_id = v_uid
      and deleted_at is null
  ) then
    raise exception 'Task tidak ditemukan.';
  end if;

  if (
    select count(*)
    from public.task_reminders
    where user_id = v_uid
      and task_id = p_task_id
  ) >= 5 then
    raise exception 'Maksimal 5 reminder per task.';
  end if;

  if (select count(*) from public.task_reminders where user_id = v_uid) >= 50 then
    raise exception 'Maksimal 50 reminder.';
  end if;

  insert into public.task_reminders (user_id, task_id, time_of_day, frequency, days_of_week)
  values (v_uid, p_task_id, p_time, v_frequency, p_days)
  returning * into v_reminder;

  return (
    select jsonb_build_object(
      'id', r.id,
      'user_id', r.user_id,
      'task_id', r.task_id,
      'task_name', t.name,
      'task_is_active', t.is_active,
      'task_deleted', t.deleted_at is not null,
      'time_of_day', to_char(r.time_of_day, 'HH24:MI'),
      'frequency', r.frequency,
      'days_of_week', coalesce(r.days_of_week, '{}'::smallint[]),
      'is_enabled', r.is_enabled,
      'created_at', r.created_at,
      'updated_at', r.updated_at
    )
    from public.task_reminders r
    join public.user_tasks t on t.id = r.task_id
    where r.id = v_reminder.id
  );
end;
$$;

create or replace function public.reminder_update(
  p_reminder_id uuid,
  p_time time default null,
  p_frequency text default null,
  p_days smallint[] default null,
  p_is_enabled boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_reminder public.task_reminders;
  v_frequency text;
  v_days smallint[];
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  select * into v_reminder
  from public.task_reminders
  where id = p_reminder_id
    and user_id = v_uid
  for update;

  if not found then
    raise exception 'Reminder tidak ditemukan.';
  end if;

  if p_time is not null and (p_time < time '00:00' or p_time > time '23:59') then
    raise exception 'Waktu reminder tidak valid.';
  end if;

  v_frequency := coalesce(p_frequency, v_reminder.frequency);

  if v_frequency = 'daily' then
    v_days := null;
  else
    v_days := coalesce(p_days, v_reminder.days_of_week);
  end if;

  perform public.validate_reminder_schedule(v_frequency, v_days);

  if exists (
    select 1 from public.task_reminders
    where task_id = v_reminder.task_id
      and time_of_day = coalesce(p_time, v_reminder.time_of_day)
      and id <> v_reminder.id
  ) then
    raise exception 'Sudah ada reminder dengan waktu tersebut untuk task ini.';
  end if;

  update public.task_reminders
  set time_of_day = coalesce(p_time, time_of_day),
      frequency = v_frequency,
      days_of_week = v_days,
      is_enabled = coalesce(p_is_enabled, is_enabled)
  where id = v_reminder.id
  returning * into v_reminder;

  delete from public.notification_deliveries
  where reminder_id = v_reminder.id
    and status in ('pending', 'failed');

  return (
    select jsonb_build_object(
      'id', r.id,
      'user_id', r.user_id,
      'task_id', r.task_id,
      'task_name', t.name,
      'task_is_active', t.is_active,
      'task_deleted', t.deleted_at is not null,
      'time_of_day', to_char(r.time_of_day, 'HH24:MI'),
      'frequency', r.frequency,
      'days_of_week', coalesce(r.days_of_week, '{}'::smallint[]),
      'is_enabled', r.is_enabled,
      'created_at', r.created_at,
      'updated_at', r.updated_at
    )
    from public.task_reminders r
    join public.user_tasks t on t.id = r.task_id
    where r.id = v_reminder.id
  );
end;
$$;

create or replace function public.reminder_toggle(p_reminder_id uuid, p_is_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_reminder public.task_reminders;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan.';
  end if;

  if p_is_enabled is null then
    raise exception 'Status reminder wajib diisi.';
  end if;

  update public.task_reminders
  set is_enabled = p_is_enabled
  where id = p_reminder_id
    and user_id = v_uid
  returning * into v_reminder;

  if not found then
    raise exception 'Reminder tidak ditemukan.';
  end if;

  if not p_is_enabled then
    delete from public.notification_deliveries
    where reminder_id = v_reminder.id
      and status in ('pending', 'failed');
  end if;

  return (
    select jsonb_build_object(
      'id', r.id,
      'user_id', r.user_id,
      'task_id', r.task_id,
      'task_name', t.name,
      'task_is_active', t.is_active,
      'task_deleted', t.deleted_at is not null,
      'time_of_day', to_char(r.time_of_day, 'HH24:MI'),
      'frequency', r.frequency,
      'days_of_week', coalesce(r.days_of_week, '{}'::smallint[]),
      'is_enabled', r.is_enabled,
      'created_at', r.created_at,
      'updated_at', r.updated_at
    )
    from public.task_reminders r
    join public.user_tasks t on t.id = r.task_id
    where r.id = v_reminder.id
  );
end;
$$;

create or replace function public.reminder_delete(p_reminder_id uuid)
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

  delete from public.task_reminders
  where id = p_reminder_id
    and user_id = v_uid;

  if not found then
    raise exception 'Reminder tidak ditemukan.';
  end if;
end;
$$;

create or replace function public.push_register(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_device_name text default null,
  p_user_agent text default null
)
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

  if p_endpoint is null or p_endpoint !~ '^https://' or char_length(p_endpoint) > 2048 then
    raise exception 'Endpoint subscription tidak valid.';
  end if;

  if p_p256dh is null or char_length(p_p256dh) < 20 or char_length(p_p256dh) > 200 then
    raise exception 'Kunci p256dh tidak valid.';
  end if;

  if p_auth is null or char_length(p_auth) < 20 or char_length(p_auth) > 200 then
    raise exception 'Kunci auth tidak valid.';
  end if;

  if exists (
    select 1 from public.push_subscriptions
    where endpoint = p_endpoint
      and user_id <> v_uid
  ) then
    raise exception 'Subscription tidak valid.';
  end if;

  if not exists (
    select 1 from public.push_subscriptions
    where endpoint = p_endpoint
  ) and (
    select count(*)
    from public.push_subscriptions
    where user_id = v_uid
      and expired_at is null
  ) >= 10 then
    raise exception 'Maksimal 10 perangkat.';
  end if;

  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, device_name, user_agent)
  values (v_uid, p_endpoint, p_p256dh, p_auth, nullif(btrim(p_device_name), ''), nullif(btrim(p_user_agent), ''))
  on conflict (endpoint) do update
    set p256dh = excluded.p256dh,
        auth = excluded.auth,
        device_name = excluded.device_name,
        user_agent = excluded.user_agent,
        failure_count = 0,
        expired_at = null,
        updated_at = now()
    where public.push_subscriptions.user_id = v_uid;
end;
$$;

create or replace function public.push_unregister(p_endpoint text)
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

  delete from public.push_subscriptions
  where user_id = v_uid
    and endpoint = p_endpoint;
end;
$$;

create or replace function public.push_unregister_all()
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

  delete from public.push_subscriptions
  where user_id = v_uid;
end;
$$;

create or replace function public.push_list_my()
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', s.id,
    'endpoint', s.endpoint,
    'device_name', s.device_name,
    'user_agent', s.user_agent,
    'last_success_at', s.last_success_at,
    'created_at', s.created_at
  )
  from public.push_subscriptions s
  where s.user_id = auth.uid()
    and s.expired_at is null
  order by s.created_at desc;
$$;

create or replace function public.push_public_key_get()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select vapid_public_key from public.notification_push_config where id = 1),
    ''
  );
$$;

create or replace function public.notification_prefs_get()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'notifications_enabled', p.notifications_enabled,
        'reminder_default_time', to_char(p.reminder_default_time, 'HH24:MI'),
        'timezone', p.timezone
      )
      from public.profiles p
      where p.id = auth.uid()
    ),
    '{}'::jsonb
  );
$$;

create or replace function public.notification_prefs_update(
  p_enabled boolean default null,
  p_default_time time default null
)
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

  if p_enabled is null and p_default_time is null then
    raise exception 'Tidak ada perubahan preferensi.';
  end if;

  update public.profiles
  set notifications_enabled = coalesce(p_enabled, notifications_enabled),
      reminder_default_time = coalesce(p_default_time, reminder_default_time)
  where id = v_uid;

  if not found then
    raise exception 'Profil tidak ditemukan.';
  end if;
end;
$$;

create or replace function public.reminder_enqueue_due()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created integer := 0;
  v_count integer;
  v_scheduled timestamptz;
  r record;
begin
  for r in
    select
      re.id as reminder_id,
      re.user_id,
      re.task_id,
      re.time_of_day,
      re.frequency,
      re.days_of_week,
      t.name as task_name,
      p.timezone as timezone,
      (timezone(p.timezone, now()))::date as local_date
    from public.task_reminders re
    join public.user_tasks t
      on t.id = re.task_id
      and t.deleted_at is null
      and t.is_active
    join public.profiles p on p.id = re.user_id
    where re.is_enabled
      and p.notifications_enabled
  loop
    if r.frequency = 'specific_days'
      and not (r.days_of_week @> array[extract(dow from r.local_date)::int]::smallint[]) then
      continue;
    end if;

    v_scheduled := ((r.local_date::timestamp + r.time_of_day) at time zone r.timezone);

    if v_scheduled > now() or v_scheduled < now() - interval '4 hours' then
      continue;
    end if;

    if exists (
      select 1 from public.task_checklists c
      where c.task_id = r.task_id
        and c.check_date = r.local_date
        and c.completed
    ) then
      continue;
    end if;

    insert into public.notification_deliveries
      (user_id, reminder_id, subscription_id, idempotency_key, local_date, scheduled_for, payload)
    select
      r.user_id,
      r.reminder_id,
      s.id,
      r.reminder_id::text || '|' || r.local_date::text || '|' || to_char(r.time_of_day, 'HH24:MI') || '|' || s.id::text,
      r.local_date,
      v_scheduled,
      jsonb_build_object(
        'title', 'Pengingat: ' || r.task_name,
        'body', 'Sudah waktunya menyelesaikan tugasmu di RESET.',
        'url', '/?task=' || r.task_id
      )
    from public.push_subscriptions s
    where s.user_id = r.user_id
      and s.expired_at is null
    on conflict (idempotency_key) do nothing;

    get diagnostics v_count = row_count;
    v_created := v_created + v_count;
  end loop;

  return v_created;
end;
$$;

create or replace function public.reminder_claim_batch(
  p_limit integer default 10,
  p_worker text default 'worker'
)
returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'Batch tidak valid.';
  end if;

  with claimed as (
    select d.id
    from public.notification_deliveries d
    where d.attempt < 3
      and d.scheduled_for <= now()
      and (
        (
          d.status in ('pending', 'failed')
          and (d.locked_at is null or d.locked_at < now() - interval '15 minutes')
        )
        or (
          d.status = 'sending'
          and d.locked_at < now() - interval '15 minutes'
        )
      )
    order by d.scheduled_for asc
    limit p_limit
    for update skip locked
  )
  update public.notification_deliveries d
  set status = 'sending',
      attempt = d.attempt + 1,
      locked_by = coalesce(nullif(btrim(p_worker), ''), 'worker'),
      locked_at = now(),
      updated_at = now()
  from claimed c
  where d.id = c.id
  returning d.id into v_ids;

  return query
  select jsonb_build_object(
    'id', d.id,
    'user_id', d.user_id,
    'reminder_id', d.reminder_id,
    'subscription_id', d.subscription_id,
    'local_date', d.local_date,
    'scheduled_for', d.scheduled_for,
    'attempt', d.attempt,
    'payload', d.payload,
    'endpoint', s.endpoint,
    'p256dh', s.p256dh,
    'auth', s.auth,
    'reminder_ok', coalesce(r.is_enabled, false),
    'task_ok', coalesce(t.deleted_at is null and t.is_active, false),
    'task_done', exists (
      select 1 from public.task_checklists c
      where c.task_id = r.task_id
        and c.check_date = d.local_date
        and c.completed
    )
  )
  from public.notification_deliveries d
  left join public.push_subscriptions s on s.id = d.subscription_id
  left join public.task_reminders r on r.id = d.reminder_id
  left join public.user_tasks t on t.id = r.task_id
  where d.id = any (v_ids);
end;
$$;

create or replace function public.reminder_mark_result(
  p_delivery_id uuid,
  p_status text,
  p_error text default null,
  p_permanent boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_status is null or p_status not in ('sent', 'skipped', 'failed') then
    raise exception 'Status hasil tidak valid.';
  end if;

  update public.notification_deliveries
  set status = case
        when p_status = 'sent' then 'sent'
        when p_status = 'skipped' then 'skipped'
        when coalesce(p_permanent, false) or attempt >= 3 then 'failed'
        else 'pending'
      end,
      sent_at = case when p_status = 'sent' then now() else sent_at end,
      last_error = left(coalesce(p_error, ''), 500),
      locked_by = null,
      locked_at = null,
      updated_at = now()
  where id = p_delivery_id
    and status = 'sending';
end;
$$;

create or replace function public.reminder_expire_subscription(p_subscription_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_subscription_id is null then
    raise exception 'Subscription wajib diisi.';
  end if;

  update public.push_subscriptions
  set expired_at = coalesce(expired_at, now()),
      updated_at = now()
  where id = p_subscription_id
    and expired_at is null;
end;
$$;

revoke execute on function public.validate_reminder_schedule(text, smallint[]) from public;
revoke execute on function public.validate_reminder_schedule(text, smallint[]) from anon;
revoke execute on function public.validate_reminder_schedule(text, smallint[]) from authenticated;

revoke execute on function public.reminder_list_my() from public;
revoke execute on function public.reminder_list_my() from anon;
revoke execute on function public.reminder_list_my() from authenticated;
grant execute on function public.reminder_list_my() to authenticated;

revoke execute on function public.reminder_create(uuid, time, text, smallint[]) from public;
revoke execute on function public.reminder_create(uuid, time, text, smallint[]) from anon;
revoke execute on function public.reminder_create(uuid, time, text, smallint[]) from authenticated;
grant execute on function public.reminder_create(uuid, time, text, smallint[]) to authenticated;

revoke execute on function public.reminder_update(uuid, time, text, smallint[], boolean) from public;
revoke execute on function public.reminder_update(uuid, time, text, smallint[], boolean) from anon;
revoke execute on function public.reminder_update(uuid, time, text, smallint[], boolean) from authenticated;
grant execute on function public.reminder_update(uuid, time, text, smallint[], boolean) to authenticated;

revoke execute on function public.reminder_toggle(uuid, boolean) from public;
revoke execute on function public.reminder_toggle(uuid, boolean) from anon;
revoke execute on function public.reminder_toggle(uuid, boolean) from authenticated;
grant execute on function public.reminder_toggle(uuid, boolean) to authenticated;

revoke execute on function public.reminder_delete(uuid) from public;
revoke execute on function public.reminder_delete(uuid) from anon;
revoke execute on function public.reminder_delete(uuid) from authenticated;
grant execute on function public.reminder_delete(uuid) to authenticated;

revoke execute on function public.push_register(text, text, text, text, text) from public;
revoke execute on function public.push_register(text, text, text, text, text) from anon;
revoke execute on function public.push_register(text, text, text, text, text) from authenticated;
grant execute on function public.push_register(text, text, text, text, text) to authenticated;

revoke execute on function public.push_unregister(text) from public;
revoke execute on function public.push_unregister(text) from anon;
revoke execute on function public.push_unregister(text) from authenticated;
grant execute on function public.push_unregister(text) to authenticated;

revoke execute on function public.push_unregister_all() from public;
revoke execute on function public.push_unregister_all() from anon;
revoke execute on function public.push_unregister_all() from authenticated;
grant execute on function public.push_unregister_all() to authenticated;

revoke execute on function public.push_list_my() from public;
revoke execute on function public.push_list_my() from anon;
revoke execute on function public.push_list_my() from authenticated;
grant execute on function public.push_list_my() to authenticated;

revoke execute on function public.push_public_key_get() from public;
revoke execute on function public.push_public_key_get() from anon;
revoke execute on function public.push_public_key_get() from authenticated;
grant execute on function public.push_public_key_get() to authenticated;

revoke execute on function public.notification_prefs_get() from public;
revoke execute on function public.notification_prefs_get() from anon;
revoke execute on function public.notification_prefs_get() from authenticated;
grant execute on function public.notification_prefs_get() to authenticated;

revoke execute on function public.notification_prefs_update(boolean, time) from public;
revoke execute on function public.notification_prefs_update(boolean, time) from anon;
revoke execute on function public.notification_prefs_update(boolean, time) from authenticated;
grant execute on function public.notification_prefs_update(boolean, time) to authenticated;

revoke execute on function public.reminder_enqueue_due() from public;
revoke execute on function public.reminder_enqueue_due() from anon;
revoke execute on function public.reminder_enqueue_due() from authenticated;
grant execute on function public.reminder_enqueue_due() to service_role;

revoke execute on function public.reminder_claim_batch(integer, text) from public;
revoke execute on function public.reminder_claim_batch(integer, text) from anon;
revoke execute on function public.reminder_claim_batch(integer, text) from authenticated;
grant execute on function public.reminder_claim_batch(integer, text) to service_role;

revoke execute on function public.reminder_mark_result(uuid, text, text, boolean) from public;
revoke execute on function public.reminder_mark_result(uuid, text, text, boolean) from anon;
revoke execute on function public.reminder_mark_result(uuid, text, text, boolean) from authenticated;
grant execute on function public.reminder_mark_result(uuid, text, text, boolean) to service_role;

revoke execute on function public.reminder_expire_subscription(uuid) from public;
revoke execute on function public.reminder_expire_subscription(uuid) from anon;
revoke execute on function public.reminder_expire_subscription(uuid) from authenticated;
grant execute on function public.reminder_expire_subscription(uuid) to service_role;
