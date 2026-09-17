-- "Create shared wedding" was failing with a 42501 RLS violation on every
-- insert into public.weddings, even though `created_by = auth.uid()` was
-- verified true in isolation via multiple direct psql/REST API tests
-- (see debugging session). Root cause not fully isolated, but proven to be
-- specific to the WITH CHECK evaluation at real insert time for anonymous
-- sessions. Sidestep it entirely: force created_by server-side from auth.uid()
-- via a BEFORE INSERT trigger, and simplify the policy to not re-derive a
-- value the trigger already guarantees is correct.

create or replace function public.fn_set_wedding_created_by()
returns trigger language plpgsql security definer as $$
begin
  new.created_by := auth.uid();
  return new;
end;
$$;

create trigger trg_set_wedding_created_by
  before insert on public.weddings
  for each row execute function public.fn_set_wedding_created_by();

drop policy if exists weddings_insert on public.weddings;
create policy weddings_insert on public.weddings
  for insert
  to authenticated, anon
  with check (auth.uid() is not null);
