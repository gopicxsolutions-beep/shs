-- SHG Saathi — Row Level Security for every table in 0001_init_schema.sql.
--
-- Design:
--   * Every table gets RLS enabled with `force row level security` off (owner/service-role
--     bypasses RLS by default in Postgres, which is what Edge Functions / admin tooling need).
--   * Three SECURITY DEFINER helper functions read the caller's own profile without
--     recursively triggering RLS on `profiles` itself.
--   * Within an SHG, members share read access to operational data (savings, loans,
--     meetings, ledger) — this mirrors how SHGs actually operate: figures are reviewed
--     together at meetings, so hiding a fellow member's savings entry from the rest of
--     the group would work against the product's transparency model. Writes are scoped
--     to the owning member, the shg's leader, or staff roles (crp/clf/admin).
--   * `shgs.bank_account` / `shgs.ifsc` are sensitive, so the base table is restricted to
--     the shg's own members + staff; a separate `shg_directory` view exposes only the
--     non-sensitive columns needed for onboarding search (profile setup's "pick your SHG").
--
-- Apply after 0001_init_schema.sql, same way (Supabase CLI `db push` or SQL editor).

-- ─────────────────────────────────────────────────────────────────────────
-- Helper functions (security definer — bypass RLS to avoid recursive checks)
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.current_role()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_shg_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select shg_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_staff()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select role in ('crp', 'clf', 'admin') from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.is_leader_or_staff()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select role in ('leader', 'crp', 'clf', 'admin') from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.profile_shg_id(p_member_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select shg_id from public.profiles where id = p_member_id;
$$;

grant execute on function public.current_role() to authenticated;
grant execute on function public.current_shg_id() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_leader_or_staff() to authenticated;
grant execute on function public.profile_shg_id(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- shgs — base table locked to own members + staff; safe directory view for
-- onboarding search (profile setup screen searches SHGs before joining one).
-- ─────────────────────────────────────────────────────────────────────────

alter table public.shgs enable row level security;

create policy "shgs_select_own_or_staff" on public.shgs
  for select using (id = public.current_shg_id() or public.is_staff());

create policy "shgs_update_leader_or_staff" on public.shgs
  for update using (
    (id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "shgs_insert_staff" on public.shgs
  for insert with check (public.is_staff());

create policy "shgs_delete_admin" on public.shgs
  for delete using (public.current_role() = 'admin');

create or replace view public.shg_directory
with (security_invoker = false) as
  select id, name, village, mandal, district, grade
  from public.shgs;

grant select on public.shg_directory to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;

create policy "profiles_select_self_shg_or_staff" on public.profiles
  for select using (
    id = auth.uid() or shg_id = public.current_shg_id() or public.is_staff()
  );

create policy "profiles_insert_self" on public.profiles
  for insert with check (id = auth.uid());

create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin');

create policy "profiles_delete_admin" on public.profiles
  for delete using (public.current_role() = 'admin');

-- ─────────────────────────────────────────────────────────────────────────
-- shg_documents
-- ─────────────────────────────────────────────────────────────────────────

alter table public.shg_documents enable row level security;

create policy "shg_documents_select_shg_or_staff" on public.shg_documents
  for select using (shg_id = public.current_shg_id() or public.is_staff());

create policy "shg_documents_write_leader_or_staff" on public.shg_documents
  for all using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Savings & loans
-- ─────────────────────────────────────────────────────────────────────────

alter table public.savings_entries enable row level security;

create policy "savings_select_shg_or_staff" on public.savings_entries
  for select using (
    member_id = auth.uid() or shg_id = public.current_shg_id() or public.is_staff()
  );

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  );

create policy "savings_update_leader_or_staff" on public.savings_entries
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "savings_delete_leader_or_staff" on public.savings_entries
  for delete using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

alter table public.loans enable row level security;

create policy "loans_select_shg_or_staff" on public.loans
  for select using (
    member_id = auth.uid() or shg_id = public.current_shg_id() or public.is_staff()
  );

create policy "loans_insert_self" on public.loans
  for insert with check (member_id = auth.uid() and shg_id = public.current_shg_id());

create policy "loans_update_leader_or_staff" on public.loans
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "loans_delete_staff" on public.loans
  for delete using (public.is_staff());

alter table public.loan_payments enable row level security;

create policy "loan_payments_select_related" on public.loan_payments
  for select using (
    exists (
      select 1 from public.loans l
      where l.id = loan_payments.loan_id
        and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id())
    ) or public.is_staff()
  );

create policy "loan_payments_insert_related" on public.loan_payments
  for insert with check (
    exists (
      select 1 from public.loans l
      where l.id = loan_payments.loan_id
        and (
          l.member_id = auth.uid()
          or (l.shg_id = public.current_shg_id() and public.current_role() = 'leader')
        )
    ) or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Meetings
-- ─────────────────────────────────────────────────────────────────────────

alter table public.meetings enable row level security;

create policy "meetings_select_shg_or_staff" on public.meetings
  for select using (shg_id = public.current_shg_id() or public.is_staff());

create policy "meetings_write_leader_or_staff" on public.meetings
  for all using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

alter table public.meeting_attendance enable row level security;

create policy "meeting_attendance_select_related" on public.meeting_attendance
  for select using (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id and m.shg_id = public.current_shg_id()
    ) or public.is_staff()
  );

create policy "meeting_attendance_self_or_leader" on public.meeting_attendance
  for all using (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  );

alter table public.meeting_minutes enable row level security;

create policy "meeting_minutes_select_related" on public.meeting_minutes
  for select using (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_minutes.meeting_id and m.shg_id = public.current_shg_id()
    ) or public.is_staff()
  );

create policy "meeting_minutes_write_leader_or_staff" on public.meeting_minutes
  for all using (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_minutes.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    ) or public.is_staff()
  ) with check (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_minutes.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    ) or public.is_staff()
  );

alter table public.meeting_action_items enable row level security;

create policy "meeting_action_items_select_related" on public.meeting_action_items
  for select using (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id and m.shg_id = public.current_shg_id()
    ) or public.is_staff()
  );

create policy "meeting_action_items_write_related" on public.meeting_action_items
  for all using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Financial ledger
-- ─────────────────────────────────────────────────────────────────────────

alter table public.financial_ledger enable row level security;

create policy "financial_ledger_select_shg_or_staff" on public.financial_ledger
  for select using (shg_id = public.current_shg_id() or public.is_staff());

create policy "financial_ledger_write_leader_or_staff" on public.financial_ledger
  for all using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Livelihoods
-- ─────────────────────────────────────────────────────────────────────────

alter table public.livelihood_activities enable row level security;

create policy "livelihood_select_shg_or_staff" on public.livelihood_activities
  for select using (
    member_id = auth.uid() or shg_id = public.current_shg_id() or public.is_staff()
  );

create policy "livelihood_write_self_leader_or_staff" on public.livelihood_activities
  for all using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  ) with check (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Marketplace — cross-SHG, so browsing is open to any authenticated member.
-- `marketplace_orders.buyer_id` is added here (the original schema only had
-- a free-text buyer_name, which made per-buyer RLS impossible).
-- ─────────────────────────────────────────────────────────────────────────

alter table public.marketplace_orders add column if not exists buyer_id uuid references public.profiles (id);

alter table public.marketplace_products enable row level security;

create policy "marketplace_products_select_all" on public.marketplace_products
  for select using (auth.role() = 'authenticated');

create policy "marketplace_products_write_seller_or_staff" on public.marketplace_products
  for all using (seller_id = auth.uid() or public.is_staff())
  with check (seller_id = auth.uid() or public.is_staff());

alter table public.marketplace_orders enable row level security;

create policy "marketplace_orders_select_related" on public.marketplace_orders
  for select using (
    buyer_id = auth.uid()
    or exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
    or public.is_staff()
  );

create policy "marketplace_orders_insert_authenticated" on public.marketplace_orders
  for insert with check (auth.role() = 'authenticated');

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
    or public.is_staff()
  );

alter table public.marketplace_reviews enable row level security;

create policy "marketplace_reviews_select_all" on public.marketplace_reviews
  for select using (auth.role() = 'authenticated');

create policy "marketplace_reviews_insert_authenticated" on public.marketplace_reviews
  for insert with check (auth.role() = 'authenticated');

create policy "marketplace_reviews_moderate_staff" on public.marketplace_reviews
  for update using (public.is_staff());

create policy "marketplace_reviews_delete_staff" on public.marketplace_reviews
  for delete using (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Government schemes
-- ─────────────────────────────────────────────────────────────────────────

alter table public.schemes enable row level security;

create policy "schemes_select_all" on public.schemes
  for select using (auth.role() = 'authenticated');

create policy "schemes_write_admin" on public.schemes
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

alter table public.scheme_applications enable row level security;

create policy "scheme_applications_select_related" on public.scheme_applications
  for select using (
    member_id = auth.uid()
    or public.profile_shg_id(member_id) = public.current_shg_id()
    or public.is_staff()
  );

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (member_id = auth.uid());

create policy "scheme_applications_update_self_or_staff" on public.scheme_applications
  for update using (member_id = auth.uid() or public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Training
-- ─────────────────────────────────────────────────────────────────────────

alter table public.training_courses enable row level security;

create policy "training_courses_select_all" on public.training_courses
  for select using (auth.role() = 'authenticated');

create policy "training_courses_write_staff" on public.training_courses
  for all using (public.is_staff()) with check (public.is_staff());

alter table public.course_progress enable row level security;

create policy "course_progress_select_related" on public.course_progress
  for select using (
    member_id = auth.uid()
    or public.profile_shg_id(member_id) = public.current_shg_id()
    or public.is_staff()
  );

create policy "course_progress_write_self_or_staff" on public.course_progress
  for all using (member_id = auth.uid() or public.is_staff())
  with check (member_id = auth.uid() or public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Digital payments
-- ─────────────────────────────────────────────────────────────────────────

alter table public.payments enable row level security;

create policy "payments_all_self_or_staff" on public.payments
  for all using (member_id = auth.uid() or public.is_staff())
  with check (member_id = auth.uid() or public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Announcements
-- ─────────────────────────────────────────────────────────────────────────

alter table public.announcements enable row level security;

create policy "announcements_select_scope_or_staff" on public.announcements
  for select using (
    shg_id is null or shg_id = public.current_shg_id() or public.is_staff()
  );

create policy "announcements_write_leader_or_staff" on public.announcements
  for all using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

alter table public.announcement_reads enable row level security;

create policy "announcement_reads_self_or_staff" on public.announcement_reads
  for all using (member_id = auth.uid() or public.is_staff())
  with check (member_id = auth.uid() or public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Support
-- ─────────────────────────────────────────────────────────────────────────

alter table public.support_tickets enable row level security;

create policy "support_tickets_select_self_or_staff" on public.support_tickets
  for select using (member_id = auth.uid() or public.is_staff());

create policy "support_tickets_insert_self" on public.support_tickets
  for insert with check (member_id = auth.uid());

create policy "support_tickets_update_self_or_staff" on public.support_tickets
  for update using (member_id = auth.uid() or public.is_staff());

alter table public.support_messages enable row level security;

create policy "support_messages_select_related" on public.support_messages
  for select using (
    exists (
      select 1 from public.support_tickets t
      where t.id = support_messages.ticket_id and (t.member_id = auth.uid() or public.is_staff())
    )
  );

create policy "support_messages_insert_related" on public.support_messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.support_tickets t
      where t.id = support_messages.ticket_id and (t.member_id = auth.uid() or public.is_staff())
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- AI advisor logs
-- ─────────────────────────────────────────────────────────────────────────

alter table public.ai_advisor_logs enable row level security;

create policy "ai_advisor_logs_select_self_or_staff" on public.ai_advisor_logs
  for select using (member_id = auth.uid() or public.is_staff());

create policy "ai_advisor_logs_insert_self" on public.ai_advisor_logs
  for insert with check (member_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- Reports & analytics — generated server-side (Edge Function / admin), so
-- only staff can write; shg-scoped members can read their own snapshots.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.report_snapshots enable row level security;

create policy "report_snapshots_select_shg_or_staff" on public.report_snapshots
  for select using (shg_id = public.current_shg_id() or public.is_staff());

create policy "report_snapshots_write_staff" on public.report_snapshots
  for all using (public.is_staff()) with check (public.is_staff());

alter table public.analytics_kpis enable row level security;

create policy "analytics_kpis_select_shg_or_staff" on public.analytics_kpis
  for select using (
    (shg_id is null and public.is_staff()) or shg_id = public.current_shg_id() or public.is_staff()
  );

create policy "analytics_kpis_write_staff" on public.analytics_kpis
  for all using (public.is_staff()) with check (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Admin audit trail — write-once from the app (actor writes their own
-- action), full read restricted to admins. No update/delete policies are
-- defined, so the log is immutable from the client once RLS is enabled.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.audit_log enable row level security;

create policy "audit_log_select_admin" on public.audit_log
  for select using (public.current_role() = 'admin');

create policy "audit_log_insert_self" on public.audit_log
  for insert with check (actor_id = auth.uid());
