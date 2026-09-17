-- Owner-only wedding deletion. There is deliberately no delete policy on
-- public.weddings for the authenticated role (mirrors the pattern in
-- 0009_owner_access_management_rpcs.sql), so the client-side "Delete Wedding"
-- / "Reset All Data" actions had no way to actually remove a cloud wedding --
-- they only ever cleared the legacy local sqflite tables, leaving all
-- Supabase-backed checklist/budget/guest/vendor/etc. data behind. Deleting
-- the weddings row here cascades to every dependent table via the existing
-- `on delete cascade` foreign keys.

create or replace function public.delete_wedding(p_wedding_id uuid)
returns void language plpgsql security definer as $$
begin
  if not public.is_wedding_owner(p_wedding_id) then
    raise exception 'Only the wedding owner can delete this wedding';
  end if;

  delete from public.weddings where id = p_wedding_id;
end;
$$;

grant execute on function public.delete_wedding(uuid) to authenticated, anon;
