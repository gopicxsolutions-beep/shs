-- ICSSR baseline survey ("A Longitudinal Study of Women-Led Microenterprises
-- and Social Transformation in Andhra Pradesh through Digital Empowerment").
-- Adds the full 9-section paper survey (demographics, enterprise profile,
-- digital access, financial inclusion, entrepreneurial skills, empowerment,
-- challenges & needs, government/NGO expectations, consent) as a structured
-- table filled once at registration time, alongside the existing
-- name/village/mandal/district/SHG fields on `profiles`
-- (lib/pages/auth/profile_setup_page.dart).
--
-- One row per profile (profile_id is itself the primary key, not a separate
-- surrogate id) — a member fills this exactly once, at signup, before ever
-- reaching the dashboard (see AppState.hasCompletedBaselineSurvey / the
-- router redirect in lib/routes/router.dart).
--
-- This is materially more sensitive than the app's usual SHG-transparency
-- data (savings/loans/meetings, which members of the same SHG can see one
-- another's — see CLAUDE.md's security model). Household income, caste,
-- and empowerment self-assessments are not the kind of thing shared with
-- fellow members even in the in-person paper-survey process, so unlike
-- those tables this one is NOT readable via is_leader_or_staff() — only the
-- owner herself and federation staff (crp/clf/admin, via is_staff()), the
-- latter needed because this data only has value in aggregate for the
-- federation-level research reporting the survey exists for in the first
-- place (mirrors the read boundary already used for financial_ledger).
create table public.member_baseline_surveys (
  profile_id uuid primary key references public.profiles(id) on delete cascade,

  -- Section A: Demographics
  age integer check (age is null or age between 10 and 120),
  education_level text check (education_level is null or education_level in ('none', 'primary', 'secondary', 'graduate', 'postgraduate')),
  caste_community text,
  marital_status text check (marital_status is null or marital_status in ('single', 'married', 'widowed', 'separated_divorced')),
  household_size integer check (household_size is null or household_size between 1 and 50),
  survey_location text check (survey_location is null or survey_location in ('east_godavari', 'west_godavari', 'krishna', 'other')),
  survey_location_other text,
  annual_household_income numeric(12, 2) check (annual_household_income is null or annual_household_income >= 0),
  primary_income_source text,

  -- Section B: Enterprise Profile
  enterprise_type text check (enterprise_type is null or enterprise_type in ('shg_led', 'individual', 'collective')),
  enterprise_sector text check (enterprise_sector is null or enterprise_sector in ('agri_food_processing', 'tailoring_textiles', 'retail', 'services', 'others')),
  enterprise_sector_other text,
  years_in_operation numeric(5, 1) check (years_in_operation is null or years_in_operation >= 0),
  monthly_revenue numeric(12, 2) check (monthly_revenue is null or monthly_revenue >= 0),
  employees_count integer check (employees_count is null or employees_count >= 0),
  registration_status text check (registration_status is null or registration_status in ('registered', 'unregistered')),
  market_reach text check (market_reach is null or market_reach in ('local', 'district', 'state', 'national', 'international')),

  -- Section C: Digital Access & Usage
  owns_smartphone boolean,
  internet_access text check (internet_access is null or internet_access in ('regular', 'occasional', 'never')),
  internet_type text check (internet_type is null or internet_type in ('mobile_data', 'wifi', 'other')),
  internet_type_other text,
  apps_used text[] not null default '{}',
  received_digital_training boolean,
  digital_payment_frequency text check (digital_payment_frequency is null or digital_payment_frequency in ('daily', 'weekly', 'occasionally', 'never')),
  digital_tools_comfort text check (digital_tools_comfort is null or digital_tools_comfort in ('high', 'moderate', 'low')),

  -- Section D: Financial Inclusion
  has_bank_account boolean,
  credit_access text check (credit_access is null or credit_access in ('formal', 'informal', 'none')),
  digital_payment_usage text check (digital_payment_usage is null or digital_payment_usage in ('often', 'sometimes', 'never')),
  savings_pattern text check (savings_pattern is null or savings_pattern in ('regular', 'irregular', 'none')),
  aware_govt_schemes boolean,
  govt_schemes_detail text,

  -- Section E: Entrepreneurial Skills
  business_planning_knowledge text check (business_planning_knowledge is null or business_planning_knowledge in ('high', 'moderate', 'low')),
  record_keeping text check (record_keeping is null or record_keeping in ('manual', 'digital', 'none')),
  has_inventory_system boolean,
  participated_business_training boolean,
  online_marketing_ability text check (online_marketing_ability is null or online_marketing_ability in ('high', 'moderate', 'low')),
  innovation_level text check (innovation_level is null or innovation_level in ('high', 'moderate', 'low')),

  -- Section F: Empowerment & Agency
  household_decision_role text check (household_decision_role is null or household_decision_role in ('high', 'moderate', 'low')),
  mobility text check (mobility is null or mobility in ('always', 'sometimes', 'never')),
  shg_leadership_role boolean,
  tech_confidence text check (tech_confidence is null or tech_confidence in ('high', 'moderate', 'low')),
  community_influence text check (community_influence is null or community_influence in ('high', 'moderate', 'low')),
  negotiation_ability text check (negotiation_ability is null or negotiation_ability in ('high', 'moderate', 'low')),

  -- Section G: Challenges & Needs
  top_challenges text[] not null default '{}' check (array_length(top_challenges, 1) is null or array_length(top_challenges, 1) <= 3),
  training_needs text[] not null default '{}',
  training_needs_other text,
  support_needed text[] not null default '{}',
  interested_in_training_trials boolean,
  expected_project_benefit text,

  -- Section H: Expectations from Government/NGOs
  govt_ngo_support_needed text[] not null default '{}',
  govt_ngo_support_other text,

  -- Section I: Consent & Confidentiality. `consent_given` must be true for
  -- the row to exist at all (see the table-level check below) — there is no
  -- "saved but not consented" state, matching the paper form where an
  -- unsigned survey was never actually returned.
  consent_given boolean not null default false,
  signature_name text not null check (char_length(trim(signature_name)) > 0),
  submitted_at timestamptz not null default now(),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint member_baseline_surveys_consent_required check (consent_given = true)
);

alter table public.member_baseline_surveys enable row level security;

create policy "member_baseline_surveys_select_own_or_staff" on public.member_baseline_surveys
  for select using (profile_id = auth.uid() or public.is_staff());

create policy "member_baseline_surveys_insert_own" on public.member_baseline_surveys
  for insert with check (profile_id = auth.uid());

-- No self-escalation surface here (unlike profiles.role) — every column is
-- either a survey answer or the fixed consent/signature pair, so a plain
-- owner-only USING/WITH CHECK is sufficient; nothing on this row grants any
-- privilege elsewhere.
create policy "member_baseline_surveys_update_own" on public.member_baseline_surveys
  for update using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- No delete policy: staff can view for research reporting but the survey
-- response itself — like the paper form it replaces — is retained, not
-- something either the respondent or staff can erase from the client.

drop trigger if exists member_baseline_surveys_set_updated_at on public.member_baseline_surveys;
create trigger member_baseline_surveys_set_updated_at before update on public.member_baseline_surveys for each row execute function public.set_updated_at();

revoke all on public.member_baseline_surveys from public, anon;
grant select, insert, update on public.member_baseline_surveys to authenticated;
