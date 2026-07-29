-- Follow-up to 0096: the live sweep query in that migration's own header
-- comment was run BEFORE writing the revoke list and somehow missed these
-- 4 state-mutating loan/marketplace RPCs from the generated list — a
-- process slip, not a different root cause. Same fix, same verified-safe
-- reasoning: `approve_loan`/`reject_loan`/`record_loan_payment`
-- (migration 0088) and `place_marketplace_order` (migration 0057) are all
-- already internally gated on `auth.uid()`-derived checks
-- (`is_leader_or_staff()`/`current_shg_id()`/`is_staff()`/`profile_is_
-- active()`), so `anon` (auth.uid() IS NULL) already fails every one of
-- them today — this closes the same defense-in-depth gap, not a live
-- exploit.

revoke execute on function public.approve_loan(uuid, numeric, date) from anon;
revoke execute on function public.reject_loan(uuid) from anon;
revoke execute on function public.record_loan_payment(uuid, numeric) from anon;
revoke execute on function public.place_marketplace_order(uuid) from anon;
