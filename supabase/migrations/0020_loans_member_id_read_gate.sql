-- Round 39 (Loans-area audit) — independent re-verification of 0019's
-- recursion fix. The fix itself (moving the self-referencing read in
-- `loans_update_leader_or_staff`'s `with check` into a `security definer`
-- function, `loans_member_id()`) is CONFIRMED CORRECT by careful trace:
--
--   * Recursion-safety: identical mechanism to `marketplace_order_locked_fields`
--     (0018), which is live-verified in production three independent ways
--     (round 36), including specifically confirming a security-definer
--     function's internal query returns the row's CURRENTLY-STORED value,
--     not the new value being written by the same UPDATE statement
--     (`PATCH {"amount":1}` was still correctly rejected with 403 after the
--     0018 fix — proving the comparison isn't tautological/self-visible).
--     0002's own header comment confirms every table in this schema has
--     `force row level security` OFF, so the function owner genuinely
--     bypasses RLS on its internal `select ... from public.loans`,
--     breaking the recursion cycle exactly as intended.
--   * Logical correctness, traced step by step for the real workflow this
--     exists to support: leader L (shg_id S, role leader) updates a
--     pending loan with member_id = M (M <> L) to status='active'.
--     `using`: old shg_id = S = current_shg_id(), role = leader -> passes.
--     `with check`: shg_id(new) = S -> true; role = leader -> true;
--     member_id(new, unchanged) = loans_member_id(id) = M -> true;
--     loans_member_id(id) <> auth.uid() -> M <> L -> true. All true ->
--     UPDATE succeeds. For the ORIGINAL bug this branch exists to block
--     (leader self-approving her OWN loan, member_id = L): the final
--     `loans_member_id(id) <> auth.uid()` becomes `L <> L` -> false ->
--     whole check fails -> UPDATE correctly blocked. Staff bypass
--     (`is_staff()`) and out-of-SHG access (blocked by `using` before
--     `with check` is ever reached) both verified correct too. 0019 is a
--     genuinely sound fix for both the recursion regression and the
--     original self-approval vulnerability.
--
-- One NEW gap found while re-verifying it, matching a shape this session
-- already established and fixed once before (0017's `shgs_current_row`
-- hardening, for the exact same reason): `loans_member_id(p_loan_id uuid)`
-- is `security definer` with NO caller-authorization check of its own —
-- it was written as a pure "read this loan's stored member_id" helper,
-- correct for its one real call site (`loans_update_leader_or_staff`'s
-- `with check`, only ever invoked with a loan id the caller already has
-- `using`-clause-level access to). But called directly as an RPC — which
-- any authenticated user can do, since 0019 granted `execute` broadly —
-- it returns the `member_id` for ANY loan id in the ENTIRE system, with
-- zero regard for `loans_select_shg_or_staff` (own loan, own SHG, or
-- staff only). A member of SHG A could learn which member of SHG B (or
-- any other SHG) owns a given loan id, bypassing the same-SHG
-- confidentiality boundary this schema otherwise enforces everywhere else
-- for loan data. Exactly the same "correct for its one real call site,
-- but a real cross-tenant read when called directly" gap 0017 fixed for
-- `shgs_current_row` — same fix, applied here: gate the function's return
-- to only the cases `loans_select_shg_or_staff` would already allow (own
-- loan, own SHG, or staff), a no-op for the real call site (which never
-- asks about a loan outside that scope in the first place).

create or replace function public.loans_member_id(p_loan_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select l.member_id
  from public.loans l
  where l.id = p_loan_id
    and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id() or public.is_staff());
$$;
