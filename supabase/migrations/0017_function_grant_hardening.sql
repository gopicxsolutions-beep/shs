-- Rounds 11-15 exhaustively audited RLS *policies* (who can read/write which
-- rows) and Edge Function auth. This migration covers a genuinely different
-- surface neither of those passes touched: PostgreSQL's own function-GRANT
-- defaults for every `security definer` function in the schema, and the
-- `anon` (fully unauthenticated) role's reach through them.
--
-- The footgun: Postgres grants EXECUTE on a newly created function to
-- PUBLIC automatically, unless the migration explicitly REVOKEs it. This is
-- the *opposite* of the default for tables/views (no PUBLIC access unless
-- explicitly granted), and it's easy to miss because `grant execute on
-- function ... to authenticated` *looks* like it's restricting the function
-- to signed-in users, when it's actually just ADDING a redundant grant on
-- top of the PUBLIC grant that's already there from creation — PUBLIC
-- includes `anon`, i.e. any completely unauthenticated request with just
-- the project's public anon key. Every migration since 0002 that defined a
-- new function did exactly this (granted to `authenticated`, never revoked
-- from `public`) with ONE exception:
-- `decrement_product_stock` (0008_marketplace_stock_decrement_rpc.sql) is
-- the only function in the whole schema that already got this right
-- (`revoke all ... from public;` right before its `grant ... to
-- authenticated;`) — used as the template for every fix below.
--
-- Full inventory of every `security definer` function in the schema (8
-- total, across 0002/0004/0008/0013) and its verdict:
--
--   current_role()               -- 0002, missing revoke. Harmless payload
--                                    (auth.uid() is null for anon -> query
--                                    matches no row -> returns null), fixed
--                                    here for defense-in-depth/consistency.
--   current_shg_id()             -- 0002, same as above. Harmless, fixed.
--   is_staff()                   -- 0002, same as above. Harmless, fixed.
--   is_leader_or_staff()         -- 0002, same as above. Harmless, fixed.
--   profile_shg_id(uuid)         -- 0002, missing revoke, AND a genuine
--                                    information-disclosure gap even for
--                                    `authenticated` (see below). Fixed.
--   approve_shg_join_request()   -- 0004, missing revoke. Already fails
--                                    closed for any unauthorized caller via
--                                    its own internal role/shg check
--                                    (raises "not authorized"), but closing
--                                    the PUBLIC default anyway removes a
--                                    minor request-id enumeration oracle
--                                    (the exception text differs for
--                                    "not found" vs "already decided" vs
--                                    "not authorized") and matches the
--                                    schema's own stated intent that this is
--                                    an `authenticated`-only RPC. Fixed.
--   decrement_product_stock(uuid)-- 0008, ALREADY correct (revoke+grant
--                                    present). No change needed.
--   shgs_current_row(uuid)       -- 0013, missing revoke, AND a genuine
--                                    information-disclosure gap even for
--                                    `authenticated` (see below). Fixed.
--
-- Two of the above are more than a hygiene nit — they're real reads of
-- RLS-restricted data with NO internal authorization check of their own,
-- because both were written purely as internal helpers for a single RLS
-- policy's own `with check`/comparison (where the calling policy already
-- constrains which row it's meaningful for), never anticipating that
-- PostgREST auto-exposes every function in `public` as
-- `/rest/v1/rpc/<name>`, directly callable by ANY authenticated user
-- (regardless of role/SHG) with an arbitrary argument:
--
-- 1. `profile_shg_id(p_member_id uuid)` — SECURITY DEFINER, so it bypasses
--    `profiles_select_self_shg_or_staff` RLS (which restricts full profile
--    reads to self/same-SHG/staff — 0002's own documented transparency
--    model, re-confirmed safe in round 13's SELECT sweep specifically
--    because it's same-SHG-only). The function itself does
--    `select shg_id from profiles where id = p_member_id` with NO caller
--    check at all — every one of its 5 call sites (0002's
--    `scheme_applications_select_related`/`course_progress_select_related`,
--    0015's `savings_insert_self_leader_or_staff`/
--    `meeting_attendance_self_or_leader`/`livelihood_write_self_leader_or_
--    staff`) only ever uses it as `profile_shg_id(x) = current_shg_id()` (or
--    `= shg_id`, itself already forced equal to `current_shg_id()` earlier
--    in the same `and`), i.e. purely an equality check against the CALLER's
--    own SHG. But called directly as an RPC, any signed-in member can pass
--    ANY profile id and get back that person's real `shg_id` — even for
--    someone in a completely different SHG the caller has no relationship
--    to at all. Combined with the public `shg_directory` view (village/
--    mandal/district per SHG, intentionally open to any authenticated user
--    for onboarding search), this lets any member resolve a specific other
--    member's UUID to their SHG's real-world location — a genuine privacy
--    leak for this app's rural-women user base, and a direct violation of
--    the same-SHG-only boundary every other profile-adjacent read in this
--    schema deliberately enforces. (A real path to obtain another member's
--    UUID already exists today: `marketplace_orders_select_related` exposes
--    `buyer_id` to the order's seller, even when buyer and seller are in
--    different SHGs.)
--    Fix: move the same-SHG gate INSIDE the function itself (return the
--    real `shg_id` only when it equals the caller's own, else null) rather
--    than leaving that check to be re-applied — or not — by every current
--    and future caller. Verified this is a no-op for all 5 existing policy
--    call sites: each already only cares about the equality outcome, and
--    `null = current_shg_id()` evaluates to null (falsy) exactly like the
--    old `<some other shg> = current_shg_id()` did.
--
-- 2. `shgs_current_row(p_id uuid)` — SECURITY DEFINER, bypasses
--    `shgs_select_own_or_staff` RLS (own-SHG-members + staff only — the
--    `shgs` base table is deliberately locked down because it also holds
--    `bank_account`/`ifsc`, per 0002's own header comment). The function
--    returns `grade`/`clf`/`vo` for ANY given shg id with no check at all.
--    Its only real caller, `shgs_update_leader_or_staff`'s `with check`
--    (0013), only ever invokes it with the row's own `id`, which the
--    policy's `using` clause has already pinned to `current_shg_id()` for
--    the leader branch — but called directly as an RPC, any authenticated
--    user (any member of ANY SHG, not just leaders) can pass a different
--    SHG's id and learn its externally-assessed NABARD/bank grade and
--    CLF/VO federation affiliation, data the schema otherwise restricts to
--    that SHG's own members + staff.
--    Fix: same pattern — gate inside the function (only return a row when
--    `p_id` is the caller's own SHG or the caller is staff), a no-op for the
--    one real call site (which never asks about a different SHG anyway).
--
-- record_loan_payment()/add_financial_ledger_entry() (0011) are NOT
-- SECURITY DEFINER (plain SECURITY INVOKER, confirmed by the absence of the
-- keyword and 0011's own comment) — they run with the CALLER's own
-- privileges, so the underlying `loans_update_leader_or_staff`/
-- `financial_ledger_insert_leader_or_staff` RLS policies already gate any
-- anon/wrong-role call (an anon caller's `auth.uid()` is null, so every
-- `member_id =`/`shg_id =`/`created_by =` check in those policies fails
-- closed). Genuinely out of this migration's `security definer` scope, but
-- their `grant ... to authenticated` (0011) has the identical missing-
-- revoke shape, so closed here too for consistency — belt-and-suspenders
-- only, not a fix for an actual exploit (verified no reachable bad outcome
-- for either function under RLS as an unauthenticated/wrong-role caller).

revoke all on function public.current_role() from public;
revoke all on function public.current_shg_id() from public;
revoke all on function public.is_staff() from public;
revoke all on function public.is_leader_or_staff() from public;
revoke all on function public.profile_shg_id(uuid) from public;
revoke all on function public.approve_shg_join_request(uuid, boolean) from public;
revoke all on function public.shgs_current_row(uuid) from public;
revoke all on function public.record_loan_payment(uuid, numeric) from public;
revoke all on function public.add_financial_ledger_entry(uuid, text, text, numeric, numeric, uuid) from public;

grant execute on function public.current_role() to authenticated;
grant execute on function public.current_shg_id() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_leader_or_staff() to authenticated;
grant execute on function public.profile_shg_id(uuid) to authenticated;
grant execute on function public.approve_shg_join_request(uuid, boolean) to authenticated;
grant execute on function public.shgs_current_row(uuid) to authenticated;
grant execute on function public.record_loan_payment(uuid, numeric) to authenticated;
grant execute on function public.add_financial_ledger_entry(uuid, text, text, numeric, numeric, uuid) to authenticated;

-- Close the profile_shg_id() information-disclosure gap: only ever reveal
-- the target member's shg_id when it's the CALLER's own SHG (matches every
-- existing call site's actual use, all of which only test for that
-- equality) — never a stranger's.
create or replace function public.profile_shg_id(p_member_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.shg_id
  from public.profiles p
  where p.id = p_member_id
    and p.shg_id = (select me.shg_id from public.profiles me where me.id = auth.uid());
$$;

-- Close the shgs_current_row() information-disclosure gap: only ever
-- reveal a SHG's grade/clf/vo to that SHG's own members or staff — matches
-- the one real call site (shgs_update_leader_or_staff's with check), which
-- only ever asks about the caller's own SHG in the first place.
create or replace function public.shgs_current_row(p_id uuid)
returns table (grade text, clf text, vo text)
language sql
security definer
stable
set search_path = public
as $$
  select s.grade, s.clf, s.vo
  from public.shgs s
  where s.id = p_id
    and (s.id = public.current_shg_id() or public.is_staff());
$$;
