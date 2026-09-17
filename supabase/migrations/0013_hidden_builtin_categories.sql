-- Lets a member with write access to a section hide one of the app's
-- built-in categories (which live as hardcoded lists in the client, not as
-- rows) so it stops being offered for new items on this wedding. Existing
-- items already using it are unaffected, matching how removing a custom
-- category already behaves. Per-wedding and shared with all collaborators
-- via the same realtime pattern as custom_categories.

create table public.hidden_categories (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  section public.wedding_section not null,
  name text not null,
  hidden_by uuid references public.profiles(id),
  hidden_at timestamptz not null default now(),
  unique (wedding_id, section, name)
);
create index hidden_categories_wedding_idx on public.hidden_categories (wedding_id, section);

alter table public.hidden_categories enable row level security;

create policy hidden_categories_select on public.hidden_categories
  for select using (public.is_wedding_member(wedding_id));
create policy hidden_categories_insert on public.hidden_categories
  for insert with check (public.has_section_access(wedding_id, section, true));
create policy hidden_categories_delete on public.hidden_categories
  for delete using (public.has_section_access(wedding_id, section, true));

alter publication supabase_realtime add table public.hidden_categories;
