-- fn_handle_new_user() defaulted anonymous users' display_name to the literal
-- string 'Guest' (since they have no email to derive a name from). That
-- satisfied the NOT NULL/non-empty check in AuthGate (auth.displayName ==
-- null || isEmpty), so SetDisplayNameScreen was silently skipped for every
-- anonymous sign-in -- every collaborator showed up as indistinguishable
-- "Guest" everywhere (Collaborators screen, attribution, access requests).
-- Leave display_name empty for anonymous users instead, so AuthGate correctly
-- routes them through SetDisplayNameScreen to pick a real name.

create or replace function public.fn_handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), ''),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Also clear the placeholder 'Guest' name for any existing anonymous users
-- who got stuck with it, so they're prompted for a real name next launch.
update public.profiles p
set display_name = ''
from auth.users u
where p.id = u.id
  and u.is_anonymous = true
  and p.display_name = 'Guest';
