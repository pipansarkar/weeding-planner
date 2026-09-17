-- New wedding_section enum value for the Planning screen (accommodation,
-- transportation, jewelry, food, ceremony & venue, decoration & flower).
-- Split into its own migration because Postgres forbids using a new enum
-- value in the same transaction that added it -- the table that uses this
-- value is created in the next migration instead.

alter type public.wedding_section add value 'planning';
