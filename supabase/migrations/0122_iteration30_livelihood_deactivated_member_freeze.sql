-- Gap-hunt iteration 30: closes a CRITICAL gap in `livelihood_activities`
-- that `docs/DEVELOPMENT_PROGRESS.md` (round 186) explicitly claimed was
-- already fixed — it never actually shipped. Migration 0090 (round 186's
-- real migration) only added `livelihood_activities_amount_cap`; no
-- migration since has ever added a `profile_is_active(member_id)` check to
-- `livelihood_update_self_leader_or_staff`, unlike the equivalent, already-
-- correct pattern on `savings_update_leader_or_staff`/`meeting_attendance`.
--
-- Live-verified exploit (rolled back): a leader (or staff, via the other
-- branch) could freely `UPDATE ... SET status='active', revenue=<any
-- value>` on a DEACTIVATED member's livelihood activity — 1 row affected,
-- no error, no restriction at all. A deactivated member's livelihood
-- numbers should be frozen the same way her savings/loan/meeting data
-- already is; instead a leader/staff could keep advancing her activity's
-- status and revenue indefinitely after she's left the SHG, permanently
-- feeding fabricated figures into SHG-wide and platform-wide livelihood
-- totals attributed to someone no longer a member.
--
-- Added to BOTH branches: the staff-editing-someone-else's-row branch
-- (previously fully unrestricted with no checks whatsoever) and the
-- self/leader/staff-on-own-row restricted branch (which already checks
-- shg_id/member_id/activity_type/description/investment/created_at/status-
-- transition/revenue-freeze, but never activeness).

drop policy if exists "livelihood_update_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_update_self_leader_or_staff" on public.livelihood_activities
  for update using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  )
  with check (
    (public.is_staff() and member_id <> auth.uid() and public.profile_is_active(member_id))
    or (
      (member_id = auth.uid() or (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff())
      and public.profile_is_active(member_id)
      and shg_id = (select f.shg_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and member_id = (select f.member_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and activity_type = (select f.activity_type from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and description is not distinct from (select f.description from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and investment is not distinct from (select f.investment from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and created_at = (select f.created_at from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and abs(
        array_position(array['planned','active','completed'], status)
        - array_position(array['planned','active','completed'], (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f))
      ) <= 1
      and (
        (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f) <> 'completed'
        or revenue = (select f.revenue from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- [MEDIUM] `audit_livelihood_staff_override` only logged an on-behalf-of
-- edit when the actor was STAFF — but the RLS policy above grants an SHG's
-- LEADER the identical "edit any member's activity" capability, and a
-- leader rewriting a teammate's revenue/status is exactly the kind of
-- action worth an audit trail for (SHG-internal disputes over numbers).
-- Broadened to any actor editing someone else's row (auth.uid() <>
-- member_id), covering leader-on-behalf-of edits too, not just staff's.
-- Renamed the logged action accordingly since it's no longer staff-only.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.audit_livelihood_staff_override()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is distinct from new.member_id and (new.status is distinct from old.status or new.revenue is distinct from old.revenue) then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'livelihood_override', 'livelihood_activities', new.id, jsonb_build_object(
      'old_status', old.status, 'new_status', new.status,
      'old_revenue', old.revenue, 'new_revenue', new.revenue
    ));
  end if;
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- [LOW] `activity_type` had no DB-level constraint at all — the known set
-- (Dairy/Tailoring/Retail/Poultry/Agriculture/Handicrafts/Other) only
-- existed client-side (`lib/models/livelihood.dart`'s
-- `livelihoodActivityTypes`). A direct REST insert could set an arbitrary
-- string; not a privilege-escalation risk (the locked-fields check already
-- freezes it after creation), but `livelihoodActivityTypeLabel()` silently
-- falls through to showing the raw unrecognized string with no
-- translation. Bounding it to the known set at the DB level closes this.
--
-- Added `NOT VALID`: the live table already has real, pre-existing rows
-- with values outside this exact set (e.g. "Poultry Farming" instead of
-- "Poultry") — legacy data from before the client-side list settled, not
-- something this session created or has any business silently rewriting.
-- `NOT VALID` skips checking existing rows retroactively while still fully
-- enforcing the constraint for every future insert/update — the actual
-- goal here (closing the gap going forward), without touching real
-- members' historical data on a guess at what they "meant."
-- ─────────────────────────────────────────────────────────────────────────

alter table public.livelihood_activities add constraint livelihood_activities_activity_type_check
  check (activity_type = any(array['Dairy', 'Tailoring', 'Retail', 'Poultry', 'Agriculture', 'Handicrafts', 'Other'])) not valid;
