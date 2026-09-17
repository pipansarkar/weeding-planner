-- Phase 3: rolls the guests (Phase 2) pattern out to 8 more domains:
-- budget, vendors (+contact logs), checklist, timeline, emergency contacts,
-- seating (via a proper join table per the seating_assignments decision),
-- menu, and custom lists (+ their dynamic items).
-- Mood board is intentionally NOT included in this pass (Storage integration
-- deferred to its own focused migration).

-- ============================================================================
-- Budget
-- ============================================================================

create type public.payment_status as enum ('unpaid', 'partiallyPaid', 'paidInFull');

create table public.budget_items (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  category text not null,
  estimated_amount numeric(12,2) not null default 0,
  actual_amount numeric(12,2) not null default 0,
  note text not null default '',
  due_date date,
  payment_method text not null default '',
  paid_by text not null default '',
  payment_status public.payment_status not null default 'unpaid',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index budget_items_wedding_idx on public.budget_items (wedding_id);
create trigger trg_budget_items_log
  before insert or update or delete on public.budget_items
  for each row execute function public.fn_log_change();
alter table public.budget_items enable row level security;
create policy budget_items_select on public.budget_items
  for select using (public.has_section_access(wedding_id, 'budget'));
create policy budget_items_insert on public.budget_items
  for insert with check (public.has_section_access(wedding_id, 'budget', true));
create policy budget_items_update on public.budget_items
  for update using (public.has_section_access(wedding_id, 'budget', true))
  with check (public.has_section_access(wedding_id, 'budget', true));
create policy budget_items_delete on public.budget_items
  for delete using (public.has_section_access(wedding_id, 'budget', true));

-- ============================================================================
-- Vendors + vendor contact logs
-- ============================================================================

create type public.vendor_status as enum ('reserved', 'pending', 'rejected');

create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  category text not null,
  phone text not null default '',
  site text not null default '',
  address text not null default '',
  amount numeric(12,2) not null default 0,
  status public.vendor_status not null default 'pending',
  note text not null default '',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index vendors_wedding_idx on public.vendors (wedding_id);
create trigger trg_vendors_log
  before insert or update or delete on public.vendors
  for each row execute function public.fn_log_change();
alter table public.vendors enable row level security;
create policy vendors_select on public.vendors
  for select using (public.has_section_access(wedding_id, 'vendors'));
create policy vendors_insert on public.vendors
  for insert with check (public.has_section_access(wedding_id, 'vendors', true));
create policy vendors_update on public.vendors
  for update using (public.has_section_access(wedding_id, 'vendors', true))
  with check (public.has_section_access(wedding_id, 'vendors', true));
create policy vendors_delete on public.vendors
  for delete using (public.has_section_access(wedding_id, 'vendors', true));

create table public.vendor_contact_logs (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  date timestamptz not null,
  note text not null default '',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index vendor_contact_logs_wedding_idx on public.vendor_contact_logs (wedding_id);
create index vendor_contact_logs_vendor_idx on public.vendor_contact_logs (vendor_id);
create trigger trg_vendor_contact_logs_log
  before insert or update or delete on public.vendor_contact_logs
  for each row execute function public.fn_log_change();
alter table public.vendor_contact_logs enable row level security;
create policy vendor_contact_logs_select on public.vendor_contact_logs
  for select using (public.has_section_access(wedding_id, 'vendors'));
create policy vendor_contact_logs_insert on public.vendor_contact_logs
  for insert with check (public.has_section_access(wedding_id, 'vendors', true));
create policy vendor_contact_logs_update on public.vendor_contact_logs
  for update using (public.has_section_access(wedding_id, 'vendors', true))
  with check (public.has_section_access(wedding_id, 'vendors', true));
create policy vendor_contact_logs_delete on public.vendor_contact_logs
  for delete using (public.has_section_access(wedding_id, 'vendors', true));

-- ============================================================================
-- Checklist
-- ============================================================================

create type public.checklist_status as enum ('pending', 'completed');

create table public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  category text not null,
  date date,
  note text not null default '',
  status public.checklist_status not null default 'pending',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index checklist_items_wedding_idx on public.checklist_items (wedding_id);
create trigger trg_checklist_items_log
  before insert or update or delete on public.checklist_items
  for each row execute function public.fn_log_change();
alter table public.checklist_items enable row level security;
create policy checklist_items_select on public.checklist_items
  for select using (public.has_section_access(wedding_id, 'checklist'));
create policy checklist_items_insert on public.checklist_items
  for insert with check (public.has_section_access(wedding_id, 'checklist', true));
create policy checklist_items_update on public.checklist_items
  for update using (public.has_section_access(wedding_id, 'checklist', true))
  with check (public.has_section_access(wedding_id, 'checklist', true));
create policy checklist_items_delete on public.checklist_items
  for delete using (public.has_section_access(wedding_id, 'checklist', true));

-- ============================================================================
-- Timeline
-- ============================================================================

create table public.timeline_events (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  title text not null,
  category text not null default 'Other',
  time timestamptz not null,
  note text not null default '',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index timeline_events_wedding_idx on public.timeline_events (wedding_id);
create trigger trg_timeline_events_log
  before insert or update or delete on public.timeline_events
  for each row execute function public.fn_log_change();
alter table public.timeline_events enable row level security;
create policy timeline_events_select on public.timeline_events
  for select using (public.has_section_access(wedding_id, 'timeline'));
create policy timeline_events_insert on public.timeline_events
  for insert with check (public.has_section_access(wedding_id, 'timeline', true));
create policy timeline_events_update on public.timeline_events
  for update using (public.has_section_access(wedding_id, 'timeline', true))
  with check (public.has_section_access(wedding_id, 'timeline', true));
create policy timeline_events_delete on public.timeline_events
  for delete using (public.has_section_access(wedding_id, 'timeline', true));

-- ============================================================================
-- Emergency contacts
-- ============================================================================

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  role text not null default '',
  phone text not null default '',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index emergency_contacts_wedding_idx on public.emergency_contacts (wedding_id);
create trigger trg_emergency_contacts_log
  before insert or update or delete on public.emergency_contacts
  for each row execute function public.fn_log_change();
alter table public.emergency_contacts enable row level security;
create policy emergency_contacts_select on public.emergency_contacts
  for select using (public.has_section_access(wedding_id, 'emergency_contacts'));
create policy emergency_contacts_insert on public.emergency_contacts
  for insert with check (public.has_section_access(wedding_id, 'emergency_contacts', true));
create policy emergency_contacts_update on public.emergency_contacts
  for update using (public.has_section_access(wedding_id, 'emergency_contacts', true))
  with check (public.has_section_access(wedding_id, 'emergency_contacts', true));
create policy emergency_contacts_delete on public.emergency_contacts
  for delete using (public.has_section_access(wedding_id, 'emergency_contacts', true));

-- ============================================================================
-- Seating: tables + a proper join table for assignments (per the seating
-- decision in the approved plan), instead of a denormalized guest_ids array.
-- ============================================================================

create table public.seating_tables (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  capacity int not null default 8,
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index seating_tables_wedding_idx on public.seating_tables (wedding_id);
create trigger trg_seating_tables_log
  before insert or update or delete on public.seating_tables
  for each row execute function public.fn_log_change();
alter table public.seating_tables enable row level security;
create policy seating_tables_select on public.seating_tables
  for select using (public.has_section_access(wedding_id, 'seating'));
create policy seating_tables_insert on public.seating_tables
  for insert with check (public.has_section_access(wedding_id, 'seating', true));
create policy seating_tables_update on public.seating_tables
  for update using (public.has_section_access(wedding_id, 'seating', true))
  with check (public.has_section_access(wedding_id, 'seating', true));
create policy seating_tables_delete on public.seating_tables
  for delete using (public.has_section_access(wedding_id, 'seating', true));

create table public.seating_assignments (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  table_id uuid not null references public.seating_tables(id) on delete cascade,
  guest_id uuid not null references public.guests(id) on delete cascade,
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz,
  unique (table_id, guest_id)
);
create index seating_assignments_wedding_idx on public.seating_assignments (wedding_id);
create index seating_assignments_table_idx on public.seating_assignments (table_id);
create index seating_assignments_guest_idx on public.seating_assignments (guest_id);
create trigger trg_seating_assignments_log
  before insert or update or delete on public.seating_assignments
  for each row execute function public.fn_log_change();
alter table public.seating_assignments enable row level security;
create policy seating_assignments_select on public.seating_assignments
  for select using (public.has_section_access(wedding_id, 'seating'));
create policy seating_assignments_insert on public.seating_assignments
  for insert with check (public.has_section_access(wedding_id, 'seating', true));
create policy seating_assignments_update on public.seating_assignments
  for update using (public.has_section_access(wedding_id, 'seating', true))
  with check (public.has_section_access(wedding_id, 'seating', true));
create policy seating_assignments_delete on public.seating_assignments
  for delete using (public.has_section_access(wedding_id, 'seating', true));

-- ============================================================================
-- Menu
-- ============================================================================

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  course text not null,
  dietary_tags text[] not null default '{}',
  note text not null default '',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index menu_items_wedding_idx on public.menu_items (wedding_id);
create trigger trg_menu_items_log
  before insert or update or delete on public.menu_items
  for each row execute function public.fn_log_change();
alter table public.menu_items enable row level security;
create policy menu_items_select on public.menu_items
  for select using (public.has_section_access(wedding_id, 'menu'));
create policy menu_items_insert on public.menu_items
  for insert with check (public.has_section_access(wedding_id, 'menu', true));
create policy menu_items_update on public.menu_items
  for update using (public.has_section_access(wedding_id, 'menu', true))
  with check (public.has_section_access(wedding_id, 'menu', true));
create policy menu_items_delete on public.menu_items
  for delete using (public.has_section_access(wedding_id, 'menu', true));

-- ============================================================================
-- Custom lists + items. custom_list_items has no direct wedding_id column
-- (matching the sqflite shape), so its RLS/trigger derive wedding_id by
-- joining through custom_lists.
-- ============================================================================

create table public.custom_lists (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  icon text not null default 'list_alt',
  fields jsonb not null default '[]',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index custom_lists_wedding_idx on public.custom_lists (wedding_id);
create trigger trg_custom_lists_log
  before insert or update or delete on public.custom_lists
  for each row execute function public.fn_log_change();
alter table public.custom_lists enable row level security;
create policy custom_lists_select on public.custom_lists
  for select using (public.has_section_access(wedding_id, 'custom_lists'));
create policy custom_lists_insert on public.custom_lists
  for insert with check (public.has_section_access(wedding_id, 'custom_lists', true));
create policy custom_lists_update on public.custom_lists
  for update using (public.has_section_access(wedding_id, 'custom_lists', true))
  with check (public.has_section_access(wedding_id, 'custom_lists', true));
create policy custom_lists_delete on public.custom_lists
  for delete using (public.has_section_access(wedding_id, 'custom_lists', true));

create table public.custom_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.custom_lists(id) on delete cascade,
  field_values jsonb not null default '{}',
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);
create index custom_list_items_list_idx on public.custom_list_items (list_id);

-- fn_log_change() reads wedding_id directly off NEW/OLD, but custom_list_items
-- has no wedding_id column -- so it gets its own trigger function that looks
-- up the owning list's wedding_id first, then delegates to the same change_log
-- insert shape as fn_log_change().
create or replace function public.fn_log_change_custom_list_item()
returns trigger language plpgsql security definer as $$
declare
  v_wedding_id uuid;
begin
  select wedding_id into v_wedding_id from public.custom_lists
    where id = coalesce(new.list_id, old.list_id);

  insert into public.change_log (wedding_id, table_name, row_id, operation, old_data, new_data, changed_by)
  values (
    v_wedding_id,
    'custom_list_items',
    coalesce(new.id, old.id),
    lower(TG_OP),
    case when TG_OP in ('update', 'delete') then to_jsonb(old) else null end,
    case when TG_OP in ('insert', 'update') then to_jsonb(new) else null end,
    auth.uid()
  );

  if TG_OP = 'update' then
    new.last_edited_by := auth.uid();
    new.last_edited_at := now();
    return new;
  elsif TG_OP = 'delete' then
    return old;
  else
    return new;
  end if;
end;
$$;

create trigger trg_custom_list_items_log
  before insert or update or delete on public.custom_list_items
  for each row execute function public.fn_log_change_custom_list_item();

alter table public.custom_list_items enable row level security;
create policy custom_list_items_select on public.custom_list_items
  for select using (
    public.has_section_access(
      (select wedding_id from public.custom_lists where id = list_id),
      'custom_lists'
    )
  );
create policy custom_list_items_insert on public.custom_list_items
  for insert with check (
    public.has_section_access(
      (select wedding_id from public.custom_lists where id = list_id),
      'custom_lists', true
    )
  );
create policy custom_list_items_update on public.custom_list_items
  for update using (
    public.has_section_access(
      (select wedding_id from public.custom_lists where id = list_id),
      'custom_lists', true
    )
  )
  with check (
    public.has_section_access(
      (select wedding_id from public.custom_lists where id = list_id),
      'custom_lists', true
    )
  );
create policy custom_list_items_delete on public.custom_list_items
  for delete using (
    public.has_section_access(
      (select wedding_id from public.custom_lists where id = list_id),
      'custom_lists', true
    )
  );
