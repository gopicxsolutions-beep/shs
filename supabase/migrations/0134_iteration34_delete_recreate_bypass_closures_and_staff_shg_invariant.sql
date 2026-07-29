-- Gap-hunt iteration 34: dogfooding iteration 33's own fixes found the SAME
-- underlying architectural gap in THREE places: an UPDATE-time lock that
-- compares against "whatever the row's current committed state happens to
-- be" can always be routed around by (a) DELETE + re-INSERT (a fresh row
-- has no history to lock against) or (b) a legitimate-looking first
-- statement that mutates the very reference point the second statement's
-- guard reads. Two of the three get real structural fixes below (a
-- genuinely immutable anchor column instead of "current committed row");
-- the third (shg_documents) is deliberately left as documented residual
-- risk — see the note at the end.
--
-- 1. [HIGH] `livelihood_activities`'s `revenue_locked_at` permanence
-- (0132) is airtight against same-row edits, but `livelihood_delete_staff`
-- (0105) lets staff delete ANY other member's activity regardless of
-- status, and the insert policy lets staff create a fresh one for any
-- active member — so a staff account can DELETE a completed activity and
-- INSERT a brand-new row for the same member, walking it through
-- planned->active->completed again with a fabricated revenue, the
-- `revenue_locked_at` trigger stamping it fresh on the "new" row. Live-
-- verified by this round's dogfooding pass end-to-end. Fixed by refusing
-- to let staff delete an activity that has ever been completed
-- (`revenue_locked_at is not null`) — once locked, its financial history
-- can no longer be erased-and-reborn as a fresh row either.
--
-- 2. [HIGH] `meetings_update_leader_or_staff`'s staff cancel-guard (0133)
-- compares the submitted `status` against `meetings_locked_fields()`'s
-- CURRENT committed `meeting_date` — but that "original" is itself
-- mutable by staff. Live-verified 2-statement bypass: statement 1 moves a
-- historical meeting's `meeting_date` into the future while leaving
-- `status` unchanged (allowed — the guard's `status <> 'cancelled'`
-- disjunct is true, so the date check never applies to a non-cancelling
-- edit); statement 2 then cancels it — now allowed, because
-- `meetings_locked_fields()` reads back the ALREADY-COMMITTED future date
-- from statement 1 as "the original." Fixed with a genuinely immutable
-- `original_meeting_date` column, stamped once at INSERT and force-pinned
-- to its original value on every subsequent UPDATE by a trigger — the
-- trigger runs before RLS's own WITH CHECK evaluation, so by the time the
-- guard reads `original_meeting_date` it can never reflect an
-- intermediate attacker-chosen value, no matter how many statements or
-- what order. The staff branch's cancel-guard now reads this column
-- instead of the mutable locked-fields snapshot.
--
-- 3. [MEDIUM, live-verified, documented rather than fixed this round]
-- `shg_documents`'s new shg_id UPDATE lock (0132) is real for a plain
-- UPDATE, but staff's unrestricted DELETE + unrestricted INSERT (any
-- shg_id) reproduces the identical "document silently moved to another
-- SHG" outcome under a new row id. Unlike livelihood/meetings, there's no
-- clean way to lock this without deciding a real product question first
-- (should staff ever be allowed to create/delete documents for a
-- different SHG at all, given the legitimate "leader manages her own
-- SHG's document list" workflow this table was always designed around,
-- per migration 0026's own judgment?) — narrowing DELETE/INSERT
-- unilaterally risks breaking a real staff workflow with no signal in
-- this codebase for what that workflow actually needs. Left as an
-- explicitly disclosed, not-yet-decided gap rather than a guessed fix.
--
-- 4. [MEDIUM-HIGH, live-verified] Admin's "Assign SHG" action
-- (`assignShg` in `admin_repository.dart`) had no role check at the RLS
-- layer either — nothing stopped a crp/clf/admin account (platform-wide
-- BY DESIGN) from being given a `shg_id`, silently narrowing every
-- `isPlatformWideStaff`-gated dashboard to single-SHG scope with no
-- error. `profiles_leader_requires_shg` (0119) only enforces the LEADER
-- direction; nothing enforced the reverse. Live-confirmed zero currently
-- live staff profiles have a non-null shg_id, so this validates
-- immediately rather than needing NOT VALID. Client-side gating fixed in
-- the same round (`admin_users_page.dart`'s "Assign SHG" button now also
-- requires role in ('member','leader')) — this constraint is the actual
-- authorization boundary per this project's own security model, not a
-- backstop for a UI check that could regress unnoticed.

drop policy if exists "livelihood_delete_staff" on public.livelihood_activities;
create policy "livelihood_delete_staff" on public.livelihood_activities
  for delete using (public.is_staff() and member_id <> auth.uid() and revenue_locked_at is null);

alter table public.meetings add column if not exists original_meeting_date date;
update public.meetings set original_meeting_date = meeting_date where original_meeting_date is null;
alter table public.meetings alter column original_meeting_date set not null;

create or replace function public.meetings_stamp_original_date()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.original_meeting_date := new.meeting_date;
  else
    new.original_meeting_date := old.original_meeting_date;
  end if;
  return new;
end;
$$;

drop trigger if exists meetings_stamp_original_date_trigger on public.meetings;
create trigger meetings_stamp_original_date_trigger
  before insert or update on public.meetings
  for each row
  execute function public.meetings_stamp_original_date();

drop policy if exists "meetings_update_leader_or_staff" on public.meetings;

create policy "meetings_update_leader_or_staff" on public.meetings
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      public.is_staff()
      and (status <> 'cancelled' or original_meeting_date >= current_date)
      and shg_id = (select f.shg_id from public.meetings_locked_fields(meetings.id) f)
      and meeting_date >= (current_date - interval '7 days')
    )
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and (status <> 'cancelled' or original_meeting_date >= current_date)
      and shg_id = (select f.shg_id from public.meetings_locked_fields(meetings.id) f)
      and meeting_date is not distinct from (select f.meeting_date from public.meetings_locked_fields(meetings.id) f)
      and meeting_time is not distinct from (select f.meeting_time from public.meetings_locked_fields(meetings.id) f)
      and venue is not distinct from (select f.venue from public.meetings_locked_fields(meetings.id) f)
      and agenda is not distinct from (select f.agenda from public.meetings_locked_fields(meetings.id) f)
    )
  );

alter table public.profiles add constraint profiles_staff_no_shg check (role not in ('crp', 'clf', 'admin') or shg_id is null);
