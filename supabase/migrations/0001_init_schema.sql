-- SHG Saathi — initial schema for every module.
-- Apply with the Supabase CLI (`supabase db push`) or paste into the
-- Supabase SQL Editor. This environment cannot reach raw Postgres (5432)
-- directly, so this file is the source of truth instead of a live migration.

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────
-- Core: SHGs, profiles (extends auth.users), documents
-- ─────────────────────────────────────────────────────────────────────────

create table public.shgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  reg_number text,
  formation_date date,
  village text,
  mandal text,
  district text,
  state text,
  bank_name text,
  bank_account text,
  ifsc text,
  grade text,
  clf text,
  vo text,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  mobile text,
  role text not null check (role in ('member', 'leader', 'crp', 'clf', 'admin')) default 'member',
  shg_id uuid references public.shgs (id),
  village text,
  avatar_color text,
  created_at timestamptz not null default now()
);

create table public.shg_documents (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid not null references public.shgs (id) on delete cascade,
  name text not null,
  type text,
  size text,
  storage_path text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Savings & Loans
-- ─────────────────────────────────────────────────────────────────────────

create table public.savings_entries (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid not null references public.shgs (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  entry_date date not null default current_date,
  amount numeric(12, 2) not null check (amount > 0),
  mode text not null check (mode in ('Cash', 'UPI', 'Bank Transfer')),
  frequency text not null check (frequency in ('Weekly', 'Monthly', 'Daily')),
  status text not null check (status in ('verified', 'pending')) default 'pending',
  created_at timestamptz not null default now()
);

create table public.loans (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid not null references public.shgs (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  purpose text not null,
  amount numeric(12, 2) not null check (amount > 0),
  outstanding numeric(12, 2) not null,
  emi numeric(12, 2) not null default 0,
  tenure_months int not null,
  disbursed_on date,
  status text not null check (status in ('pending', 'approved', 'rejected', 'active', 'closed', 'overdue')) default 'pending',
  next_due_date date,
  created_at timestamptz not null default now()
);

create table public.loan_payments (
  id uuid primary key default gen_random_uuid(),
  loan_id uuid not null references public.loans (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  paid_on date not null default current_date,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Meetings
-- ─────────────────────────────────────────────────────────────────────────

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid not null references public.shgs (id) on delete cascade,
  meeting_date date not null,
  meeting_time text,
  venue text,
  agenda text,
  status text not null check (status in ('upcoming', 'completed', 'cancelled')) default 'upcoming',
  created_at timestamptz not null default now()
);

create table public.meeting_attendance (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  present boolean not null default false,
  marked_at timestamptz,
  unique (meeting_id, member_id)
);

create table public.meeting_minutes (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings (id) on delete cascade,
  decisions text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.meeting_action_items (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings (id) on delete cascade,
  task text not null,
  owner_id uuid references public.profiles (id),
  due_date date,
  done boolean not null default false
);

-- ─────────────────────────────────────────────────────────────────────────
-- Financial records (cashbook / ledger / bank reconciliation / audit)
-- ─────────────────────────────────────────────────────────────────────────

create table public.financial_ledger (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid not null references public.shgs (id) on delete cascade,
  entry_type text not null check (entry_type in ('cashbook', 'ledger', 'bank', 'audit')),
  description text not null,
  debit numeric(12, 2) not null default 0,
  credit numeric(12, 2) not null default 0,
  balance numeric(12, 2) not null default 0,
  entry_date date not null default current_date,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Livelihoods
-- ─────────────────────────────────────────────────────────────────────────

create table public.livelihood_activities (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid not null references public.shgs (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  activity_type text not null,
  description text,
  investment numeric(12, 2) default 0,
  revenue numeric(12, 2) default 0,
  status text not null check (status in ('planned', 'active', 'completed')) default 'active',
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Marketplace
-- ─────────────────────────────────────────────────────────────────────────

create table public.marketplace_products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  description text,
  price numeric(12, 2) not null check (price >= 0),
  stock int not null default 0,
  image_url text,
  category text,
  created_at timestamptz not null default now()
);

create table public.marketplace_orders (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.marketplace_products (id) on delete cascade,
  buyer_name text not null,
  amount numeric(12, 2) not null,
  status text not null check (status in ('new', 'packed', 'shipped', 'delivered')) default 'new',
  order_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table public.marketplace_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.marketplace_products (id) on delete cascade,
  reviewer_name text not null,
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Government schemes
-- ─────────────────────────────────────────────────────────────────────────

create table public.schemes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  full_name text,
  agency text,
  benefit text,
  eligibility text[] not null default '{}',
  deadline date,
  created_at timestamptz not null default now()
);

create table public.scheme_applications (
  id uuid primary key default gen_random_uuid(),
  scheme_id uuid not null references public.schemes (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  status text not null check (status in ('not_applied', 'applied', 'under_review', 'approved', 'rejected')) default 'applied',
  applied_on date not null default current_date,
  unique (scheme_id, member_id)
);

-- ─────────────────────────────────────────────────────────────────────────
-- Training
-- ─────────────────────────────────────────────────────────────────────────

create table public.training_courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  topic text not null,
  format text not null check (format in ('Video', 'PDF', 'Audio')),
  duration text,
  created_at timestamptz not null default now()
);

create table public.course_progress (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.training_courses (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  progress int not null default 0 check (progress between 0 and 100),
  certified boolean not null default false,
  completed_on date,
  unique (course_id, member_id)
);

-- ─────────────────────────────────────────────────────────────────────────
-- Digital payments
-- ─────────────────────────────────────────────────────────────────────────

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  mode text not null check (mode in ('UPI', 'QR', 'Card', 'NetBanking')),
  reference text,
  status text not null check (status in ('pending', 'success', 'failed')) default 'pending',
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Announcements
-- ─────────────────────────────────────────────────────────────────────────

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid references public.shgs (id) on delete cascade,
  title text not null,
  body text,
  category text not null check (category in ('Circular', 'Meeting', 'Training', 'Scheme')),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.announcement_reads (
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, member_id)
);

-- ─────────────────────────────────────────────────────────────────────────
-- Support
-- ─────────────────────────────────────────────────────────────────────────

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles (id) on delete cascade,
  subject text not null,
  description text,
  status text not null check (status in ('open', 'in_progress', 'resolved', 'closed')) default 'open',
  created_at timestamptz not null default now()
);

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  sender_id uuid references public.profiles (id),
  body text not null,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- AI advisors (logs only — the advisor call itself is an external LLM API,
-- wired behind an abstraction in the Flutter app and mocked until a
-- production key is supplied)
-- ─────────────────────────────────────────────────────────────────────────

create table public.ai_advisor_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles (id) on delete cascade,
  advisor_type text not null check (advisor_type in ('financial', 'scheme', 'market')),
  query text not null,
  response text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Reports & analytics (materialized snapshots so per-role reports/analytics
-- screens don't need to aggregate raw tables on every load)
-- ─────────────────────────────────────────────────────────────────────────

create table public.report_snapshots (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid references public.shgs (id) on delete cascade,
  report_type text not null check (report_type in ('member', 'shg', 'federation')),
  period text not null,
  data jsonb not null default '{}',
  generated_at timestamptz not null default now()
);

create table public.analytics_kpis (
  id uuid primary key default gen_random_uuid(),
  shg_id uuid references public.shgs (id) on delete cascade,
  metric text not null,
  value numeric(14, 2) not null,
  period text not null,
  recorded_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Admin audit trail
-- ─────────────────────────────────────────────────────────────────────────

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id),
  action text not null,
  entity text not null,
  entity_id uuid,
  meta jsonb not null default '{}',
  created_at timestamptz not null default now()
);
