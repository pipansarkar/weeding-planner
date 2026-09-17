-- Defensive re-apply: "Create shared wedding" was failing with a 42501 RLS
-- violation on insert into public.weddings even though the client sets
-- created_by = auth.uid() correctly. Drop and recreate the insert policy
-- idempotently in case an earlier partial/duplicate migration run left a
-- stale or incorrectly-scoped policy in place, and confirm RLS is enabled.

alter table public.weddings enable row level security;

drop policy if exists weddings_insert on public.weddings;
create policy weddings_insert on public.weddings
  for insert
  to authenticated, anon
  with check (created_by = auth.uid());
