-- Modul 3 — skrip verifikasi manual untuk pengujian live.
-- SKRIP INI BELUM DIJALANKAN pada sesi pengembangan. Jalankan setelah
-- migration 202610170001..0004 sukses di project Supabase kamu.
--
-- Persiapan:
-- 1. Buat dua akun lewat aplikasi (verifikasi email), misal alice@mail.com dan bob@mail.com.
-- 2. Ambil kedua user id:
--      select id, email from auth.users order by created_at desc limit 5;
-- 3. Cari-ganti placeholder di bawah:
--      <USER_A_ID> -> uuid akun Alice
--      <USER_B_ID> -> uuid akun Bob

-- ============================================================
-- BAGIAN 0 — struktur kolom
-- ============================================================
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in ('profiles', 'user_tasks', 'task_checklists', 'task_daily_snapshots')
order by table_name, ordinal_position;

-- ============================================================
-- BAGIAN 1 — sesi Alice: CRUD, checklist hari ini
-- ============================================================
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.get_local_today() as hari_lokal_alice;

do $$
declare
  v_id uuid;
  v_name text;
begin
  select id, name into v_id, v_name from public.task_create('Task A1', 'water_drop');
  if v_name <> 'Task A1' then
    raise exception 'GAGAL: nama task create tidak sesuai';
  end if;
  if not exists (select 1 from public.user_tasks where id = v_id and user_id = auth.uid()) then
    raise exception 'GAGAL: task tidak tercatat sebagai milik session';
  end if;

  perform public.task_create('Task A2', null);
  perform public.task_create('Task A3', null);
  perform public.task_create('Task A4', null);
  perform public.task_create('Task A5', null);
  perform public.task_create('Task A6', null);

  if (select count(*) from public.task_list_my()) <> 6 then
    raise exception 'GAGAL: jumlah task aktif Alice diharapkan 6';
  end if;

  select id into v_id from public.task_list_my() where name = 'Task A2';
  perform public.task_update(v_id, 'Task A2 Diubah', 'edit', true, null);

  if not exists (select 1 from public.task_list_my() where id = v_id and name = 'Task A2 Diubah') then
    raise exception 'GAGAL: rename task tidak berlaku';
  end if;

  perform public.task_update(v_id, null, null, true, false);
  if exists (select 1 from public.task_list_my() where id = v_id) then
    raise exception 'GAGAL: task nonaktif masih muncul di daftar aktif';
  end if;
  perform public.task_update(v_id, null, null, false, true);

  if (select count(*) from public.task_list_my()) <> 6 then
    raise exception 'GAGAL: reactivate task tidak mengembalikan daftar aktif';
  end if;

  raise notice 'OK: CRUD task + activate/deactivate Alice';
end $$;

do $$
declare
  v_today date := public.get_local_today();
  v_id uuid;
  v_completed timestamptz;
begin
  select id into v_id from public.task_list_my() order by position limit 1;

  perform public.task_set_completed(v_id, v_today, true);

  select completed_at into v_completed
  from public.task_checklists
  where task_id = v_id and check_date = v_today;

  if v_completed is null then
    raise exception 'GAGAL: completed_at tidak tercatat';
  end if;

  perform public.task_set_completed(v_id, v_today, true);
  if (select count(*) from public.task_checklists where task_id = v_id and check_date = v_today) <> 1 then
    raise exception 'GAGAL: checklist duplikat pada tanggal yang sama';
  end if;

  if (select count(*) from public.task_daily_snapshots where user_id = auth.uid() and check_date = v_today) <> 6 then
    raise exception 'GAGAL: snapshot hari ini harus 6 task';
  end if;

  raise notice 'OK: checklist hari ini, anti duplikat, snapshot hari ini 6';
end $$;

do $$
begin
  begin
    perform public.task_set_completed(
      (select id from public.task_list_my() limit 1),
      public.get_local_today() + 1,
      true
    );
    raise exception 'GAGAL: checklist masa depan diterima';
  exception
    when raise_exception then
      if sqlerrm like 'GAGAL%' then raise; end if;
      raise notice 'OK: tanggal masa depan ditolak (%)', sqlerrm;
  end;
end $$;

reset role;
reset request.jwt.claims;

-- Backdate task Alice agar skenario historis "hari kemarin" valid.
update public.user_tasks
set created_at = now() - interval '3 days'
where user_id = '<USER_A_ID>';

-- ============================================================
-- BAGIAN 2 — sesi Alice: history 5/6 yang tidak berubah
-- ============================================================
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

do $$
declare
  v_past date := public.get_local_today() - 1;
  v_ids uuid[];
begin
  select array_agg(id order by position) into v_ids from public.task_list_my();

  perform public.task_ensure_snapshot(v_past);
  perform public.task_set_completed(v_ids[1], v_past, true);
  perform public.task_set_completed(v_ids[2], v_past, true);
  perform public.task_set_completed(v_ids[3], v_past, true);
  perform public.task_set_completed(v_ids[4], v_past, true);
  perform public.task_set_completed(v_ids[5], v_past, true);

  if (select count(*) from public.task_daily_snapshots where user_id = auth.uid() and check_date = v_past) <> 6 then
    raise exception 'GAGAL: total snapshot hari kemarin harus 6';
  end if;
  if (select count(*) from public.task_daily_snapshots where user_id = auth.uid() and check_date = v_past and completed) <> 5 then
    raise exception 'GAGAL: total selesai hari kemarin harus 5';
  end if;

  raise notice 'OK: skenario historis 5/6 tersimpan';
end $$;

do $$
declare
  v_past date := public.get_local_today() - 1;
  v_total integer;
  v_done integer;
begin
  perform public.task_delete((select id from public.task_list_my() order by position desc limit 1));
  perform public.task_delete((select id from public.task_list_my() order by position desc limit 1));

  if (select count(*) from public.task_list_my()) <> 4 then
    raise exception 'GAGAL: task aktif setelah hapus 2 diharapkan 4';
  end if;

  select count(*), count(*) filter (where completed)
  into v_total, v_done
  from public.task_daily_snapshots
  where user_id = auth.uid() and check_date = v_past;

  if v_total <> 6 or v_done <> 5 then
    raise exception 'GAGAL: history berubah menjadi %/%, diharapkan 5/6', v_done, v_total;
  end if;

  if exists (
    select 1 from public.task_checklists
    where user_id = auth.uid() and check_date = v_past
  ) is distinct from true then
    raise exception 'GAGAL: checklist historis ikut terhapus';
  end if;

  raise notice 'OK: history tetap 5/6 setelah 2 task dihapus dari daftar aktif';
end $$;

reset role;
reset request.jwt.claims;

-- ============================================================
-- BAGIAN 3 — sesi Bob: data terpisah
-- ============================================================
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_B_ID>","role":"authenticated"}';

do $$
begin
  perform public.task_create('Task B1', null);
  perform public.task_create('Task B2', null);

  if (select count(*) from public.task_list_my()) <> 2 then
    raise exception 'GAGAL: jumlah task Bob diharapkan 2';
  end if;

  if exists (select 1 from public.user_tasks where name like 'Task A%') then
    raise exception 'GAGAL: task Alice terlihat di sesi Bob';
  end if;

  if exists (select 1 from public.task_daily_snapshots where user_id <> auth.uid()) then
    raise exception 'GAGAL: snapshot Alice terlihat di sesi Bob';
  end if;

  if exists (select 1 from public.task_checklists where user_id <> auth.uid()) then
    raise exception 'GAGAL: checklist Alice terlihat di sesi Bob';
  end if;

  if exists (select 1 from public.profiles where id <> auth.uid()) then
    raise exception 'GAGAL: profil Alice terbaca di sesi Bob';
  end if;

  raise notice 'OK: sesi Bob hanya melihat data miliknya';
end $$;

do $$
declare
  v_alice_task uuid;
  v_count integer;
begin
  reset role;
  select id into v_alice_task from public.user_tasks where user_id = '<USER_A_ID>' limit 1;
  set role authenticated;

  update public.user_tasks set name = 'hacked' where id = v_alice_task;
  get diagnostics v_count = row_count;
  if v_count > 0 then
    raise exception 'GAGAL: task Alice bisa diubah dari sesi Bob';
  end if;

  delete from public.user_tasks where id = v_alice_task;
  get diagnostics v_count = row_count;
  if v_count > 0 then
    raise exception 'GAGAL: task Alice bisa dihapus paksa dari sesi Bob';
  end if;

  raise notice 'OK: update/delete task Alice oleh sesi Bob tidak mengubah baris apa pun';
end $$;

reset role;
reset request.jwt.claims;

-- ============================================================
-- BAGIAN 4 — sesi Alice: isolasi baca dan tulis terhadap data Bob
-- ============================================================
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

do $$
begin
  if exists (select 1 from public.user_tasks where user_id = '<USER_B_ID>') then
    raise exception 'GAGAL: task Bob terbaca oleh sesi Alice';
  end if;
  if exists (select 1 from public.task_daily_snapshots where user_id = '<USER_B_ID>') then
    raise exception 'GAGAL: snapshot Bob terbaca oleh sesi Alice';
  end if;
  if exists (select 1 from public.profiles where id = '<USER_B_ID>') then
    raise exception 'GAGAL: profil Bob terbaca oleh sesi Alice';
  end if;
  raise notice 'OK: isolasi baca Alice terhadap data Bob';
end $$;

do $$
begin
  begin
    insert into public.user_tasks (user_id, name)
    values ('<USER_B_ID>', 'injected');
    raise exception 'GAGAL: insert task milik Bob diterima dari sesi Alice';
  exception
    when insufficient_privilege or check_violation then
      raise notice 'OK: insert task milik Bob ditolak RLS';
  end;

  begin
    insert into public.task_checklists (user_id, task_id, check_date, completed)
    select '<USER_B_ID>', id, current_date, true
    from public.user_tasks
    where user_id = '<USER_B_ID>'
    limit 1;
    raise exception 'GAGAL: insert checklist milik Bob diterima dari sesi Alice';
  exception
    when insufficient_privilege or check_violation then
      raise notice 'OK: insert checklist milik Bob ditolak RLS';
  end;
end $$;

reset role;
reset request.jwt.claims;

-- ============================================================
-- BAGIAN 5 — aturan database tanpa sesi
-- ============================================================
do $$
declare
  v_uid uuid := '<USER_A_ID>';
  v_task uuid;
  v_date date;
begin
  select id into v_task from public.user_tasks where user_id = v_uid and deleted_at is null limit 1;
  v_date := (select timezone((select p.timezone from public.profiles p where p.id = v_uid), now()))::date;

  begin
    insert into public.task_checklists (user_id, task_id, check_date, completed)
    values (v_uid, v_task, v_date, false);
    insert into public.task_checklists (user_id, task_id, check_date, completed)
    values (v_uid, v_task, v_date, true);
    raise exception 'GAGAL: duplikat checklist per tanggal diterima';
  exception
    when unique_violation then
      raise notice 'OK: unique (task_id, check_date) bekerja';
  end;
end $$;

do $$
begin
  begin
    update public.profiles
    set timezone = 'Bukan/Timezone'
    where id = '<USER_A_ID>';
    raise exception 'GAGAL: timezone tidak valid diterima';
  exception
    when raise_exception then
      if sqlerrm like 'GAGAL%' then raise; end if;
      raise notice 'OK: timezone tidak valid ditolak trigger (%)', sqlerrm;
  end;
end $$;

update public.profiles set timezone = 'Asia/Jakarta' where id = '<USER_A_ID>';
update public.profiles set timezone = 'Asia/Jakarta' where id = '<USER_B_ID>';

select schemaname, tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('user_tasks', 'task_checklists', 'task_daily_snapshots', 'profiles')
order by tablename, policyname;

select p.rolname, has_function_privilege(p.rolname, 'public.task_set_completed(uuid,date,boolean)', 'EXECUTE') as can_task_set_completed,
       has_function_privilege(p.rolname, 'public.user_timezone(uuid)', 'EXECUTE') as can_user_timezone
from pg_roles p
where p.rolname in ('anon', 'authenticated', 'service_role');
