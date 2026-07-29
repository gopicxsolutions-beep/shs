-- Gap-hunt round 190 (iteration 18): follow-up to 0099. That migration
-- fixed the 6 tables the Admin-module audit found; the independent
-- Savings-module audit (same round, different agent) flagged the exact
-- same shape on `meeting_attendance.member_id` too and prompted a full
-- live sweep (`pg_constraint` query for every remaining FK to
-- profiles(id)/shgs(id) still ON DELETE CASCADE) rather than fixing one
-- more table and stopping again.
--
-- The sweep found 14 more instances. This migration fixes the 5 that are
-- unambiguously real historical/financial/certification records, matching
-- the already-established precedent (loans/financial_ledger/savings_entries/
-- shg_documents/meetings/livelihood_activities, and specifically
-- `training_courses -> course_progress`'s own course_id fix, round 187,
-- for the exact same "don't silently erase a certification" reasoning
-- extended here to member_id):
--   - meeting_attendance.member_id: real attendance history
--   - scheme_applications.member_id: real government-scheme application/
--     decision history (DAY-NRLM record-keeping context)
--   - course_progress.member_id: real certification history — the member_id
--     side of the exact fix 0090's course_id-side RESTRICT already made
--   - payments.member_id: real financial transaction history
--   - marketplace_products.seller_id: real listing/order history (a
--     product with real orders against it would already be blocked from
--     cascading by marketplace_orders' own FK; this closes the remaining
--     case of a product with no orders yet)
--
-- The remaining 9 (announcements.shg_id, announcement_reads.member_id,
-- support_tickets.member_id, ai_advisor_logs.member_id, report_snapshots.
-- shg_id, analytics_kpis.shg_id, shg_join_requests.member_id/shg_id,
-- shg_bank_details.shg_id) are deliberately NOT changed here — each is
-- either clearly-derived/regenerable data (report_snapshots, analytics_kpis
-- are point-in-time analytics caches), a read-receipt/workflow record with
-- no independent evidentiary value once its subject is gone (announcement_
-- reads, shg_join_requests), or a genuine data-retention policy question
-- rather than a bug (support_tickets/ai_advisor_logs: is a deleted
-- member's complaint/AI-chat history something staff should be required to
-- retain, or should it go with her account? — a deliberate product/legal
-- decision, not something to default to RESTRICT without that call being
-- made). Documented here rather than silently dropped.

alter table public.meeting_attendance drop constraint meeting_attendance_member_id_fkey;
alter table public.meeting_attendance add constraint meeting_attendance_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;

alter table public.scheme_applications drop constraint scheme_applications_member_id_fkey;
alter table public.scheme_applications add constraint scheme_applications_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;

alter table public.course_progress drop constraint course_progress_member_id_fkey;
alter table public.course_progress add constraint course_progress_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;

alter table public.payments drop constraint payments_member_id_fkey;
alter table public.payments add constraint payments_member_id_fkey foreign key (member_id) references public.profiles (id) on delete restrict;

alter table public.marketplace_products drop constraint marketplace_products_seller_id_fkey;
alter table public.marketplace_products add constraint marketplace_products_seller_id_fkey foreign key (seller_id) references public.profiles (id) on delete restrict;
