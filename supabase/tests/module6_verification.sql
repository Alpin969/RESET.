-- Modul 6 — skrip verifikasi live (BELUM DIJALANKAN pada sesi pengembangan).
-- Jalankan setelah migration 202610170007_savings_tracker.sql sukses.
-- Ganti <USER_A_ID> dan <USER_B_ID> dengan uuid dua akun pengujian berbeda.

-- struktur tabel & constraint
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'savings_transactions'
order by ordinal_position;

select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.savings_transactions'::regclass
  and contype = 'c';

select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'savings_transactions';

-- RLS aktif + kebijakan: hanya SELECT own, tanpa INSERT/UPDATE/DELETE policy
select relrowsecurity from pg_class where relname = 'savings_transactions';
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'savings_transactions';

-- hak execute fungsi
select p.proname, p.prosecdef
from pg_proc p
where p.proname like 'savings\_%'
order by p.proname;

select p.rolname,
       has_function_privilege(p.rolname, 'public.savings_add_transaction(text, bigint, text, timestamptz, text)', 'EXECUTE') as can_add,
       has_function_privilege(p.rolname, 'public.savings_total(uuid)', 'EXECUTE') as can_total,
       has_function_privilege(p.rolname, 'public.savings_lock(uuid)', 'EXECUTE') as can_lock,
       has_function_privilege(p.rolname, 'public.savings_balance()', 'EXECUTE') as can_balance
from pg_roles p
where p.rolname in ('anon', 'authenticated', 'service_role');

-- sesi Alice
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_A_ID>","role":"authenticated"}';

-- pengguna baru saldo Rp0
select public.savings_balance() as saldo_awal;

-- skenario: deposit 10000, deposit 5000, withdrawal 3000 -> saldo 12000
select public.savings_add_transaction('deposit', 10000, 'tabungan hari pertama');
select public.savings_add_transaction('deposit', 5000, null);
select public.savings_add_transaction('withdrawal', 3000, 'beli buku');
select public.savings_balance() as saldo_akhir;

-- withdrawal melebihi saldo wajib error
select public.savings_add_transaction('withdrawal', 999999999, null);

-- nominal nol dan negatif wajib error
select public.savings_add_transaction('deposit', 0, null);
select public.savings_add_transaction('deposit', -1000, null);

-- idempotency: request identik dengan key sama tidak menggandakan saldo
select public.savings_add_transaction('deposit', 2000, 'retry demo', null, 'key-abc-12345678') as pertama;
select public.savings_add_transaction('deposit', 2000, 'retry demo', null, 'key-abc-12345678') as kedua;
-- kedua return id yang sama; lalu:
select public.savings_balance() as saldo_setelah_duplikat;

-- key sama dengan payload berbeda wajib error
select public.savings_add_transaction('deposit', 3000, null, null, 'key-abc-12345678');

-- dua deposit nominal sama dengan key berbeda tetap sah
select public.savings_add_transaction('deposit', 5000, 'sengaja sama', null, 'key-def-11111111');
select public.savings_add_transaction('deposit', 5000, 'sengaja sama', null, 'key-ghi-22222222');
select public.savings_balance() as saldo_setelah_dua_deposit_sama;

-- update dan delete dengan aturan saldo
select id, amount, note
from public.savings_list_my(5, 0);

-- ganti nominal satu transaksi (ganti p_id dengan id transaksi withdrawal 3000)
-- update wajib error bila membuat saldo negatif:
-- select public.savings_update_transaction('<TX_ID_WITHDRAWAL>', 999999999, null, false);

-- hapus transaksi keliru (misal deposit 5000 terakhir):
-- select public.savings_delete_transaction('<TX_ID>');

-- urutan deterministik pada waktu sama
insert into public.savings_transactions (user_id, transaction_type, amount, transaction_date)
select '<USER_A_ID>', 'deposit', 100, t
from generate_series(
  now() - interval '2 hours',
  now() - interval '2 hours',
  interval '0 seconds'
) as t;

select id, amount, transaction_date
from public.savings_list_my(10, 0);

-- statistik: saldo awal periode + transaksi lokal
select id, transaction_type, amount, transaction_local_date
from public.savings_transactions_between(
  public.get_local_today() - 6,
  public.get_local_today()
);
select public.savings_balance_before(public.get_local_today() - 6) as saldo_awal_minggu;

-- uji konkurensi: buka DUA session SQL Editor / terminal terpisah.
-- Session 1: begin; select public.savings_lock('<USER_A_ID>');
--            (tahan transaksi, jangan commit dulu)
-- Session 2: select public.savings_add_transaction('withdrawal', <sisa_saldo>, null);
--            -- wajib MENUNGGU (blocked oleh advisory lock), bukan langsung error.
-- Session 1: commit;
-- Session 2: hasil keluar: bila melebihi sisa saldo -> error, saldo tidak negatif.

-- isolasi antar akun: sesi Bob tidak melihat/mengubah milik Alice
reset role;
set role authenticated;
set request.jwt.claims to '{"sub":"<USER_B_ID>","role":"authenticated"}';

select count(*) as bob_sees from public.savings_transactions;
select public.savings_balance() as bob_balance;
select public.savings_balance_before(current_date) as bob_balance_before;

-- tulis langsung ke tabel wajib ditolak RLS (tanpa policy INSERT):
do $$
begin
  insert into public.savings_transactions (user_id, transaction_type, amount)
  values ('<USER_B_ID>', 'deposit', 5000);
  raise exception 'INSERT langsung seharusnya ditolak RLS.';
exception
  when insufficient_privilege then
    raise notice 'OK: INSERT langsung ditolak RLS.';
end;
$$;

reset role;
reset request.jwt.claims;

-- catatan akhir: agregat statistik (saldo harian/bulanan berjalan untuk grafik
-- fl_chart) dihitung di Dart oleh SavingsCalculator dari
-- savings_transactions_between + savings_balance_before.
-- Verifikasi end-to-end lewat aplikasi:
--   1. Pengguna baru getCurrentBalance() == 0.
--   2. addDeposit 10000 + 5000 lalu addWithdrawal 3000 -> 12000.
--   3. addWithdrawal melebihi saldo -> AuthException 'Saldo tidak mencukupi...'
--   4. Dua kali addDeposit dengan idempotencyKey sama -> id transaksi sama, saldo sekali.
--   5. getWeeklySavingsStats() -> 7 entri daily, endBalance berjalan benar.
--   6. getMonthlySavingsStats() -> entri per hari dalam bulan berjalan.
--   7. getYearlySavingsStats() -> 12 entri monthly dengan saldo akhir benar.
--   8. updateTransaction menaikkan nominal melebihi saldo -> ditolak.
--   9. deleteTransaction deposit terakhir yang membuat saldo negatif -> ditolak.
