-- Modul 4 — skrip verifikasi live (BELUM DIJALANKAN pada sesi pengembangan).
-- Jalankan setelah migration 202610170005_streak.sql sukses.
-- Ganti <USER_A_ID> dengan uuid akun pengujian.

-- struktur fungsi
select p.proname, p.prosecdef, l.lame
from pg_proc p
join pg_language l on l.oid = p.prolang
where p.proname in ('get_active_dates', 'get_local_today', 'user_timezone');

select p.rolname,
       has_function_privilege(p.rolname, 'public.get_active_dates(integer)', 'EXECUTE') as can_get_active_dates,
       has_function_privilege(p.rolname, 'public.user_timezone(uuid)', 'EXECUTE') as can_user_timezone
from pg_roles p
where p.rolname in ('anon', 'authenticated', 'service_role');

-- siapkan skenario: backdate beberapa baris checklist completed milik Alice
with ranked as (
  select id,
         row_number() over (order by check_date, task_id) as rn
  from public.task_checklists
  where user_id = '<USER_A_ID>'
    and completed
  limit 12
)
update public.task_checklists c
set check_date = current_date - make_interval(days => gap),
    completed_at = now() - make_interval(days => gap)
from (
  select id,
         case mod(rn, 5)
           when 0 then 0
           when 1 then 1
           when 2 then 2
           when 3 then 3
           else 4
         end as gap
  from ranked
) r
where c.id = r.id;

-- sesi Alice: daftar tanggal aktif harus berisi rentang skenario di atas
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

select public.get_local_today() as hari_lokal;
select public.get_active_dates(100) as tanggal_aktif;
select public.get_active_dates(0) as limit_bawah_clamp;
select public.get_active_dates(99999) as limit_atas_clamp;

reset role;
reset request.jwt.claims;

-- catatan: hasil akhir streak (currentStreak, missedDays, graceDaysRemaining)
-- dihitung di Dart oleh StreakCalculator dari get_active_dates + get_local_today.
-- Verifikasi skenario streak dilakukan lewat aplikasi/Flutter berikut:
--   1. Hari aktif berurutan 5 hari -> getCurrentStreak() == 5.
--   2. Lewat 1-2 hari tanpa centang -> streak dipertahankan, missedDays naik.
--   3. Lewat 3 hari -> getCurrentStreak() == 0.
--   4. Centang lagi setelah putus -> getCurrentStreak() == 1.
--   5. Batalkan centang terakhir hari ini -> streak turun kembali.
