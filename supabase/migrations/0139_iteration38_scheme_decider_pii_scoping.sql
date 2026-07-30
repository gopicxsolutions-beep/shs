-- Gap-hunt iteration 38: a fresh Profile/Roster audit found a HIGH PII leak.
--
-- `profiles_select_scheme_decider` (migration 0111) was added so
-- `scheme_repository.dart`'s embed `decided_by_profile:profiles!decided_by
-- (name)` resolves for a member viewing her own scheme application's
-- decision. But RLS is row-level, not column-level — the policy grants
-- SELECT on the decider's ENTIRE profile row, and the Flutter app's own
-- restraint of only reading `name` out of that embed is not an enforced
-- boundary. A hostile client hitting `/rest/v1/profiles?id=eq.<decider_id>`
-- directly gets everything: mobile number, village, mandal, district.
--
-- Live-verified: a real member with a real rejected scheme application
-- read the deciding admin's full row this way — `mobile: "918341915251"`,
-- home village/mandal/district — despite having no other relationship to
-- that admin.
--
-- Fixed the right way for "expose only some columns of an otherwise
-- protected row": a `security_invoker` view projecting just `id, name`.
-- Row visibility is still governed by the exact same RLS condition (this
-- view runs with the CALLER's own permissions against the base table, not
-- an elevated one), but the columns available through it are permanently
-- capped at `id, name` regardless of which policy let the row through —
-- unlike the base `profiles` table, a direct REST query against this view
-- structurally cannot return `mobile`/`village`/etc.
create or replace view public.scheme_decider_public
with (security_invoker = true) as
  select id, name from public.profiles;

grant select on public.scheme_decider_public to authenticated;
