-- Gap-hunt round 190 (iteration 18): Admin module fresh audit found the
-- exact same cascade-blast-radius shape migration 0063 already fixed for
-- loans (round ~30-something) — never extended to four more tables.
--
-- `shgs_delete_admin`/`profiles_delete_admin` (0002) correctly scope WHO can
-- delete an SHG/profile (admin only) — that part is not the gap. The gap is
-- that the delete itself is a landmine: a routine admin action (deleting a
-- duplicate/defunct SHG, or a duplicate profile) silently destroys every
-- savings entry, meeting record (and everything under it — attendance/
-- minutes/action items cascade from meetings.id independently and are
-- correctly left as-is), uploaded document, and livelihood activity for
-- that SHG/member in the same transaction, with no archival and no
-- "block if there's real history" check — while loans (0063) and
-- financial_ledger (0072) already correctly RESTRICT the exact same shape.
-- RESTRICT forces an explicit decision before a profile/SHG with real
-- history can ever be removed, instead of silent data loss, matching
-- 0063's own reasoning exactly.

alter table public.shg_documents drop constraint shg_documents_shg_id_fkey;
alter table public.shg_documents add constraint shg_documents_shg_id_fkey foreign key (shg_id) references public.shgs (id) on delete restrict;

alter table public.savings_entries drop constraint savings_entries_shg_id_fkey;
alter table public.savings_entries add constraint savings_entries_shg_id_fkey foreign key (shg_id) references public.shgs (id) on delete restrict;

alter table public.savings_entries drop constraint savings_entries_member_id_fkey;
alter table public.savings_entries add constraint savings_entries_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;

alter table public.meetings drop constraint meetings_shg_id_fkey;
alter table public.meetings add constraint meetings_shg_id_fkey foreign key (shg_id) references public.shgs (id) on delete restrict;

alter table public.livelihood_activities drop constraint livelihood_activities_shg_id_fkey;
alter table public.livelihood_activities add constraint livelihood_activities_shg_id_fkey foreign key (shg_id) references public.shgs (id) on delete restrict;

alter table public.livelihood_activities drop constraint livelihood_activities_member_id_fkey;
alter table public.livelihood_activities add constraint livelihood_activities_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;
