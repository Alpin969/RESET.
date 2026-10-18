alter table public.profiles
  add column if not exists motivation text;

alter table public.profiles
  add column if not exists age_group text;

alter table public.profiles drop constraint if exists profiles_motivation_length;
alter table public.profiles
  add constraint profiles_motivation_length
  check (motivation is null or char_length(motivation) <= 160);

alter table public.profiles drop constraint if exists profiles_age_group_allowed;
alter table public.profiles
  add constraint profiles_age_group_allowed
  check (age_group is null or age_group in ('13-17', '18+'));

drop function if exists public.is_username_available(text);

create or replace function public.is_username_available(p_username text, p_exclude_id uuid default null)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select not exists (
    select 1
    from public.profiles
    where username = lower(trim(p_username))
      and (p_exclude_id is null or id <> p_exclude_id)
  );
$$;

revoke execute on function public.is_username_available(text, uuid) from public;
revoke execute on function public.is_username_available(text, uuid) from anon;
revoke execute on function public.is_username_available(text, uuid) from authenticated;
grant execute on function public.is_username_available(text, uuid) to anon;
grant execute on function public.is_username_available(text, uuid) to authenticated;
