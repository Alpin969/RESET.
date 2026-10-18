-- Modul 7 — skrip verifikasi live (BELUM DIJALANKAN pada sesi pengembangan).
-- Modul 7 tidak menambah tabel/RPC baru; semua membaca task_daily_snapshots via RLS.
-- Jalankan setelah migration Modul 3-6 sukses. Ganti <USER_A_ID>/<USER_B_ID> dengan dua akun pengujian.

-- struktur yang diandalkan
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'task_daily_snapshots';

select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'task_daily_snapshots';

-- modul 7 tidak membuat fungsi baru (harus kosong)
select p.proname
from pg_proc p
where p.proname like 'activity\_%';

-- simulasi data riwayat dua akun (postgres / SQL Editor)
insert into public.user_tasks (id, user_id, name, icon, position)
values
  (gen_random_uuid(), '<USER_A_ID>', 'Task Lama A', 'sun', 0),
  (gen_random_uuid(), '<USER_A_ID>', 'Task Baru A', 'moon', 1),
  (gen_random_uuid(), '<USER_B_ID>', 'Task B', 'star', 0);

with a_tasks as (
  select id, row_number() over (order by position) - 1 as idx
  from public.user_tasks where user_id = '<USER_A_ID>'
)
insert into public.task_daily_snapshots
  (user_id, task_id, check_date, name, icon, position, is_active, completed, completed_at)
select '<USER_A_ID>', t.id, d.check_date, t2.name, t2.icon, t2.position, true,
       (t.idx + extract(day from d.check_date)) % 2 = 0,
       case when (t.idx + extract(day from d.check_date)) % 2 = 0 then now() else null end
from a_tasks t
cross join (values (date '2026-10-10'), (date '2026-10-11'), (date '2026-10-16'), (date '2026-10-17')) as d(check_date)
join public.user_tasks t2 on t2.id = t.id;

-- 1. integritas snapshot: rename task TIDAK mengubah riwayat
update public.user_tasks set name = 'Task renamed A'
where user_id = '<USER_A_ID>' and name = 'Task Lama A';

select distinct name
from public.task_daily_snapshots
where user_id = '<USER_A_ID>' and check_date = date '2026-10-10'
order by name;
-- harus tetap 'Task Lama A' dan 'Task Baru A' (nama historis), bukan 'Task renamed A'.

-- 2. hapus task TIDAK menghilangkan riwayat
update public.user_tasks set deleted_at = now()
where user_id = '<USER_A_ID>' and name = 'Task Baru A';

select count(*) as riwayat_task_dihapus
from public.task_daily_snapshots
where user_id = '<USER_A_ID>' and name = 'Task Baru A';
-- harus > 0 (riwayat tetap ada).

-- 3. agregasi per hari (mencerminkan ActivityRepository)
select check_date,
       count(*) as total,
       count(*) filter (where completed) as completed
from public.task_daily_snapshots
where user_id = '<USER_A_ID>'
  and check_date between date '2026-10-11' and date '2026-10-17'
group by check_date
order by check_date;
-- hari tanpa snapshot tidak muncul -> frontend mengisinya 0/0 (ActivityCalculator.buildDays).

-- 4. isolasi akun: sesi Bob tidak melihat data Alice
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_B_ID>","role":"authenticated"}';

select count(*) as bob_sees
from public.task_daily_snapshots;
-- hanya snapshot milik Bob.

select check_date, count(*) as total
from public.task_daily_snapshots
where check_date between date '2026-10-10' and date '2026-10-17'
group by check_date;
-- tidak berisi baris milik Alice.

reset role;
reset request.jwt.claims;

-- 5. tanggal lampau tidak pernah direkonstruksi oleh jalur baca Modul 7:
--    task_ensure_snapshot hanya dipanggil untuk HARI INI oleh ActivityRepository.
--    Verifikasi lewat aplikasi:
--    a. Catat checklist hari lalu (task_set_completed) -> snapshot terbentuk sekali.
--    b. Rename task aktif.
--    c. Panggil getDailyActivity(tanggal lalu) -> nama dan jumlah tetap seperti saat dicatat.
--    d. Panggil getWeeklyActivity() -> hari-hari sebelumnya tidak bertambah baris baru
--       (cek jumlah baris snapshot sebelum dan sesudah).
-- 6. uji aplikasi end-to-end:
--    a. getDailyActivity hari tanpa task -> 0/0, percentage 0, allCompleted false.
--    b. getDailyActivity 5/6 -> percentage 83.33, allCompleted false; tasks berisi 6 entri terurut position.
--    c. getWeeklyActivity() -> 7 tanggal berurutan; konsisten dengan angka TaskRepository per hari.
--    d. getMonthlyActivity(tahun, bulan) -> jumlah hari = hari dalam bulan (28/29/30/31).
--    e. getYearlyActivity(2026) -> months.length == 12; total periode = jumlah bulan.
--    f. getMonthlyActivity bulan depan / getWeeklyActivity masa depan -> 0/0, tanpa error,
--       dan tidak membuat snapshot untuk tanggal depan.
--    g. getActivityHistory(awal, akhir, limit: 7, offset: 0 dan 7) -> dua halaman hari
--       saling melengkapi; totalCompleted/totalAvailable identik di kedua halaman.
--    h. getActivitySummary(awal, akhir) -> hari aktif dan hari semua-selesai sesuai hitungan manual.
--    i. DashboardService.getOverview() -> currentStreak == StreakRepository.getStreakInfo().currentStreak;
--       totalSavings == SavingsRepository.getCurrentBalance();
--       todayProgress cocok dengan TaskRepository.getDailyProgress(hari ini);
--       weeklyActivity 7 entri; latestSleep == SleepRepository.getLatestSleepLog().
--    j. Ubah timezone profil pengguna -> tanggal riwayat lama TETAP mengikuti tanggal saat dicatat
--       (check_date tersimpan sebagai tanggal lokal murni); hanya "hari ini" dan pencatatan baru bergeser.
