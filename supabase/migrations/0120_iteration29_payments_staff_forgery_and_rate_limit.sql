-- Gap-hunt iteration 29: Payments full sweep, 2 real gaps closed.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH] `payments_insert_self_or_staff`'s `is_staff()` disjunct let any
--    crp/clf/admin fabricate a "successful" payment for ANY member,
--    platform-wide — no restriction to the caller's own SHG, no
--    restriction on `member_id`, no restriction forbidding `status =
--    'success'` at insert time. Migration 0093's own comment explicitly
--    left this as a deliberate, deferred design question rather than fixed
--    at the time ("staff recording a payment on a member's behalf, a
--    plausible real assisted-payment workflow"). This round's audit
--    confirmed no such workflow actually exists: every real write path
--    (`PaymentRepository.pay()`, called only from `payments_qr_page.dart`)
--    always inserts with the caller's OWN `member_id`, never anyone
--    else's. This is the exact same shape this codebase already retired
--    for `loan_payments_insert_related` in migration 0110 (round 198) once
--    that branch was confirmed similarly unused — same reasoning applies
--    here. Retiring the disjunct entirely; if a genuine staff-assisted
--    payment feature is built later, it should be scoped to the member's
--    own SHG and forbid inserting directly as `status = 'success'` (only a
--    real gateway/webhook or a security-definer RPC should ever mark a
--    payment successful), not reopen this unrestricted branch.
--
-- 2. [MEDIUM] No INSERT rate limit on `payments`, unlike every sibling
--    high-frequency self-insert table hardened in this same migration
--    0090 round (`support_tickets` got `< 10/hour`; `announcements` got
--    `< 10/hour`; `support_messages` got `< 20/10min`) — `payments` was
--    named in that round's own comment as one of the tables being closed
--    together but never actually got the rate-limit half of the pattern.
--    A member could otherwise script unlimited valid-shaped payment
--    inserts in a tight loop with zero governance. Chosen limit (30/hour)
--    is deliberately generous since legitimate contribution payments can
--    be more frequent than a support ticket or announcement.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "payments_insert_self_or_staff" on public.payments;

create policy "payments_insert_self" on public.payments
  for insert with check (
    member_id = auth.uid()
    and public.profile_is_active(member_id)
    and created_at = now()
    and (
      select count(*) from public.payments p
      where p.member_id = auth.uid() and p.created_at > now() - interval '1 hour'
    ) < 30
  );
