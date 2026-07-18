-- Production-hardening pass: indexes on every FK/filter column RLS policies
-- and report/analytics queries rely on (none existed before this migration
-- beyond one partial unique index), missing CHECK constraints, an
-- updated_at audit trail on mutable financial tables, and a real unique
-- constraint + upsert target for report_snapshots (previously worked around
-- via non-atomic delete-then-insert in generate-report-snapshots).
--
-- Pre-flight verified against the live project before writing this file:
-- zero rows would violate any constraint added here (financial_ledger has
-- no null created_by, loans has no negative outstanding/non-positive
-- tenure, marketplace_orders has no non-positive amount, payments has no
-- duplicate non-null references, report_snapshots has no duplicate
-- (shg_id, report_type, period) groups) — safe to apply directly.

-- ─────────────────────────────────────────────────────────────────────────
-- Indexes: every FK column RLS policies filter on, plus common ordering
-- columns for history/ledger/log-style listings.
-- ─────────────────────────────────────────────────────────────────────────

create index if not exists profiles_shg_id_idx on public.profiles (shg_id);
create index if not exists shg_documents_shg_id_idx on public.shg_documents (shg_id);
create index if not exists savings_entries_shg_id_idx on public.savings_entries (shg_id);
create index if not exists savings_entries_member_id_idx on public.savings_entries (member_id);
create index if not exists savings_entries_created_at_idx on public.savings_entries (created_at desc);
create index if not exists loans_shg_id_idx on public.loans (shg_id);
create index if not exists loans_member_id_idx on public.loans (member_id);
create index if not exists loan_payments_loan_id_idx on public.loan_payments (loan_id);
create index if not exists meetings_shg_id_idx on public.meetings (shg_id);
create index if not exists meetings_meeting_date_idx on public.meetings (meeting_date desc);
create index if not exists meeting_attendance_meeting_id_idx on public.meeting_attendance (meeting_id);
create index if not exists meeting_attendance_member_id_idx on public.meeting_attendance (member_id);
create index if not exists meeting_minutes_meeting_id_idx on public.meeting_minutes (meeting_id);
create index if not exists meeting_action_items_meeting_id_idx on public.meeting_action_items (meeting_id);
create index if not exists financial_ledger_shg_id_idx on public.financial_ledger (shg_id);
create index if not exists financial_ledger_entry_date_idx on public.financial_ledger (entry_date desc);
create index if not exists livelihood_activities_shg_id_idx on public.livelihood_activities (shg_id);
create index if not exists livelihood_activities_member_id_idx on public.livelihood_activities (member_id);
create index if not exists marketplace_products_seller_id_idx on public.marketplace_products (seller_id);
create index if not exists marketplace_orders_product_id_idx on public.marketplace_orders (product_id);
create index if not exists marketplace_reviews_product_id_idx on public.marketplace_reviews (product_id);
create index if not exists scheme_applications_scheme_id_idx on public.scheme_applications (scheme_id);
create index if not exists scheme_applications_member_id_idx on public.scheme_applications (member_id);
create index if not exists course_progress_course_id_idx on public.course_progress (course_id);
create index if not exists course_progress_member_id_idx on public.course_progress (member_id);
create index if not exists payments_member_id_idx on public.payments (member_id);
create index if not exists announcements_shg_id_idx on public.announcements (shg_id);
create index if not exists announcement_reads_member_id_idx on public.announcement_reads (member_id);
create index if not exists support_tickets_member_id_idx on public.support_tickets (member_id);
create index if not exists support_messages_ticket_id_idx on public.support_messages (ticket_id);
create index if not exists ai_advisor_logs_member_id_idx on public.ai_advisor_logs (member_id);
create index if not exists ai_advisor_logs_created_at_idx on public.ai_advisor_logs (created_at desc);
create index if not exists report_snapshots_shg_id_idx on public.report_snapshots (shg_id);
create index if not exists analytics_kpis_shg_id_idx on public.analytics_kpis (shg_id);
create index if not exists audit_log_actor_id_idx on public.audit_log (actor_id);
create index if not exists shg_join_requests_shg_id_idx on public.shg_join_requests (shg_id);
create index if not exists shg_join_requests_member_id_idx on public.shg_join_requests (member_id);

-- ─────────────────────────────────────────────────────────────────────────
-- Missing CHECK constraints (every other money/quantity column in the
-- schema already has one of these — these four were inconsistently missed).
-- ─────────────────────────────────────────────────────────────────────────

alter table public.loans add constraint loans_outstanding_check check (outstanding >= 0);
alter table public.loans add constraint loans_tenure_months_check check (tenure_months > 0);
alter table public.marketplace_orders add constraint marketplace_orders_amount_check check (amount > 0);

-- ─────────────────────────────────────────────────────────────────────────
-- Audit-trail gap: financial_ledger is the audit ledger itself, so a row
-- with no actor attached defeats its purpose. Verified zero existing nulls
-- before adding not null.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.financial_ledger alter column created_by set not null;

-- payments.reference: no duplicates once set (nulls allowed for
-- not-yet-referenced pending payments) — prevents a webhook for one
-- payment's reference from being able to match/flip a different payment.
create unique index if not exists payments_reference_uidx on public.payments (reference) where reference is not null;

-- ─────────────────────────────────────────────────────────────────────────
-- updated_at audit trail on mutable financial tables (none existed before).
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

alter table public.loans add column if not exists updated_at timestamptz not null default now();
alter table public.savings_entries add column if not exists updated_at timestamptz not null default now();
alter table public.payments add column if not exists updated_at timestamptz not null default now();
alter table public.financial_ledger add column if not exists updated_at timestamptz not null default now();

drop trigger if exists loans_set_updated_at on public.loans;
create trigger loans_set_updated_at before update on public.loans for each row execute function public.set_updated_at();

drop trigger if exists savings_entries_set_updated_at on public.savings_entries;
create trigger savings_entries_set_updated_at before update on public.savings_entries for each row execute function public.set_updated_at();

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at before update on public.payments for each row execute function public.set_updated_at();

drop trigger if exists financial_ledger_set_updated_at on public.financial_ledger;
create trigger financial_ledger_set_updated_at before update on public.financial_ledger for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────
-- report_snapshots uniqueness. shg_id is nullable (null = federation
-- rollup), and standard unique constraints treat NULLs as distinct from
-- each other, so this needs two partial unique indexes rather than one
-- constraint — generate-report-snapshots previously worked around the lack
-- of any unique target with a non-atomic delete-then-insert; it's updated
-- in this same change to upsert against these instead.
-- ─────────────────────────────────────────────────────────────────────────

create unique index if not exists report_snapshots_shg_period_uidx
  on public.report_snapshots (shg_id, report_type, period)
  where shg_id is not null;

create unique index if not exists report_snapshots_federation_period_uidx
  on public.report_snapshots (report_type, period)
  where shg_id is null;
