-- Modul 5 — skrip verifikasi live (BELUM DIJALANKAN pada sesi pengembangan).
-- Jalankan setelah migration 202610170006_sleep_tracker.sql sukses.
-- Ganti <USER_A_ID> dan <USER_B_ID> dengan uuid dua akun pengujian berbeda.

-- struktur tabel & constraint
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'sleep_logs'
order by ordinal_position;

select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.sleep_logs'::regclass
  and contype in ('c', 'x');

select extname from pg_extension where extname = 'btree_gist';

-- RLS aktif + kebijakan
select relrowsecurity from pg_class where relname = 'sleep_logs';
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'sleep_logs'
order by policyname;

-- fungsi dan hak execute
select p.proname, p.prosecdef
from pg_proc p
where p.proname like 'sleep\_%'
order by p.proname;

select p.rolname,
       has_function_privilege(p.rolname, 'public.sleep_create(timestamptz, timestamptz)', 'EXECUTE') as can_create,
       has_function_privilege(p.rolname, 'public.sleep_validate_range(timestamptz, timestamptz)', 'EXECUTE') as can_validate,
       has_function_privilege(p.rolname, 'public.sleep_logs_between(date, date)', 'EXECUTE') as can_between
from pg_roles p
where p.rolname in ('anon', 'authenticated', 'service_role');

-- trigger durasi: insert langsung ke tabel (bukan lewat RPC) tetap menghitung ulang duration_minutes
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

insert into public.sleep_logs (user_id, sleep_start, wake_time, duration_minutes)
values (
  '<USER_A_ID>',
  timestamptz '2026-10-10 16:00:00+00',
  timestamptz '2026-10-11 01:00:00+00',
  1
)
returning duration_minutes;

-- durasi yang dikirim frontend tidak dipercaya (harus 540, bukan 1)

-- catatan valid: tidur 23.00 WIB, bangun 07.00 WIB = 480 menit
select public.sleep_create(
  timestamptz '2026-10-12 16:00:00+00',
  timestamptz '2026-10-13 00:00:00+00'
);

-- duplikasi identik wajib idempoten (return row yang sama, bukan error)
select public.sleep_create(
  timestamptz '2026-10-12 16:00:00+00',
  timestamptz '2026-10-13 00:00:00+00'
);

-- wajib error 'Waktu bangun harus setelah waktu mulai tidur.'
select public.sleep_create(
  timestamptz '2026-10-14 16:00:00+00',
  timestamptz '2026-10-14 15:00:00+00'
);

-- wajib error 'Durasi tidur maksimal 24 jam.'
select public.sleep_create(
  timestamptz '2026-10-14 00:00:00+00',
  timestamptz '2026-10-15 01:00:00+00'
);

-- wajib error 'Catatan tidur ini bertumpang tindih dengan catatan lain.'
select public.sleep_create(
  timestamptz '2026-10-12 20:00:00+00',
  timestamptz '2026-10-13 03:00:00+00'
);

-- daftar riwayat + tanggal bangun lokal
select id, sleep_start, wake_time, duration_minutes, wake_local_date
from public.sleep_list_my(10, 0);

-- catatan terakhir
select id, wake_time, duration_minutes from public.sleep_latest();

-- statistik mingguan/bulanan/tahunan memakai rentang tanggal lokal
select id, wake_local_date, duration_minutes
from public.sleep_logs_between(
  public.get_local_today() - 6,
  public.get_local_today()
);

-- isolasi antar akun: sesi Alice tidak boleh terlihat/diubah oleh Bob
reset role;
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_B_ID>","role":"authenticated"}';

select count(*) as bob_sees from public.sleep_logs;
select public.sleep_latest() is null as bob_latest_null;

-- akses sleep_logs_between pun harus kosong milik Bob
select count(*) as bob_between
from public.sleep_logs_between(current_date - 6, current_date);

reset role;
reset request.jwt.claims;

-- catatan akhir: perhitungan agregat (rata-rata, hitung malam di/batas/atas
-- rekomendasi per kelompok usia, grafik mingguan/bulanan/tahunan) dihitung di
-- Dart oleh SleepCalculator dari sleep_logs_between + get_local_today.
-- Verifikasi end-to-end lewat aplikasi:
--   1. createSleepLog 23.00->07.00 tersimpan duration_minutes = 480.
--   2. getWeeklySleepStats(ageGroup: '18+') mengembalikan 7 entri daily zero-filled.
--   3. getYearlySleepStats() mengembalikan 12 entri monthly.
--   4. Log masuk 1 Februari (bangun lokal) muncul di entri Februari, bukan Januari.
--   5. updateSleepLog menimpa waktu; deleteSleepLog menghapus satu baris tanpa
--      mempengaruhi data akun lain.
