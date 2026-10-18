-- Modul 9 — skrip verifikasi live (BELUM DIJALANKAN pada sesi pengembangan).
-- Jalankan setelah migration 202610170009_export_backup.sql sukses.
-- Ganti <USER_A_ID>/<USER_B_ID> dengan dua akun pengujian.

-- kebijakan yang tersisa setelah migrasi keamanan
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'profiles', 'user_tasks', 'task_checklists', 'task_daily_snapshots',
    'sleep_logs', 'savings_transactions', 'task_reminders',
    'push_subscriptions', 'notification_push_config'
  )
order by tablename;

select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in (
    'task_checklists', 'task_daily_snapshots'
  )
order by tablename, policyname;

-- insert/update langsung ke riwayat harus DITOLAK
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

-- siapkan data dasar
insert into public.user_tasks (id, user_id, name, position)
values (gen_random_uuid(), '<USER_A_ID>', 'Task Export A', 10);

-- snapshot hari ini dibuat lewat RPC (harus berhasil)
select public.task_ensure_snapshot(current_date);

-- insert langsung ke task_daily_snapshots harus gagal
insert into public.task_daily_snapshots (user_id, task_id, check_date, name, position)
select '<USER_A_ID>', id, current_date, name, position
from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Export A';
-- diharapkan: error "new row violates row-level security policy"

-- update langsung ke task_daily_snapshots harus gagal
update public.task_daily_snapshots
set completed = true
where user_id = '<USER_A_ID>';
-- diharapkan: 0 baris terpengaruh / tanpa error, data tidak berubah

-- insert/update langsung ke task_checklists harus gagal
insert into public.task_checklists (user_id, task_id, check_date, completed)
select '<USER_A_ID>', id, current_date, true
from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Export A';
-- diharapkan: error "new row violates row-level security policy"

update public.task_checklists set completed = false where user_id = '<USER_A_ID>';
-- diharapkan: 0 baris terpengaruh

-- set_completed lewat RPC tetap berfungsi (jalankan sebagai user A)
select public.task_set_completed(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Export A'),
  current_date,
  true
);
-- diharapkan: sukses; snapshot completed = true

-- select riwayat tetap berfungsi
select count(*) as snapshot_count
from public.task_daily_snapshots
where user_id = '<USER_A_ID>';
-- diharapkan: > 0

-- user A tidak melihat data user B
select public.task_set_completed(
  (select id from public.user_tasks where user_id = '<USER_B_ID>' and name = 'Task Export B'),
  current_date,
  true
);
-- diharapkan: error (task milik user B)

-- export RPC/list yang dipakai export repository tetap terjangkau authenticated
select public.sleep_list_my(10, 0);
select public.savings_list_my(10, 0);
select public.reminder_list_my();
select public.savings_balance();

reset role;
reset request.jwt.claims;

-- ringkasan kebijakan sensitif (push endpoints & config tidak boleh
-- punya insert/update policy untuk authenticated selain kebutuhan push)
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('push_subscriptions', 'notification_push_config')
order by tablename, policyname;
