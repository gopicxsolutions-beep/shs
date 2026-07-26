-- Closes a residual gap left by 0045_join_request_visibility_and_bank_detail_masking.sql.
--
-- 0045 correctly identified that `shgs.bank_account`/`ifsc` were readable by
-- any ordinary member (not just leader/staff) via a plain `select *` against
-- `shgs`, and fixed the app's own read path by adding `shg_own_masked` (a
-- view that nulls those two columns unless the caller is leader/staff) and
-- switching `ShgRepository.fetchShg()` to read from it instead.
--
-- But `shgs_select_own_or_staff` itself — the base table's own SELECT
-- policy — was never tightened:
--   (id = current_shg_id()) or is_staff()
-- Postgres RLS is row-level, not column-level: this still grants any member
-- of the SHG full-column access to the base `shgs` row, bank_account/ifsc
-- included. The masked view only protects callers who choose to query it —
-- a client that queries `/rest/v1/shgs?select=bank_account,ifsc&id=eq.<id>`
-- directly (trivial: any member's own already-valid session JWT + browser
-- devtools, no special access needed) still gets the real values. Live-
-- confirmed this round: `set local request.jwt.claims` as a genuine
-- plain-member test account, `select bank_account, ifsc from public.shgs
-- where id = <her own shg>` succeeded and returned the real column values
-- (this specific SHG's were null, i.e. never populated, so nothing was
-- actually exposed by the verification itself — but the policy imposed no
-- block, which is the bug: any SHG that DOES have these populated remains
-- exposed to its own ordinary members today). This directly contradicts
-- this project's own stated model for these two columns ("shgs.bank_account/
-- ifsc are sensitive -- never expose through a broadly-readable view") and
-- the standing "RLS is authorization, client checks are UX only" rule.
--
-- 0045's own comment already correctly ruled out fixing this with a
-- column-level GRANT/REVOKE: every authenticated app user shares the single
-- Postgres `authenticated` role, so a column grant can't be conditioned on
-- "is this caller leader-of-THIS-row" (a per-row, per-caller fact) — it can
-- only be table-wide. The only way to make bank_account/ifsc genuinely
-- unreadable to a non-leader/staff caller, from ANY query shape including a
-- direct base-table hit, is to move them to their own table with their own
-- row-level policy.
--
-- No live write path sets these columns today (grep-confirmed: neither
-- ShgRepository.createShg() nor updateShg() touch bank_account/ifsc in live
-- mode; shg_home_page.dart only ever reads them). AdminShgsPage's "Manage
-- SHGs" list/detail (backed by fetchAllShgs(), a plain `select()` against
-- the base `shgs` table) also never references .bankAccount/.ifsc in its
-- own rendering — so dropping these two columns from `shgs` has zero
-- observable effect on any existing Dart code path except shg_own_masked
-- itself, updated below in the same migration.

create table public.shg_bank_details (
  shg_id uuid primary key references public.shgs(id) on delete cascade,
  bank_account text,
  ifsc text
);

insert into public.shg_bank_details (shg_id, bank_account, ifsc)
select id, bank_account, ifsc from public.shgs
where bank_account is not null or ifsc is not null;

alter table public.shg_bank_details enable row level security;

-- Mirrors shgs_select_own_or_staff's row scope exactly, but this is the
-- ONLY policy on this table (no "or any member" clause exists here at all —
-- that's the entire point of splitting it out) and there is deliberately no
-- current_role() = 'leader' shortcut elsewhere in the schema that a member
-- could hit instead.
create policy "shg_bank_details_select_leader_or_staff" on public.shg_bank_details
  for select using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

-- No live UI writes this table yet, but the write GRANT on these two
-- specific columns already had an explicit, deliberate scope before this
-- migration: `shgs_update_leader_or_staff`'s own WITH CHECK only protects
-- grade/clf/vo from the leader branch (0013's own comment: "keep the leader
-- able to self-service the ordinary descriptive/operational fields (name,
-- address fields, bank details...)"), and 0024_every_column_recheck_gaps.sql
-- later re-examined that exact choice and explicitly declined to narrow it
-- ("bank_account/ifsc self-service with no admin review is arguably worth a
-- second look, but not unilaterally changed here"). This migration fixes an
-- unrelated bug (unauthorized READ by non-leader members) — it must not
-- also silently relitigate that already-recorded, deliberately-left-open
-- WRITE decision by narrowing it to staff-only. Mirrors
-- shgs_update_leader_or_staff's own leader-or-staff shape exactly, just
-- keyed on shg_id instead of id.
create policy "shg_bank_details_write_leader_or_staff" on public.shg_bank_details
  for all using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

revoke all on public.shg_bank_details from public;
grant select, insert, update, delete on public.shg_bank_details to authenticated;

-- Replace shg_own_masked to source the two sensitive columns from the new
-- table instead of the still-live shgs columns, BEFORE those columns are
-- dropped below — the view must stop depending on shgs.bank_account/ifsc
-- before DROP COLUMN can succeed (a first attempt at this migration hit
-- exactly this ordering error live: "cannot drop column bank_account of
-- table shgs because other objects depend on it", cleanly rolled back as a
-- whole transaction, no partial state). Same row scope, same masking
-- condition, same security_invoker = false (the view still needs to read
-- shg_bank_details as its owner, bypassing the querying session's own RLS
-- on that table, then re-applies the leader/staff check itself via the
-- CASE — identical pattern to before, just pointed at the new source).
create or replace view public.shg_own_masked
with (security_invoker = false) as
  select
    s.id, s.name, s.reg_number, s.formation_date, s.village, s.mandal, s.district, s.state,
    s.bank_name, s.grade, s.clf, s.vo,
    case when public.is_leader_or_staff() then b.bank_account else null end as bank_account,
    case when public.is_leader_or_staff() then b.ifsc else null end as ifsc
  from public.shgs s
  left join public.shg_bank_details b on b.shg_id = s.id
  where s.id = public.current_shg_id() or public.is_staff();

grant select on public.shg_own_masked to authenticated;

alter table public.shgs drop column bank_account;
alter table public.shgs drop column ifsc;
