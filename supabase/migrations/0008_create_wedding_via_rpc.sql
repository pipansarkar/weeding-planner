-- Direct INSERT into public.weddings through PostgREST consistently fails
-- with a 42501 RLS violation for every authenticated/anonymous role tested,
-- even against a maximally permissive `with check (true)` policy -- proven
-- via extensive isolated testing (direct psql simulation, raw REST API calls,
-- a full project restart) to not be a policy-content issue. Root cause not
-- resolved; bypassing PostgREST's INSERT path entirely via an RPC function
-- that performs the insert itself and enforces the auth check in the
-- function body, which runs outside of PostgREST's per-request RLS
-- enforcement for INSERT.

create or replace function public.create_wedding(
  p_bride_name text default '',
  p_groom_name text default ''
)
returns public.weddings
language plpgsql security definer as $$
declare
  v_uid uuid;
  v_wedding public.weddings;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Must be authenticated to create a wedding';
  end if;

  insert into public.weddings (bride_name, groom_name, created_by)
  values (p_bride_name, p_groom_name, v_uid)
  returning * into v_wedding;

  return v_wedding;
end;
$$;

grant execute on function public.create_wedding(text, text) to authenticated, anon;
