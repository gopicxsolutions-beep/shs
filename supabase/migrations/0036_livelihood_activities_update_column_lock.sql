-- Follow-up to round 81 (0034, `savings_entries`): that migration fixed a
-- genuinely missing `with check` on `savings_entries` that rounds 46-48's
-- original "re-derive EVERY column, not just the one named in the bug
-- report" sweep (0023/0024) should have caught but didn't. This raised the
-- real possibility other tables were similarly missed. Systematic re-audit
-- of every UPDATE policy in the schema that's writable by more than one
-- distinct role/relationship (i.e. excluding tables where the only actor is
-- `is_staff()`, which has no room for this specific bug shape), focused on
-- the tables 0023/0024/0026/0029/0034 never re-derived column-by-column by
-- name: `livelihood_activities`, `payments`, `ai_advisor_logs`,
-- `course_progress`, `support_messages`, `shg_documents`, `analytics_kpis`,
-- `report_snapshots`, plus `marketplace_products`/`marketplace_reviews`/
-- `shg_join_requests` found along the way while building the full
-- inventory.
--
-- Full verdict — only `livelihood_activities` (fixed below) turned out to
-- be a real, new, previously-undisclosed gap:
--
--   payments_update_staff, analytics_kpis_write_staff,
--   report_snapshots_write_staff, financial_ledger_update_staff,
--   support_tickets_update_staff, scheme_applications_update_staff,
--   marketplace_reviews_moderate_staff -- all fully staff-only (`using`/
--     `with check` both just `is_staff()`), confirmed unchanged since
--     0012/0013/0014. No self/leader write branch exists for a column-lock
--     gap to hide behind — out of scope for this bug shape by construction.
--   ai_advisor_logs, support_messages, shg_join_requests -- none of these
--     three has an UPDATE policy defined anywhere in the schema (grepped
--     every migration for each table name; only SELECT/INSERT/DELETE
--     policies exist). With RLS enabled and zero permissive UPDATE policy,
--     Postgres denies the command outright for every non-owner role — zero
--     client-writable surface to lock down. (`shg_join_requests`'
--     leader/staff decision path goes through `approve_shg_join_request()`,
--     a `security definer` function that bypasses RLS entirely, same as
--     0004/0023 already established.)
--   shg_documents_write_leader_or_staff -- re-confirmed safe (0015/0024's
--     own verdict, re-derived fresh here rather than trusted): `shg_id` is
--     the only identity column and the `with check` already requires it
--     stay equal to the leader's own `current_shg_id()` — a leader cannot
--     reassign a document to a different SHG. `name`/`type`/`size`/
--     `storage_path` are the entire point of a leader managing her own
--     SHG's document list (renaming/correcting an uploaded file's record);
--     no other party's interests are at stake in her own SHG's own
--     document metadata.
--   course_progress_write_self_or_staff -- re-confirmed safe: the self
--     branch's `with check` doesn't lock `course_id`, so a member could in
--     principle retarget an existing progress row to a different course.
--     But `TrainingRepository.markCertified()` already lets a member
--     `upsert()` ANY `course_id` + `member_id: self` + `certified: true`
--     directly through the app's own supported flow with zero server-side
--     gate (0024's own explicit "self-certification IS the feature"
--     verdict) — a `with check` column lock here would close a REST path
--     that unlocks nothing the app doesn't already hand her on a plate
--     through a normal call. Not a real gap, just a redundant door next to
--     an already-open one.
--   marketplace_products_write_seller_or_staff -- re-confirmed safe:
--     `seller_id` is explicitly named in the `with check` itself
--     (`seller_id = auth.uid() or is_staff()`), so a seller cannot
--     reassign a listing to another seller. Every other column
--     (`name`/`description`/`price`/`stock`/`image_url`/`category`) is a
--     seller's own product listing — single-owner-scoped, no cross-party
--     victim, matches 0024's "not padded in" reasoning for the same shape
--     elsewhere.
--   meetings/meeting_minutes/meeting_attendance/meeting_action_items,
--   marketplace_orders, loans, announcements, savings_entries -- already
--     explicitly re-derived by name in 0023/0024/0026/0029/0034; not
--     revisited in this pass. `shgs_update_leader_or_staff`'s open
--     descriptive/bank-detail columns and `meeting_action_items`'s
--     `owner_id` cross-SHG gap are both pre-existing, disclosed, and
--     deliberately-not-unilaterally-changed judgment calls (0013/0015's own
--     written verdicts) — left as the team's own call, not re-litigated
--     here, same as round 81 did for `savings_entries`'s own disclosed
--     self-verification judgment call.
--
-- Scope note: this pass covered every UPDATE/FOR ALL policy currently
-- defined in the schema (cross-referenced against 0001's full table list),
-- but did not re-verify every INSERT/DELETE policy's column scope from
-- scratch — those are a different bug shape (already covered by 0015/0027's
-- dedicated INSERT sweep and 0014/0026's dedicated DELETE sweep) and out of
-- this migration's stated focus.
--
-- ─────────────────────────────────────────────────────────────────────────
-- livelihood_write_self_leader_or_staff (0015, still current) — the real,
-- new gap.
-- ─────────────────────────────────────────────────────────────────────────
-- Full column list (0001_init_schema.sql): id, shg_id, member_id,
-- activity_type, description, investment, revenue, status, created_at.
-- Current policy:
--   for all using (
--     member_id = auth.uid()
--     or (shg_id = current_shg_id() and current_role() = 'leader')
--     or is_staff()
--   ) with check (
--     member_id = auth.uid()
--     or (shg_id = current_shg_id() and current_role() = 'leader'
--         and profile_shg_id(member_id) = shg_id)
--     or is_staff()
--   );
-- 0015 added the `profile_shg_id(member_id) = shg_id` clause to close an
-- INSERT-side cross-SHG misattribution gap, but never revisited this for
-- UPDATE, and 0024's later full-schema pass only checked this table's
-- `created_at` (lumped in with `meetings`/`marketplace_products`/
-- `announcement_reads` as "single-owner-scoped, low-stakes, not fixed") —
-- it never re-derived `investment`/`activity_type`/`description`/`shg_id`
-- the way it did for `loans`/`marketplace_orders`, and never noticed the
-- self-branch's `with check` doesn't constrain `shg_id` AT ALL.
--
-- `LivelihoodRepository` (lib/repositories/livelihood_repository.dart) has
-- exactly one `.update()` call site anywhere in `lib/` (grepped) —
-- `updateProgress()`, which always sends exactly
-- `{'revenue': revenue, 'status': status}`, never any other column.
-- `addActivity()` only ever `.insert()`s. So, same as 0034's finding for
-- `savings_entries`, the app itself never needs a UPDATE to touch
-- `shg_id`/`member_id`/`activity_type`/`description`/`investment`/
-- `created_at` — locking them closes a direct-REST-bypass gap only, no
-- legitimate app behavior depends on them being writable.
--
-- Concretely reachable today via `PATCH /rest/v1/livelihood_activities`:
--   * Self branch: a member updating her OWN activity (`member_id =
--     auth.uid()` on both the old and new row) can also send an arbitrary
--     `shg_id` in the same request — the `with check`'s self clause never
--     references `shg_id` at all. `livelihood_home_page.dart` computes
--     `totalInvestment`/`totalRevenue` by folding `investment`/`revenue`
--     over `fetchForShg(shgId)`'s results, so a member can inject her own
--     (possibly fabricated) investment/revenue figures directly into a
--     COMPLETELY DIFFERENT SHG's livelihood dashboard totals just by
--     retargeting her own row's `shg_id` — cross-tenant data pollution the
--     `shg_id = current_shg_id()` scoping on every read query was supposed
--     to prevent.
--   * Both self and leader branches can freely rewrite `investment` (never
--     touched by `updateProgress()` after the initial `addActivity()`
--     insert) to any value — silently inflating or deflating the same
--     per-SHG `totalInvestment` figure, and the `profit = revenue -
--     investment` shown per-activity on the detail page, with no
--     independent review, under cover of an ordinary-looking "Update
--     Progress" action.
--   * Leader branch can rewrite `activity_type`/`description` for any
--     member's activity in her own SHG at any time — free-form
--     mischaracterization of what a fellow member's logged business
--     activity actually was, unrelated to legitimately recording her own
--     SHG's `revenue`/`status` progress updates.
--
-- Fix: same security-definer read-gated locked-fields pattern already
-- established for `savings_entries`/`loans`/`marketplace_orders`/
-- `announcements` (avoids the 0018/0019 self-referencing-subquery
-- recursion). `revenue` and `status` are deliberately left OUT of the lock
-- — they're the entire point of this policy's one legitimate write.
--
-- Same wrinkle 0024 hit for `announcements`: this table's write policy is a
-- single `for all` (covers INSERT too), and a locked-field lookup keyed on
-- the row's own id returns NO ROWS for a brand-new INSERT (the row doesn't
-- exist yet), which would make every `= (select ...)` comparison evaluate
-- to `= NULL` — always false — silently breaking every legitimate new
-- activity, not just the attack path. Fix: split into separate INSERT and
-- UPDATE(+DELETE) policies, same precedent 0014/0024 already established.
-- INSERT keeps 0015's exact scope/check unchanged (nothing to lock yet);
-- DELETE keeps the existing `using` clause unchanged (no column-lock
-- concern on a row that's being removed, not rewritten) — only the new
-- UPDATE policy adds the column freeze.

create or replace function public.livelihood_activities_locked_fields(p_id uuid)
returns table (shg_id uuid, member_id uuid, activity_type text, description text, investment numeric, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select l.shg_id, l.member_id, l.activity_type, l.description, l.investment, l.created_at
  from public.livelihood_activities l
  where l.id = p_id
    and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.livelihood_activities_locked_fields(uuid) from public;
grant execute on function public.livelihood_activities_locked_fields(uuid) to authenticated;

drop policy if exists "livelihood_write_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_insert_self_leader_or_staff" on public.livelihood_activities
  for insert with check (
    member_id = auth.uid()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and public.profile_shg_id(member_id) = shg_id
    )
    or public.is_staff()
  );

create policy "livelihood_update_self_leader_or_staff" on public.livelihood_activities
  for update using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  ) with check (
    public.is_staff()
    or (
      (member_id = auth.uid() or (shg_id = public.current_shg_id() and public.current_role() = 'leader'))
      and shg_id = (select f.shg_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and member_id = (select f.member_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and activity_type = (select f.activity_type from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and description is not distinct from (select f.description from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and investment is not distinct from (select f.investment from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and created_at = (select f.created_at from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    )
  );

create policy "livelihood_delete_self_leader_or_staff" on public.livelihood_activities
  for delete using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  );
