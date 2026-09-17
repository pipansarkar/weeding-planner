-- Lets a planning_items row be "for" the Bride or Groom directly, alongside
-- the existing guest_id link. The couple themselves usually aren't entered
-- as rows in guests (that list is for who's invited, not the couple), so
-- guest_id alone can't represent "this hotel room is for the groom." Stored
-- as a stable tag ('bride'/'groom') rather than a name snapshot, so the
-- displayed name always tracks whatever's currently set in Wedding Details
-- even if it's edited later.

alter table public.planning_items
  add column for_couple text check (for_couple in ('bride', 'groom'));
