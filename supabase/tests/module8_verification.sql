-- Modul 8 — skrip verifikasi live (BELUM DIJALANKAN pada sesi pengembangan).
-- Jalankan setelah migration 202610170008_reminders.sql sukses.
-- Ganti <USER_A_ID>/<USER_B_ID> dengan dua akun pengujian.

-- struktur yang diandalkan
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'task_reminders', 'push_subscriptions',
    'notification_deliveries', 'notification_push_config'
  )
order by tablename;

select policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('task_reminders', 'push_subscriptions', 'notification_push_config')
order by tablename, policyname;

select p.proname, p.prosecdef
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (
    p.proname like 'reminder\_%'
    or p.proname like 'push\_%'
    or p.proname like 'notification\_%'
    or p.proname = 'validate_reminder_schedule'
  )
order by p.proname;

-- profil harus punya kolom preferensi baru
select id, notifications_enabled, reminder_default_time, timezone
from public.profiles
where id in ('<USER_A_ID>', '<USER_B_ID>');

-- simulasi data (postgres / SQL Editor)
insert into public.user_tasks (id, user_id, name, position)
values
  (gen_random_uuid(), '<USER_A_ID>', 'Task Reminder A', 10),
  (gen_random_uuid(), '<USER_A_ID>', 'Task Reminder A2', 11),
  (gen_random_uuid(), '<USER_B_ID>', 'Task Reminder B', 10);

update public.notification_push_config
set vapid_public_key = 'test-public-key-placeholder'
where id = 1;

-- 1. buat reminder valid lewat RPC (authenticated)
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  time '08:00'
);

select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A2'),
  time '19:30',
  'specific_days',
  array[1, 3, 5]::smallint[]
);

-- 2. validasi ditolak
-- frekuensi tidak valid
select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  time '09:00',
  'weekly',
  null
);
-- harus gagal: hari kosong untuk specific_days
select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  time '09:00',
  'specific_days',
  null
);
-- harus gagal: hari di luar 0-6
select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  time '09:00',
  'specific_days',
  array[7]::smallint[]
);
-- harus gagal: jam tidak valid untuk time type
select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  time '24:00'
);
-- harus gagal: task milik user lain
select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_B_ID>' and name = 'Task Reminder B'),
  time '09:00'
);
-- harus gagal: duplikat waktu pada task yang sama
select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  time '08:00'
);

-- 3. daftar reminder user A (2 baris)
select public.reminder_list_my();

-- 4. nonaktifkan lalu aktifkan kembali
select public.reminder_toggle(
  (select id from public.task_reminders where user_id = '<USER_A_ID>' and time_of_day = time '19:30'),
  false
);
select public.reminder_toggle(
  (select id from public.task_reminders where user_id = '<USER_A_ID>' and time_of_day = time '19:30'),
  true
);

select public.reminder_toggle(
  (select id from public.task_reminders where user_id = '<USER_A_ID>' and time_of_day = time '19:30'),
  false
);
-- reminder specific_days sengaja dibiarkan nonaktif agar pengujian enqueue deterministik.

-- subscription endpoint milik user lain tidak bisa didaftarkan ulang
-- (dilakukan setelah seed subscription di bawah)

-- preferensi notifikasi
select public.notification_prefs_get();
select public.notification_prefs_update(true, time '07:45');
select public.notification_prefs_get();

-- user B membuat satu reminder
reset role;
reset request.jwt.claims;

insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, device_name)
values
  ('<USER_A_ID>', 'https://push.example.com/device-a1', repeat('a', 88), repeat('b', 24), 'Web A1'),
  ('<USER_A_ID>', 'https://push.example.com/device-a2', repeat('c', 88), repeat('d', 24), 'Web A2'),
  ('<USER_B_ID>', 'https://push.example.com/device-b1', repeat('e', 88), repeat('f', 24), 'Web B1');

set role authenticated;
set request.jwt.claims to '{"sub":"<USER_B_ID>","role":"authenticated"}';

select public.reminder_create(
  (select id from public.user_tasks where user_id = '<USER_B_ID>' and name = 'Task Reminder B'),
  time '07:00'
);

select public.reminder_list_my();
-- tidak berisi reminder milik A.

select public.reminder_delete(
  (select id from public.task_reminders where user_id = '<USER_A_ID>' limit 1)
);
-- harus gagal: Reminder tidak ditemukan.

select public.push_register(
  'https://push.example.com/device-a1',
  repeat('x', 88),
  repeat('y', 24)
);
-- harus gagal: Subscription tidak valid (endpoint milik akun lain).

reset role;
reset request.jwt.claims;

set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.push_register(
  'https://push.example.com/device-b1',
  repeat('g', 88),
  repeat('h', 24)
);
-- harus gagal: Subscription tidak valid.

select public.push_list_my();
-- hanya device milik A.

select public.push_public_key_get();
-- harus 'test-public-key-placeholder'.

reset role;
reset request.jwt.claims;

-- 5. enqueue dengan waktu lokal yang baru lewat (jatuh tempo dalam 4 jam)
update public.profiles set timezone = 'Asia/Jakarta' where id = '<USER_A_ID>';

update public.task_reminders
set time_of_day = date_trunc('minute', timezone('Asia/Jakarta', now()) - interval '5 minutes')::time
where user_id = '<USER_A_ID>'
  and time_of_day = time '08:00';

select public.reminder_enqueue_due() as created_first;
-- harus 2 (satu per perangkat user A); user B tidak jatuh tempo.

select public.reminder_enqueue_due() as created_second;
-- idempotency: 0.

select r.time_of_day, d.local_date, d.scheduled_for, d.status, count(*) as deliveries
from public.notification_deliveries d
join public.task_reminders r on r.id = d.reminder_id
where d.user_id = '<USER_A_ID>'
group by r.time_of_day, d.local_date, d.scheduled_for, d.status;

select count(*) as deliveries_user_b
from public.notification_deliveries
where user_id = '<USER_B_ID>';
-- harus 0.

-- 6. task sudah selesai pada tanggal lokal -> enqueue dilewati
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.task_set_completed(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  public.get_local_today(),
  true
);

reset role;
reset request.jwt.claims;

delete from public.notification_deliveries where user_id = '<USER_A_ID>';

select public.reminder_enqueue_due() as created_after_completed;
-- harus 0.

-- task dinonaktifkan -> enqueue dilewati
update public.user_tasks set is_active = false
where user_id = '<USER_A_ID>' and name = 'Task Reminder A';

update public.task_reminders
set time_of_day = date_trunc('minute', timezone('Asia/Jakarta', now()) - interval '10 minutes')::time
where user_id = '<USER_A_ID>'
  and time_of_day = date_trunc('minute', timezone('Asia/Jakarta', now()) - interval '5 minutes')::time;

select public.reminder_enqueue_due() as created_after_inactive;
-- harus 0.

update public.user_tasks set is_active = true
where user_id = '<USER_A_ID>' and name = 'Task Reminder A';

-- 7. klaim batch, dedupe, dan retry
select public.reminder_enqueue_due() as created_for_claim;
-- harus 2.

select d->>'id' as delivery_id, d->>'attempt' as attempt, d->>'endpoint' as endpoint,
       d->>'task_ok' as task_ok, d->>'task_done' as task_done, d->>'reminder_ok' as reminder_ok
from public.reminder_claim_batch(10, 'worker-1') d;
-- 2 baris, attempt 1, endpoint device-a1 dan device-a2.

select count(*) as claimed_second
from public.reminder_claim_batch(10, 'worker-2');
-- harus 0 (dua worker tidak mengirim reminder yang sama).

do $$
declare
  v_ids uuid[];
begin
  select array_agg(id) into v_ids
  from public.notification_deliveries
  where status = 'sending'
    and locked_by = 'worker-1';

  perform public.reminder_mark_result(v_ids[1], 'sent', null, false);

  if coalesce(array_length(v_ids, 1), 0) >= 2 then
    perform public.reminder_mark_result(v_ids[2], 'failed', 'web_push_503: temporary', false);
  end if;
end $$;

select status, attempt, sent_at, last_error, locked_by
from public.notification_deliveries
where user_id = '<USER_A_ID>'
order by created_at;
-- satu baris sent dengan sent_at terisi; satu baris kembali pending dengan attempt 1.

select d->>'id' as delivery_id, d->>'attempt' as attempt
from public.reminder_claim_batch(10, 'worker-4') d;
-- hanya delivery gagal yang muncul kembali, dengan attempt 2.

do $$
declare
  v_id uuid;
begin
  select id into v_id
  from public.notification_deliveries
  where status = 'sending'
    and last_error like 'web_push_503%';

  if v_id is not null then
    perform public.reminder_mark_result(v_id, 'failed', 'web_push_400: permanent', true);
  end if;
end $$;

select count(*) as retry_after_permanent
from public.reminder_claim_batch(10, 'worker-6');
-- harus 0.

-- baris terkunci worker lain tidak diklaim ulang selama lock masih baru
insert into public.notification_deliveries
  (user_id, reminder_id, subscription_id, idempotency_key, local_date, scheduled_for, payload, status, attempt, locked_by, locked_at)
select
  user_id, reminder_id, subscription_id,
  'lock-test|' || gen_random_uuid()::text,
  local_date, now() - interval '1 minute', payload,
  'sending', 1, 'worker-x', now()
from public.notification_deliveries
where user_id = '<USER_A_ID>'
limit 1;

select count(*) as claimed_while_locked
from public.reminder_claim_batch(10, 'worker-7');
-- harus 0.

-- worker crash: lock basi > 15 menit bisa diklaim ulang (crash recovery)
update public.notification_deliveries
set locked_at = now() - interval '20 minutes'
where idempotency_key like 'lock-test%';

select d->>'id' as delivery_id, d->>'attempt' as attempt
from public.reminder_claim_batch(10, 'worker-8') d;
-- baris lock-test muncul kembali dengan attempt bertambah (tidak hilang permanen).

-- batas percobaan: attempt >= 3 tidak diklaim lagi
update public.notification_deliveries
set status = 'pending', attempt = 3, locked_at = null, locked_by = null
where idempotency_key like 'lock-test%';

select count(*) as claimed_beyond_retry_limit
from public.reminder_claim_batch(10, 'worker-9');
-- harus 0.

-- 8. perubahan zona waktu menggeser jadwal terhitung
delete from public.notification_deliveries where user_id = '<USER_A_ID>';

update public.profiles set timezone = 'UTC' where id = '<USER_A_ID>';

update public.task_reminders
set time_of_day = date_trunc('minute', timezone('UTC', now()) - interval '5 minutes')::time
where user_id = '<USER_A_ID>'
  and frequency = 'daily';

select public.reminder_enqueue_due() as created_after_tz_change;

select d.scheduled_for,
       (d.scheduled_for at time zone 'UTC') as utc_instant,
       d.local_date
from public.notification_deliveries d
where d.user_id = '<USER_A_ID>'
order by d.created_at desc
limit 2;
-- local_date dan scheduled_for dihitung memakai timezone profiles terbaru (UTC).

-- 9. subscription kedaluwarsa tidak lagi dituju
update public.push_subscriptions
set expired_at = now()
where endpoint = 'https://push.example.com/device-a1';

delete from public.notification_deliveries where user_id = '<USER_A_ID>';

select public.reminder_enqueue_due() as created_with_expired_sub;

select count(*) as active_subscription_deliveries
from public.notification_deliveries
where user_id = '<USER_A_ID>';
-- hanya 1 (device-a2).

insert into public.notification_deliveries
  (user_id, reminder_id, subscription_id, idempotency_key, local_date, scheduled_for, payload)
select
  user_id, reminder_id, null,
  'manual-expired-test|' || gen_random_uuid()::text,
  local_date, now() - interval '1 minute', payload
from public.notification_deliveries
where user_id = '<USER_A_ID>'
limit 1;

select d->>'endpoint' as endpoint, d->>'task_ok' as task_ok
from public.reminder_claim_batch(10, 'worker-10') d;
-- salah satu baris memiliki endpoint null -> dispatcher memberi reminder_expire_subscription
-- dan menandai delivery skipped.

-- 10. update reminder membuang delivery pending lama
delete from public.notification_deliveries where user_id = '<USER_A_ID>';

update public.task_reminders
set time_of_day = date_trunc('minute', timezone('UTC', now()) - interval '2 minutes')::time
where user_id = '<USER_A_ID>'
  and frequency = 'daily';

select public.reminder_enqueue_due() as created_before_update;

select count(*) as pending_before_update
from public.notification_deliveries
where user_id = '<USER_A_ID>' and status = 'pending';
-- harus 1.

set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.reminder_update(
  (select id from public.task_reminders where user_id = '<USER_A_ID>' and frequency = 'daily'),
  time '23:15'
);

reset role;
reset request.jwt.claims;

select count(*) as pending_after_update
from public.notification_deliveries
where user_id = '<USER_A_ID>' and status = 'pending';
-- harus 0.

-- 11. task dihapus setelah enqueue -> dispatcher melewati delivery
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.task_set_completed(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A'),
  public.get_local_today(),
  false
);

reset role;
reset request.jwt.claims;

update public.task_reminders
set time_of_day = date_trunc('minute', timezone('UTC', now()) - interval '3 minutes')::time
where user_id = '<USER_A_ID>'
  and frequency = 'daily';

select public.reminder_enqueue_due() as created_before_task_delete;
-- harus >= 1.

set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.task_delete(
  (select id from public.user_tasks where user_id = '<USER_A_ID>' and name = 'Task Reminder A')
);

reset role;
reset request.jwt.claims;

select d->>'task_ok' as task_ok, d->>'reminder_ok' as reminder_ok
from public.reminder_claim_batch(10, 'worker-11') d;
-- task_ok false -> dispatcher menandai delivery skipped, bukan mengirim notifikasi.

select public.reminder_enqueue_due() as enqueue_again_after_delete;
-- harus 0 (task sudah terhapus, join task aktif di reminder_enqueue_due menyaringnya).

-- 12. RLS: akun A tidak melihat data akun B
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select count(*) as reminders_visible_to_a
from public.task_reminders;
-- hanya reminder milik A.

select count(*) as subscriptions_visible_to_a
from public.push_subscriptions;
-- hanya subscription milik A; device-b1 tidak terlihat.

select count(*) as deliveries_visible_to_a
from public.notification_deliveries;
-- 0 (tabel deliveries tanpa policy select untuk authenticated).

select public.reminder_enqueue_due();
-- harus gagal: permission denied.

select public.reminder_claim_batch(1, 'x');
select public.reminder_mark_result(gen_random_uuid(), 'sent', null, false);
select public.reminder_expire_subscription(gen_random_uuid());
-- ketiganya harus gagal: permission denied.

reset role;
reset request.jwt.claims;

set role authenticated;
set request.jwt.claims to '{"sub":"<USER_B_ID>","role":"authenticated"}';

select count(*) as reminders_visible_to_b
from public.task_reminders;
-- hanya reminder milik B (1 baris).

select public.notification_prefs_get();
-- hanya preferensi milik B.

reset role;
reset request.jwt.claims;

set role anon;
select public.reminder_list_my();
-- harus gagal: permission denied.

select count(*) as anon_sees_reminders from public.task_reminders;
-- 0.

reset role;
reset request.jwt.claims;

-- 13. penghapusan subscription (logout atau pencabutan izin per perangkat)
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';
select public.push_unregister('https://push.example.com/device-a2');
reset role;
reset request.jwt.claims;

select endpoint, expired_at
from public.push_subscriptions
where user_id = '<USER_A_ID>'
order by created_at;
-- device-a2 terhapus; device-a1 tetap sebagai riwayat expired.

set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';
select public.push_unregister_all();
reset role;
reset request.jwt.claims;

select count(*) as remaining_subscriptions_a
from public.push_subscriptions
where user_id = '<USER_A_ID>';
-- harus 0.

-- 14. uji lewat aplikasi (frontend / browser, tidak bisa diverifikasi di SQL)
-- a. NotificationService.enableNotifications() pada Chrome desktop -> permission prompt muncul
--    sekali; setelah granted, push_subscriptions berisi 1 baris untuk akun tersebut.
-- b. Dua browser berbeda pada akun sama -> push_list_my berisi 2 entri.
-- c. disableNotifications() pada satu perangkat -> hanya baris perangkat itu terhapus.
-- d. Izin dicabut lewat settings browser lalu app dibuka -> syncOnAppStart menghapus
--    endpoint tersimpan dari server tanpa meminta izin ulang.
-- e. permission 'denied' -> enableNotifications() mengembalikan permissionDenied tanpa
--    memanggil Notification.requestPermission().
-- f. Logout -> cleanupOnSignOut menghapus seluruh subscription akun tersebut.
-- g. Reminder 2 menit dari sekarang, aplikasi ditutup, cron aktif -> notifikasi muncul
--    di system tray tanpa aplikasi terbuka.
-- h. Centang task sebelum waktu reminder -> tidak ada notifikasi untuk tanggal itu.
-- i. Dua tab memanggil enableNotifications() bersamaan -> endpoint sama, 1 baris (upsert).

-- pembersihan data uji (opsional)
-- delete from public.notification_deliveries where user_id in ('<USER_A_ID>', '<USER_B_ID>');
-- delete from public.push_subscriptions where user_id in ('<USER_A_ID>', '<USER_B_ID>');
-- delete from public.task_reminders where user_id in ('<USER_A_ID>', '<USER_B_ID>');
-- delete from public.task_daily_snapshots where user_id in ('<USER_A_ID>', '<USER_B_ID>');
-- delete from public.task_checklists where user_id in ('<USER_A_ID>', '<USER_B_ID>');
-- delete from public.user_tasks where user_id in ('<USER_A_ID>', '<USER_B_ID>');
