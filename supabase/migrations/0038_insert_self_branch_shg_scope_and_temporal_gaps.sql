-- Fresh, adversarial re-derivation of every `for insert`/INSERT-half-of-
-- `for all` policy in the schema, explicitly NOT trusting 0015/0027's own
-- "verified correct" verdicts (the same discipline rounds 81/82 (0034/0035/
-- 0036) applied to the UPDATE sweep after finding it had missed real gaps on
-- `savings_entries`/`meeting_attendance`/`livelihood_activities` despite
-- those tables already having been through 46-48's "every column" pass).
-- Read every INSERT-capable policy's CURRENT definition (after every later
-- migration that touched it), cross-checked against 0001's full column list
-- and every real `lib/repositories/**/.insert()`/`.upsert()` call site.
--
-- Full re-derived verdict for every table (29 tables total; only the 4
-- below were real, new gaps — everything else re-confirmed already correct,
-- not re-asserted from memory):
--
--   profiles_insert_self (0022)                 -- safe: id/role/shg_id all locked
--   shgs_insert_staff                            -- safe: staff-only
--   shg_documents_write_leader_or_staff          -- safe: shg_id is the only
--     identity column and is already scoped; storage_path re-checked this
--     round too (a leader could point a row's storage_path at a path outside
--     her own SHG's folder, but `storage.objects`' own SELECT RLS (0005) is
--     keyed off the REQUESTING caller's `current_shg_id()`, not off what this
--     table's row claims, so a signed-URL request for a mismatched path
--     always fails for every SHG but the one that actually owns that
--     storage folder — a dead link at worst, not a cross-tenant read)
--   savings_insert_self_leader_or_staff          -- BUGGY, fixed below (#1)
--   loans_insert_self (0027)                     -- safe: member_id AND
--     shg_id = current_shg_id() are ANDed together in the policy's one and
--     only branch (unlike #1/#2 below, there's no separate self-vs-leader
--     structure to miss half of)
--   loan_payments_insert_related                 -- unchanged, still the
--     team's own disclosed judgment call (0027) — bypasses the atomic RPC
--     but doesn't corrupt any balance actually trusted elsewhere; not
--     re-litigated
--   meetings_insert_leader_or_staff (0026)       -- safe: shg_id is the only
--     identity column, already scoped; `status`/`meeting_date` starting
--     value re-checked and judged low-stakes (single-owner-SHG-scoped
--     record, `setStatus()` is never called by the app at all so `status`
--     is inert either way, and nothing downstream trusts a fabricated
--     'completed'/'cancelled' row as anyone else's compliance record)
--   meeting_attendance_insert_self_or_leader (0026) -- BUGGY, fixed below (#3)
--   meeting_minutes_insert_leader_or_staff (0026)   -- BUGGY, fixed below (#4)
--   meeting_action_items_write_related           -- unchanged, still the
--     team's own disclosed judgment call (0015) — re-verified
--     `meeting_mom_page.dart`'s `_addActionItem()` still never passes
--     `ownerId`, so the reasoning still holds
--   financial_ledger_insert_leader_or_staff (0027) -- safe: created_by/
--     entry_date/created_at/balance all locked; no member_id column on this
--     table at all, so the #1/#2 shape below doesn't apply
--   livelihood_insert_self_leader_or_staff (0036) -- BUGGY, fixed below (#2)
--   marketplace_products_write_seller_or_staff    -- safe: seller_id is
--     named directly in the check; no shg concept on this table
--   marketplace_orders_insert_authenticated (0027) -- safe: buyer_id/status/
--     order_date/created_at all locked; `amount` still not tied to
--     `marketplace_products.price` by a `with check` remains 0027's own
--     disclosed, deliberately-not-fixed judgment call (atomicity trade-off)
--     -- re-verified `placeOrder()` still always inserts the RPC-verified
--     price, not the raw parameter, so still low real-world risk
--   marketplace_reviews_insert_authenticated (0032) -- safe: reviewer_id
--     locked to null-or-self plus a real-purchase check, duplicate-review
--     unique index in place
--   schemes_write_admin                           -- safe: admin-only
--   scheme_applications_insert_self (0030)        -- safe: member_id/status/
--     applied_on locked, deadline-enforcement exists() added since 0027
--   training_courses_write_staff                  -- safe: staff-only
--   course_progress_write_self_or_staff           -- safe (re-verified,
--     not just re-asserted): `markCertified()` already lets a member
--     self-certify ANY course_id at 100%/true through the app's own
--     supported call with zero server gate, so a `with check` here would
--     block nothing the app doesn't already hand her directly
--   payments_insert_self_or_staff (0013)          -- unchanged, still the
--     team's own disclosed judgment call (0027) — `status` genuinely
--     client-computed under today's mock-gateway architecture; re-verified
--     `PaymentRepository.pay()` still writes the mock processor's own result
--   announcements_insert_leader_or_staff (0027)   -- safe: created_by/
--     created_at both locked
--   announcement_reads_self_or_staff              -- re-derived, low-stakes:
--     `member_id = auth.uid()` already prevents marking on someone else's
--     behalf; `read_at` is never read back anywhere in `lib/` (grepped) and
--     `announcement_id` isn't secret/sensitive to reference — not fixed
--   support_tickets_insert_self (0027)            -- safe: member_id/status/
--     created_at all locked
--   support_messages_insert_related               -- safe: sender_id pinned
--     to auth.uid(), ticket membership re-checked via exists()
--   ai_advisor_logs_insert_self                   -- re-derived, low-stakes:
--     member_id pinned to self, advisor_type constrained by its own CHECK,
--     query/response/created_at are a personal-scoped usage log with no
--     shared/cross-user visibility beyond is_staff() — not fixed
--   report_snapshots_write_staff                  -- safe: staff-only
--   analytics_kpis_write_staff                    -- safe: staff-only
--   audit_log_insert_self                         -- unchanged, still the
--     team's own disclosed judgment call (0027) — re-verified: still 100%
--     unused by `lib/` (grepped, zero write call sites)
--   shg_join_requests_insert_self (0027)          -- safe: member_id/status/
--     requested_at/decided_at/decided_by all locked
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1 & 2. savings_insert_self_leader_or_staff / livelihood_insert_self_
--    leader_or_staff — THE headline finding, the identical shape on BOTH
--    tables: the SELF branch of `with check` was NEVER given a `shg_id`
--    constraint, only the LEADER branch was (0015's own fix). A plain
--    member can self-insert a savings deposit or livelihood activity
--    crediting HERSELF but attributed to a COMPLETELY DIFFERENT SHG.
-- ─────────────────────────────────────────────────────────────────────────
-- 0015's own header comment for fix #1 (savings) framed the bug as "a
-- LEADER could record a savings deposit against a member who ISN'T actually
-- in her SHG" and fixed exactly that — adding `profile_shg_id(member_id) =
-- shg_id` to the LEADER branch only. It never asked the mirror question:
-- does the SELF branch (`member_id = auth.uid()`, present unchanged since
-- 0002) verify that the `shg_id` being posted into is HER OWN? It does not,
-- and never has, through 0015, 0027 (which wrapped this same self-branch in
-- a lifecycle-column AND without touching its shg_id scope), or round 81's
-- dedicated `savings_entries` deep-dive (0034 — UPDATE policy only, this is
-- INSERT). Same story for `livelihood_write_self_leader_or_staff` /
-- `livelihood_insert_self_leader_or_staff`: 0015 added the identical
-- `profile_shg_id()` guard to ITS leader branch only, and round 82's own
-- dedicated `livelihood_activities` deep-dive (0036) fixed the UPDATE
-- policy's column-lock gaps but explicitly scoped itself to UPDATE only
-- (its own header: "did not re-verify every INSERT/DELETE policy's column
-- scope from scratch... out of this migration's stated focus") — leaving
-- this exact INSERT-side gap for this round to find.
--
-- Concrete exploit, `savings_entries` (member_id/shg_id/entry_date/amount/
-- mode/frequency/status/created_at per 0001):
--   POST /rest/v1/savings_entries
--   {"member_id": "<self>", "shg_id": "<any OTHER real SHG's id>",
--    "amount": 5000, "mode": "Cash", "frequency": "Weekly"}
--   (status/entry_date/created_at all still forced to
--   'pending'/current_date/now() by 0027 — that part of the check already
--   holds — but `shg_id` sails through untouched.)
-- This inserts a "pending" deposit into a COMPLETELY UNRELATED SHG's
-- savings book. That other SHG's own leader legitimately sees it via
-- `savings_select_shg_or_staff` (`shg_id = current_shg_id()`) sitting in
-- her verification queue next to her real members' entries, with nothing
-- distinguishing it as fraudulent, and can "Verify" it in good faith —
-- at which point it's instantly-real, counted group savings for a member
-- who was never part of that group at all, corrupting that SHG's total
-- savings figure and (per 0013's own comment) the `shgs.grade` figure that
-- gates loan/scheme eligibility for every ACTUAL member of that group.
-- `livelihood_activities` (shg_id/member_id/activity_type/description/
-- investment/revenue/status/created_at) has the identical exploit shape,
-- injecting fabricated investment/revenue directly into
-- `livelihood_home_page.dart`'s `fetchForShg(shgId)`-folded
-- `totalInvestment`/`totalRevenue` for a group the inserting member was
-- never part of.
--
-- Verified against the app's own call sites (both `SavingsEntryPage`'s
-- `_submit()` and `LivelihoodEntryPage`'s equivalent) that `shgId` is
-- ALWAYS `appState.profile?.shgId` — the caller's own SHG — for both the
-- member-self and leader-on-behalf-of cases; the app itself never sends any
-- other value. Closing this at the RLS layer costs zero real functionality,
-- matching every other fix in this migration series.
drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    public.is_staff()
    or (
      status = 'pending'
      and entry_date = current_date
      and created_at = now()
      and (
        (member_id = auth.uid() and shg_id = public.current_shg_id())
        or (
          shg_id = public.current_shg_id()
          and public.current_role() = 'leader'
          and public.profile_shg_id(member_id) = shg_id
        )
      )
    )
  );

drop policy if exists "livelihood_insert_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_insert_self_leader_or_staff" on public.livelihood_activities
  for insert with check (
    (member_id = auth.uid() and shg_id = public.current_shg_id())
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and public.profile_shg_id(member_id) = shg_id
    )
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. meeting_attendance_insert_self_or_leader — the SELF branch has no
--    temporal restriction at all, so a member can self-check-in "present"
--    for ANY meeting in her own SHG via direct REST, not just today's —
--    the exact fraud round 80 closed, but only in the Dart-side UI filter
--    that picks which meeting the QR page's INSERT-shaped upsert targets,
--    never in the underlying RLS policy itself.
-- ─────────────────────────────────────────────────────────────────────────
-- Round 80 added `Meeting.isScheduledToday` and switched
-- `meeting_qr_page.dart`'s self-check-in "next meeting" filter to it,
-- specifically so a member can't self-mark "present" for a meeting that's
-- still days/weeks away. Round 82's own dedicated `meeting_attendance`
-- deep-dive (0035) explicitly re-traced this exact question and documented,
-- in its own header comment, that round 80's fix "only touches which
-- meeting the app's OWN INSERT-shaped upsert targets" and closed the
-- adjacent UPDATE-side retarget-an-existing-row gap that reaches the same
-- fraud "one HTTP verb over" — but the underlying INSERT policy itself
-- (`meeting_attendance_insert_self_or_leader`, 0026) was never touched by
-- either round and still has no date check on its self branch today.
--
-- Concrete exploit: a member sends
--   POST /rest/v1/meeting_attendance
--   {"meeting_id": "<any meeting in her own SHG, e.g. one scheduled 3 weeks
--    out, or one already completed weeks ago that she never attended>",
--    "member_id": "<self>", "present": true}
-- and it succeeds today — `meeting_attendance_insert_self_or_leader`'s self
-- branch only checks `member_id = auth.uid()` and that the meeting belongs
-- to her own SHG, nothing about its date. This directly feeds
-- `avg_attendance_pct` (`analytics_repository.dart` groups
-- `meeting_attendance.present`/`meeting_id` verbatim), the same
-- SHG-grading/health-score figure round 80 was originally trying to
-- protect.
--
-- Fix: add the same day-granularity restriction to the SELF branch only —
-- `meeting_qr_page.dart` (the only self-check-in call site anywhere in
-- `lib/`, grepped) already never sends a `meeting_id` that fails this,
-- since it's pre-filtered to `isScheduledToday`, so this costs zero real
-- app functionality. The LEADER branch is deliberately left untouched:
-- 0035 already re-traced and re-confirmed, fresh, that a leader
-- pre-marking or backfilling attendance on her own roster for a
-- future/past meeting via her own authenticated action is a legitimate,
-- deliberately-provisioned capability (`meeting_attendance_page.dart`'s own
-- picker lets her select any of her SHG's meetings, not just today's) —
-- not re-litigating that verdict here, only closing the unsupervised
-- self-service path it was never meant to cover.
drop policy if exists "meeting_attendance_insert_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_insert_self_or_leader" on public.meeting_attendance
  for insert with check (
    (
      member_id = auth.uid()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.meeting_date = current_date
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
    )
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. meeting_minutes_insert_leader_or_staff — `created_at` was never locked,
--    letting a leader/staff post a fabricated minutes entry dated far in
--    the future so it permanently wins the "latest minutes" query over any
--    real entry recorded afterward.
-- ─────────────────────────────────────────────────────────────────────────
-- `meeting_minutes` (id/meeting_id/decisions/created_at per 0001) is, by
-- the app's own design, append-only: `MeetingRepository.saveMinutes()`
-- (the only call site anywhere in `lib/`, grepped) always
-- `.insert()`s a brand-new row and never sends `created_at`, relying on the
-- column default; `fetchLatestMinutes()` is the ONLY read path
-- (`meeting_mom_page.dart`), and it always resolves "what did this meeting
-- decide" via `order('created_at', ascending: false).limit(1)` — the single
-- most-recent row wins, unconditionally. 0026's own header comment already
-- established this table's DELETE branch needed staff-only locking
-- specifically because minutes are this schema's "durable record of what a
-- meeting decided," but never asked whether the INSERT side could be used
-- to the same effect without deleting anything.
--
-- Concrete exploit: a leader posts
--   POST /rest/v1/meeting_minutes
--   {"meeting_id": "<her own SHG's meeting>", "decisions": ["<fabricated>"],
--    "created_at": "2099-01-01T00:00:00Z"}
-- and it succeeds today. Every subsequent GENUINE minutes entry for that
-- same meeting — recorded with a real `now()` timestamp, necessarily
-- earlier than year 2099 — permanently loses the `order by created_at desc
-- limit 1` comparison, so `fetchLatestMinutes()` keeps surfacing the
-- fabricated entry forever, no matter how many real corrections are filed
-- afterward. This is the identical "falsify created_at to win a
-- most-recent-wins query" shape 0024/0027 already closed for
-- `announcements`, just never applied to this table.
--
-- Fix: lock `created_at = now()`, same technique as every other
-- `created_at` lock in this migration series — safe because a column's own
-- `default now()` and a `with check (col = now())` in the same INSERT
-- statement observe the identical transaction-start `now()` value when the
-- caller omits the column, which `saveMinutes()` always does.
drop policy if exists "meeting_minutes_insert_leader_or_staff" on public.meeting_minutes;

create policy "meeting_minutes_insert_leader_or_staff" on public.meeting_minutes
  for insert with check (
    (
      exists (
        select 1 from public.meetings m
        where m.id = meeting_minutes.meeting_id
          and m.shg_id = public.current_shg_id()
          and public.current_role() = 'leader'
      ) or public.is_staff()
    )
    and created_at = now()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Migration-numbering note: 0036 was the highest migration on disk when
-- this file's audit started; `0037_select_scope_overexposure_fix.sql`
-- appeared (a concurrently-run sibling agent's SELECT-scope audit) before
-- this file was written, so this one claims `0038` instead. Both are
-- independent, non-overlapping changes (SELECT-policy scope vs.
-- INSERT-policy scope, no shared table/policy touched by both), but the
-- orchestrator should double-check no THIRD concurrent agent also claimed
-- 0038 before deploying, same numbering-collision risk round 82 already
-- documented and resolved once this session.
-- ─────────────────────────────────────────────────────────────────────────
