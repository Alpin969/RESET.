-- Modul 9 — Export & Backup
-- Integritas riwayat task: client tidak boleh menulis task_daily_snapshots
-- dan task_checklists secara langsung. Semua perubahan hanya melalui
-- SECURITY DEFINER RPC (task_ensure_snapshot, task_create, task_update,
-- task_delete, task_reorder, task_set_completed).

drop policy if exists snapshots_insert_own on public.task_daily_snapshots;
drop policy if exists snapshots_update_own on public.task_daily_snapshots;

drop policy if exists checklists_insert_own on public.task_checklists;
drop policy if exists checklists_update_own on public.task_checklists;

-- export hanya membaca; kebijakan select tetap dipertahankan
select policyname, cmd, qual
from pg_policies
where schemaname = 'public'
  and tablename in ('task_daily_snapshots', 'task_checklists')
order by tablename, policyname;
