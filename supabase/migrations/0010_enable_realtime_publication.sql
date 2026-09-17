-- Critical fix: the supabase_realtime publication had zero tables in it,
-- meaning every .channel().onPostgresChanges() subscription throughout the
-- app (guests, budget, vendors, checklist, timeline, emergency_contacts,
-- seating_tables, seating_assignments, menu_items, custom_lists,
-- custom_list_items, weddings, section_access, wedding_members) has been
-- silently receiving zero realtime events since Phase 2. Initial loads work
-- (plain Postgrest queries), but live updates from other collaborators or
-- from realtime-dependent UI (e.g. the wedding_info edit dialog relying on
-- its own echo) never actually arrived. This wasn't caught earlier because
-- single-device/single-session testing doesn't exercise cross-client sync.

alter publication supabase_realtime add table
  public.weddings,
  public.wedding_members,
  public.section_access,
  public.guests,
  public.budget_items,
  public.vendors,
  public.vendor_contact_logs,
  public.checklist_items,
  public.timeline_events,
  public.emergency_contacts,
  public.seating_tables,
  public.seating_assignments,
  public.menu_items,
  public.custom_lists,
  public.custom_list_items;
