-- Requesting (or re-requesting after rejection/revocation) section access needs
-- an insert-or-reset-to-pending upsert. A single member-owned RLS update policy
-- can't safely express "only allowed to reset your own row back to pending"
-- without also letting a member flip status to 'approved' for themselves, so
-- this is done via a SECURITY DEFINER RPC that pins the status transition.

create or replace function public.request_section_access(
  p_wedding_id uuid, p_section public.wedding_section
)
returns void language plpgsql security definer as $$
begin
  insert into public.section_access (wedding_id, user_id, section, status, requested_at, decided_at, decided_by)
  values (p_wedding_id, auth.uid(), p_section, 'pending', now(), null, null)
  on conflict (wedding_id, user_id, section)
  do update set status = 'pending', requested_at = now(), decided_at = null, decided_by = null
  where section_access.status in ('rejected', 'revoked');
end;
$$;
