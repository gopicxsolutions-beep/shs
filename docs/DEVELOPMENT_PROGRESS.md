# SHG Saathi — Development Progress Log

This file is the durable cross-session record for the "build every module end-to-end
on Supabase" effort. Each work session should read this file first, pick up the next
`pending` module, and update this file before ending.

## Environment constraints (read this first)

This dev environment has **no Flutter SDK installed** (the `flutter` PATH entry is
stale — `C:\flutter` does not exist on disk) and **no live Supabase project**
connected (only `.env.json.example` is present, no real `.env.json`). That means:

- `flutter analyze`, `flutter test`, `flutter pub get`, `flutter run` cannot be
  executed here. All code so far has been verified by careful manual read-through
  against the actual widget/package APIs in this repo, not by compiling.
- No SQL migration has been applied to a real Postgres instance — the RLS policies
  in `0002_rls_policies.sql` are unexecuted against a live database.
- **Before trusting this code in production**: run `flutter pub get && flutter
  analyze` and `supabase db push` (or paste the migrations into the SQL editor) in
  an environment that actually has the toolchain, then fix whatever surfaces.

## Architecture pattern (replicate this for every remaining module)

Established while building the Savings module — copy this shape for Loans,
Meetings, etc.:

1. **`lib/models/<domain>.dart`** — a plain Dart class matching the Supabase table
   shape, with a `fromMap(Map<String, dynamic>)` factory. Joins (e.g. member name)
   are read from the nested map PostgREST returns for embedded selects
   (`select('*, profiles(name)')` → `map['profiles']['name']`).
2. **`lib/repositories/<domain>_repository.dart`** — dual-mode, same pattern as
   `AppState`:
   - `bool get _live => SupabaseService.isConfigured;`
   - Every read method takes the caller-resolved id(s) (shgId/memberId — read from
     `context.watch<AppState>().profile`, not re-fetched inside the repository) and
     branches: `if (!_live || id == null) return _mockXxx();` else real Supabase
     query.
   - Mock fallback methods adapt the existing `lib/data/<domain>.dart` const list
     into the new model type — **do not delete the old `lib/data/*.dart` mocks**,
     they're the offline/demo-mode data source now, imported with `as mock` to
     avoid class-name collisions with the new model.
   - Writes (`insert`/`update`) no-op when `!_live` (demo mode has nothing to
     persist to).
3. **`lib/pages/<domain>/*.dart`** — one file per screen from `lib/routes/paths.dart`.
   Use `AppAsyncBuilder<T>` (`lib/widgets/async_state.dart`) for one-shot loads with
   built-in loading/error+retry states, or a raw `StreamBuilder` for realtime
   screens (see `SavingsLedgerPage` for the pattern — only use realtime where
   collaborative live updates actually matter, not on every screen).
4. **`lib/routes/router.dart`** — replace the `comingSoon(Paths.xxx, 'Title')` line
   for each screen with a real `GoRoute(path: Paths.xxx, builder: ...)`.
5. **Navigation**: this app navigates with `context.go()` everywhere (never
   `push()`), which replaces the Navigator stack rather than pushing onto it. Do
   **not** call `context.pop()` after an action (e.g. post-submit) — it may have
   nothing to pop to. Use `context.go(Paths.xxx)` to a known destination instead.

## RLS design decisions (see `supabase/migrations/0002_rls_policies.sql`)

- Within an SHG, members share **read** access to operational data (savings,
  loans, meetings, ledger) — mirrors real SHG transparency (figures are reviewed
  together at meetings). Writes are scoped to the owning member, the shg's
  `leader`, or staff roles (`crp`/`clf`/`admin`).
- `shgs.bank_account`/`ifsc` are sensitive — the base table is members-only, and
  a `shg_directory` view exposes just the safe columns for onboarding search.
- `marketplace_orders` gained a `buyer_id uuid` column (the original schema only
  had a free-text `buyer_name`, which made per-buyer RLS impossible) — see the
  `alter table ... add column if not exists` near the marketplace section.
- Helper functions `current_role()`, `current_shg_id()`, `is_staff()`,
  `is_leader_or_staff()`, `profile_shg_id(uuid)` are `security definer` to avoid
  RLS recursion when a policy needs to read the caller's own profile row.

## Module status

| Module | Status | Notes |
|---|---|---|
| Foundation (RLS, services, AppState, auth) | ✅ done | `0002_rls_policies.sql`, `lib/services/*`, `lib/state/app_state.dart`, auth pages |
| Onboarding (Login/OTP/Profile Setup/Role Select) | ✅ done | Real phone-OTP via Supabase Auth; profile setup persists to `profiles`; SHG search via `shg_directory` view |
| Savings | ✅ done | Model, repository, 5 screens (home/entry/history/ledger[realtime]/statement/group-report), wired in router |
| Loans | ✅ done | Model, repository, 5 screens (home/apply/approval/tracking/detail with payment recording), wired in router incl. `/app/loans/:id` |
| Meetings | ⬜ not started | Schedule / attendance / QR check-in / MoM / action items |
| My SHG (members/documents) | ⬜ not started | Member list + detail, document list (Supabase Storage for uploads) |
| Financial records (cashbook/ledger/bank/audit) | ⬜ not started | Backed by `financial_ledger` table |
| Livelihoods | ⬜ not started | `livelihood_activities` table |
| Marketplace (products/orders/reviews) | ⬜ not started | Cross-SHG browsing; needs Supabase Storage for product images |
| Government schemes | ⬜ not started | Catalog + `scheme_applications`; eligibility checker can be client-side rule evaluation for now |
| Training | ⬜ not started | `training_courses` + `course_progress`; quiz screen needs a quiz-content model (not in schema yet — add if needed) |
| Digital payments | ⬜ not started | `payments` table; **external payment gateway is out of scope until keys are supplied** — build the full UI/DB flow with a mock "processor" abstraction (see External APIs section below) |
| Announcements | 🟡 partial | List already reads mock data on dashboards; needs its own repository + detail screen + read-receipt tracking via `announcement_reads` |
| Support (chat/voice/FAQ/tickets) | ⬜ not started | `support_tickets` + `support_messages`; voice support needs an external STT/TTS API — abstract behind an interface, mock for now |
| AI Advisors (financial/scheme/market) | ⬜ not started | `ai_advisor_logs` table exists. **External LLM API is out of scope until keys are supplied** — build a `AiAdvisorService` interface with a canned/mock implementation now, swap in a real provider later |
| Reports | ⬜ not started | `report_snapshots`; snapshots are meant to be generated server-side (Edge Function) — for now, repository can compute on-the-fly client-side from live tables as a placeholder |
| Analytics | ⬜ not started | `analytics_kpis`; CRP/CLF/Admin dashboards already show a version of this from mock data — needs a real repository |
| Admin (users/schemes/monitoring) | ⬜ not started | User role management (admin can update any profile's role per RLS), scheme catalog CRUD, system monitoring (likely needs an Edge Function for real infra metrics — mock for now) |
| Automated tests | ⬜ not started | No `test/` directory exists yet. Add widget tests for the async/repository pattern once 2-3 more modules land, so the test harness matches a stable pattern rather than being rewritten each time |
| Edge Functions | ⬜ not started | None created yet. Candidates once modules are live: report snapshot generation, AI advisor proxy (keeps the LLM key server-side), payment webhook handler |

## External API abstraction plan

Per the requirement to build full architecture now and swap in real providers
later: every module that needs a third-party API (AI advisors, SMS beyond
Supabase's own OTP provider config, payment gateway, voice STT/TTS) should get a
small interface in `lib/services/` with:
- One method per capability (e.g. `Future<String> ask(String prompt)`).
- A `Mock*` implementation returning canned/plausible responses, used until real
  credentials exist.
- The repository/UI layer depends on the interface, not the mock, so swapping in
  a real implementation later is a one-file change.

None of these exist yet — build them alongside their module (e.g. `AiAdvisorService`
when building the AI Advisors module), not speculatively ahead of time.

## Live Supabase project

A real project now exists: `pccbwfmlhpvieetetrpx` (URL in the gitignored
`.env.json`, which is populated with the URL + anon key only). **Migrations are
NOT yet applied to it.** Two blockers found while trying:

1. This sandbox can only reach the internet over HTTPS (443) — confirmed by
   direct TCP tests. Both direct Postgres (`5432`) and the connection pooler
   (`6543`) are unreachable, so `supabase db push` cannot run from here (it
   needs a real Postgres wire-protocol connection). This matches the warning
   already at the top of `0001_init_schema.sql`.
2. The Supabase CLI on this machine is logged into a different account (one
   that owns an unrelated "humanproof" project) than the account that owns
   `pccbwfmlhpvieetetrpx`, so `supabase link` also fails on privileges even
   before the network issue would matter.

**Next session should either**: (a) check if the user ran `supabase db push`
themselves and the schema is now live — if so, everything in this repo should
work against it as-is — or (b) if they provided a Supabase **personal access
token** (Management API token, not anon/service key), use it to push the SQL
via `POST https://api.supabase.com/v1/projects/{ref}/database/query` over
HTTPS instead of a direct DB connection. Never write the DB password or
service-role key into any repo file — both were shared in chat and should be
treated as sensitive (recommend the user rotate the DB password).

## Session log

- **2026-07-17**: Built the foundation (RLS policies for all 27 tables, Supabase
  service/repository layer, real phone-OTP auth wired into onboarding, session-
  aware `AppState`/router redirect logic) and the full Savings module (5 screens +
  realtime ledger). Established the model/repository/page pattern documented above.
- **2026-07-17 (cont'd)**: Built the full Loans module (5 screens: home, apply,
  approval with EMI-entry dialog, tracking, detail with payment recording).
  Started installing the Flutter SDK locally (was missing — stale PATH entry).
  Got real Supabase project credentials from the user; wired `.env.json`
  (client-safe values only); migration push blocked on network/account issues
  documented above. Next: Meetings module, and resolve the migration push.
