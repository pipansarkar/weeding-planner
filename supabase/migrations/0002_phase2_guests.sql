-- Phase 2: Guest List pilot migration to Supabase.
-- Creates the guests table, attaches the generic change-log trigger, and adds
-- RLS policies gated on the 'guests' wedding_section.

create type public.guest_gender as enum ('male', 'female');

create table public.guests (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.weddings(id) on delete cascade,
  name text not null,
  gender public.guest_gender not null default 'male',
  phone text not null default '',
  address text not null default '',
  note text not null default '',
  category text not null,
  events text[] not null default '{}',
  rsvp_by_event jsonb not null default '{}',
  plus_ones int not null default 0,
  meal_preference text not null default '',
  invitation_sent boolean not null default false,
  gift_received text not null default '',
  thank_you_sent boolean not null default false,
  last_edited_by uuid references public.profiles(id),
  last_edited_at timestamptz
);

create index guests_wedding_idx on public.guests (wedding_id);

create trigger trg_guests_log
  before insert or update or delete on public.guests
  for each row execute function public.fn_log_change();

alter table public.guests enable row level security;

create policy guests_select on public.guests
  for select using (public.has_section_access(wedding_id, 'guests'));

create policy guests_insert on public.guests
  for insert with check (public.has_section_access(wedding_id, 'guests', true));

create policy guests_update on public.guests
  for update using (public.has_section_access(wedding_id, 'guests', true))
  with check (public.has_section_access(wedding_id, 'guests', true));

create policy guests_delete on public.guests
  for delete using (public.has_section_access(wedding_id, 'guests', true));
