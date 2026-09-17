-- Anonymous sign-ins have no email (auth.users.email is null), so the
-- original fn_handle_new_user() would violate profiles' NOT NULL email/
-- display_name columns. Relax those columns and give the trigger a safe
-- fallback display name for anonymous users (the app's SetDisplayNameScreen
-- prompts them to pick a real one on first login anyway).

alter table public.profiles alter column email drop not null;

create or replace function public.fn_handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), 'Guest'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
