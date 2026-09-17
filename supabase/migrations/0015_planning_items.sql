-- Planning: the 6-tab drawer screen for structured, category-specific
-- wedding-planning items (who it's for, quantity, price, dates, location,
-- etc.), as opposed to Checklist (a flat to-do) or Vendors (the supplier
-- side -- who you're booking, not what/how much you're getting from them).
-- Each item can optionally link to a Guest (who it's for), a Vendor (who's
-- supplying it), and -- when it carries a price -- a mirrored Budget entry
-- kept in sync by the client (see PlanningProvider).

create type public.planning_category as enum (
  'accommodation', 'transportation', 'jewelry', 'food', 'ceremony_venue', 'decoration_flower'
);

create type public.planning_status as enum ('planned', 'booked', 'purchased', 'done');

create table public.planning_items (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  category public.planning_category not null,
  title text not null,
  guest_id uuid references public.guests(id) on delete set null,
  vendor_id uuid references public.vendors(id) on delete set null,
  budget_item_id uuid references public.budget_items(id) on delete set null,
  quantity numeric(10,2) not null default 1,
  unit_price numeric(12,2) not null default 0,
  status public.planning_status not null default 'planned',
  note text not null default '',
  -- Category-specific fields; only the ones relevant to a row's category are
  -- ever set by the client, the rest stay at their defaults.
  event_name text not null default '',
  venue_name text not null default '',
  address text not null default '',
  event_date date,
  start_date date,
  end_date date,
  from_location text not null default '',
  to_location text not null default '',
  vehicle_type text not null default '',
  occasion text not null default '',
  course text not null default '',
  placement text not null default '',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index planning_items_wedding_idx on public.planning_items (wedding_id);
create index planning_items_category_idx on public.planning_items (wedding_id, category);

create trigger trg_planning_items_log
  before insert or update or delete on public.planning_items
  for each row execute function public.fn_log_change();

alter table public.planning_items enable row level security;
create policy planning_items_select on public.planning_items
  for select using (public.has_section_access(wedding_id, 'planning'));
create policy planning_items_insert on public.planning_items
  for insert with check (public.has_section_access(wedding_id, 'planning', true));
create policy planning_items_update on public.planning_items
  for update using (public.has_section_access(wedding_id, 'planning', true))
  with check (public.has_section_access(wedding_id, 'planning', true));
create policy planning_items_delete on public.planning_items
  for delete using (public.has_section_access(wedding_id, 'planning', true));

alter publication supabase_realtime add table public.planning_items;
