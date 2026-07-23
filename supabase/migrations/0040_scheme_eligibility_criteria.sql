-- Replaces the Government Schemes eligibility checker's client-side
-- fuzzy-keyword-matching heuristic (SchemeEligibilityPage matching a
-- member's yes/no toggle answers against substrings of `schemes.eligibility`
-- free text) with a real structured rules engine: explicit, typed
-- eligibility criteria the app can evaluate against a member's actual data,
-- instead of guessing from prose.
--
-- Scope is deliberately limited to what this app's own data model actually
-- has. `public.profiles` carries no income, gender, caste/category, age, or
-- occupation field anywhere (checked before writing this migration) — this
-- schema does NOT invent columns for those, since a criterion with no real
-- backing data would just silently always pass or fail. What the app DOES
-- have, on `public.profiles`/`public.shgs`:
--   - profiles.shg_id            -- SHG membership (or lack of one)
--   - shgs.formation_date        -- SHG registration age
--   - shgs.grade                 -- SHG grading (A+/A/B+/B/C — see
--                                   analytics_shg_list_page.dart's own
--                                   grade vocabulary)
-- so the structured criteria below cover exactly those three facts. A
-- scheme's existing free-text `eligibility` list is untouched and still
-- shown on SchemeDetailPage for requirements that genuinely need manual/
-- documentary verification (BPL status, prior-subsidy history, age,
-- gender/caste category, project cost, ...) and are not evaluated by this
-- engine — this is a real rules engine over real stored facts, not a
-- connection to any government eligibility API (no such API exists or is
-- reachable from this project).
--
-- A single JSONB column (rather than three separate nullable columns) keeps
-- this catalog table's shape stable as more structured facts inevitably get
-- added later, and matches the shape `EligibilityCriteria.toMap()` /
-- `EligibilityCriteria.fromMap()` (lib/models/scheme.dart) already read and
-- write. `schemes_write_admin` (0002_rls_policies.sql) is already a
-- `for all using/with check (current_role() = 'admin')` policy with no
-- column-level restriction, so no RLS change is needed for a new column on
-- this table — every write to `schemes` is already fully admin-gated.
--
-- Shape (all keys optional/nullable — every key absent means "no structured
-- requirement, free-text `eligibility` only"):
--   { "requires_shg_membership": boolean,
--     "min_shg_age_months": integer,
--     "min_shg_grade": text }

alter table public.schemes
  add column if not exists eligibility_criteria jsonb not null default '{}'::jsonb;

comment on column public.schemes.eligibility_criteria is
  'Structured eligibility rules evaluated by the client-side rules engine '
  '(EligibilityCriteria in lib/models/scheme.dart): '
  '{requires_shg_membership: bool, min_shg_age_months: int, min_shg_grade: text}. '
  'Supplements, does not replace, the free-text eligibility[] column.';
