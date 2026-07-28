-- loans.shg_id / loans.member_id: change ON DELETE CASCADE to ON DELETE
-- RESTRICT — a routine admin action (deleting a duplicate/inactive member
-- profile, or a defunct SHG) must not silently destroy real loan and
-- payment history.
--
-- Found during a broad gap-hunting audit. `profiles_delete_admin` and
-- `shgs_delete_admin` (0002_rls_policies.sql) correctly scope WHO can
-- delete a profile/SHG (admin only) — that part is not the gap.
-- `0039_delete_scope_audit_cascade_and_evidence_gaps.sql` fixed the
-- equivalent cascade-blast-radius problem for `marketplace_products`,
-- `livelihood_activities`, and `announcements` by restricting WHO could
-- delete the PARENT row (the actual vulnerability there was a
-- non-staff self-service delete destroying shared evidence). Loans is a
-- different shape: the admin-only deleter is already correctly scoped, but
-- the cascade itself is the problem — an admin legitimately deleting one
-- duplicate profile, or one defunct SHG, takes every loan and loan_payment
-- that member/SHG ever had down with it in the same transaction, including
-- loans with real outstanding balances still owed to the group. There is
-- no archival, no "block if outstanding > 0" check, nothing.
--
-- RESTRICT (rather than adding a conditional trigger) is the simplest
-- correct fix: it forces an explicit decision before a profile/SHG with
-- loan history can ever be removed, instead of silent data loss. An admin
-- who genuinely needs to remove such a profile/SHG must first settle what
-- to do with its loans (transfer, close out, or a deliberate future
-- archival migration) rather than have Postgres do it for them by
-- accident. `loan_payments.loan_id` is left as CASCADE — once a loan
-- itself can no longer disappear via this path, a loan's own payments
-- cascading with it (on the vanishingly rare case a loan row is ever
-- directly deleted, which no RLS policy currently even permits) is no
-- longer part of this same blast-radius problem.

alter table public.loans drop constraint loans_shg_id_fkey;
alter table public.loans add constraint loans_shg_id_fkey foreign key (shg_id) references public.shgs (id) on delete restrict;

alter table public.loans drop constraint loans_member_id_fkey;
alter table public.loans add constraint loans_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;
