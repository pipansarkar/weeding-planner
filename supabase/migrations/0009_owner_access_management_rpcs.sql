-- Owner controls requested: grant a section directly without waiting for a
-- request, and fully remove a member from a wedding (not just one section).
-- Both are owner-only RPCs; membership/section_access mutation for these
-- cases isn't otherwise exposed via direct table RLS policies (by design --
-- see section_access_owner_decide, which only lets the owner transition an
-- *existing* row's status, and wedding_members has no client-facing
-- update/delete policy at all).

create or replace function public.grant_section_access(
  p_wedding_id uuid, p_user_id uuid, p_section public.wedding_section
)
returns void language plpgsql security definer as $$
begin
  if not public.is_wedding_owner(p_wedding_id) then
    raise exception 'Only the wedding owner can grant access';
  end if;

  insert into public.section_access (wedding_id, user_id, section, status, decided_at, decided_by)
  values (p_wedding_id, p_user_id, p_section, 'approved', now(), auth.uid())
  on conflict (wedding_id, user_id, section)
  do update set status = 'approved', decided_at = now(), decided_by = auth.uid();
end;
$$;

grant execute on function public.grant_section_access(uuid, uuid, public.wedding_section) to authenticated, anon;

create or replace function public.remove_wedding_member(p_wedding_id uuid, p_user_id uuid)
returns void language plpgsql security definer as $$
begin
  if not public.is_wedding_owner(p_wedding_id) then
    raise exception 'Only the wedding owner can remove a member';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'The owner cannot remove themselves';
  end if;

  delete from public.section_access where wedding_id = p_wedding_id and user_id = p_user_id;
  delete from public.wedding_members where wedding_id = p_wedding_id and user_id = p_user_id;
end;
$$;

grant execute on function public.remove_wedding_member(uuid, uuid) to authenticated, anon;
