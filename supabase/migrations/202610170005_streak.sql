create or replace function public.get_active_dates(p_limit integer default 2000)
returns setof date
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
  select distinct c.check_date
  from public.task_checklists c
  where c.user_id = v_uid
    and c.completed
  order by c.check_date desc
  limit least(greatest(coalesce(p_limit, 2000), 1), 5000);
end;
$$;

revoke execute on function public.get_active_dates(integer) from public;
revoke execute on function public.get_active_dates(integer) from anon;
revoke execute on function public.get_active_dates(integer) from authenticated;
grant execute on function public.get_active_dates(integer) to authenticated;
