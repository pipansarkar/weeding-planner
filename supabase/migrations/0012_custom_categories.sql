-- Lets any member with write access to a section add their own categories
-- (e.g. a new Budget or Vendor category) beyond the app's built-in fixed
-- lists. Custom categories are per-wedding and shared with all collaborators
-- via the same realtime pattern as every other domain table.

create table public.custom_categories (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  section public.wedding_section not null,
  name text not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (wedding_id, section, name)
);
create index custom_categories_wedding_idx on public.custom_categories (wedding_id, section);

alter table public.custom_categories enable row level security;

create policy custom_categories_select on public.custom_categories
  for select using (public.is_wedding_member(wedding_id));
create policy custom_categories_insert on public.custom_categories
  for insert with check (public.has_section_access(wedding_id, section, true));
create policy custom_categories_delete on public.custom_categories
  for delete using (public.has_section_access(wedding_id, section, true));

alter publication supabase_realtime add table public.custom_categories;
