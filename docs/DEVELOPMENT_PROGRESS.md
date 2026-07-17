# SHG Saathi — Development Progress Log

This file is the durable cross-session record for the "build every module end-to-end
on Supabase" effort. Each work session should read this file first, pick up the next
`pending` module, and update this file before ending.

## Environment status

**Resolved**: Flutter SDK 3.44.6 is now installed at `C:\flutter` (was missing —
stale PATH entry — fixed by downloading via `curl.exe`, NOT `Invoke-WebRequest`,
which throttles large downloads to ~0.24 MB/s due to progress-bar rendering
overhead in Windows PowerShell 5.1). `flutter pub get` and `flutter analyze` both
run cleanly now — 0 errors/warnings on the foundation + Savings + Loans modules
(a handful of trivial info-level lints fixed: unused import, missing `mounted`
check after an async gap, double-underscore lambda params).

**Resolved**: A live Supabase project (`pccbwfmlhpvieetetrpx`) is connected —
see the "Live Supabase project" section below.

**Resolved — browser automation of Flutter web DOES work, with the right technique**:
the `flutter-web` dev server (`.claude/launch.json`) runs correctly and Supabase
initializes against the live project. Typing into Flutter web `TextField`s
(CanvasKit renderer) initially seemed impossible — `type`/`key` with coordinate
clicks and manual DOM `InputEvent` dispatch on the hidden native `<input>` both
failed silently. The actual fix, in order:
1. Activate Flutter's accessibility semantics tree once per page load: find
   and click `flt-semantics-placeholder` (a ~1px element near viewport origin) —
   `document.querySelector('flt-semantics-placeholder').click()` via
   `javascript_tool`. Without this, Flutter doesn't create proper focusable
   proxy elements at all.
2. Click the field by **coordinate**, not by accessibility `ref` (ref-based
   clicks didn't reliably trigger Flutter's focus handling in testing, even
   with semantics on).
3. **Verify real focus** before typing — check
   `document.activeElement.tagName` is `INPUT` via `javascript_tool`. If it's
   not, the click didn't land on Flutter's real hidden input and nothing
   typed afterward will register.
4. Type using the `computer` tool's `key` action with **individual real
   keystrokes** (e.g. `key text:"9"` then `key text:"8"`, or one call with
   space-separated sequential keys like `"7 6 5 4"` — these are sequential
   presses, not a combo). The `type` action and any JS-based `.value` /
   `InputEvent` injection do NOT sync into Flutter's internal editing state —
   only genuine dispatched keyboard events do.
Verified end-to-end this way: typed a full phone number into Login, tapped
Send OTP, and watched the **real** `signInWithOtp` call fail against the live
project (no SMS provider configured — expected) with the app's error-handling
UI correctly catching it and showing "Could not send OTP. Please check the
number and try again." Also verified live: navigating directly to a protected
route (`#/app/dashboard`) with no session correctly redirects to Splash (the
router's auth guard, `lib/routes/router.dart`, working against real state).
For deeper coverage Flutter's own `integration_test` package is still the more
robust long-term answer, but the above unblocks real interactive UI testing
in the meantime — use it for the golden-path flows of new modules, not just
the DB-level RLS testing.

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
| Meetings | ✅ done | Model, repository, 6 screens (home/schedule/attendance roster/self check-in/detail/MoM with decisions+action items), wired incl. `/app/meetings/:id` and `/app/meetings/:id/mom`. QR check-in is real attendance-marking logic behind a tap, not a camera scanner (no camera plugin in pubspec yet) |
| My SHG (members/documents) | ✅ done | Model, repository, 4 screens (shg home/members list/member detail/documents), wired incl. `/app/shg/members/:id`. Document upload is metadata-only — actual file upload needs a Supabase Storage bucket + file-picker plugin (neither wired yet) |
| Financial records (cashbook/ledger/bank/audit) | ✅ done | One shared `FinancialLedgerPage(entryType, title)` screen reused across all 4 routes (they're identical shape, just filtered by `entry_type`) + add-entry dialog with running-balance calc. Live-tested: leader-only write denied for member, shared read works |
| Livelihoods | ✅ done | Model, repository, 3 screens (home/entry/detail with Update Progress dialog). Live-tested DB/RLS + full UI golden path (see session log) — found and fixed a real Role-Select-skip bug in the process |
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

A real project exists: `pccbwfmlhpvieetetrpx` (URL + anon key in the gitignored
`.env.json`). **Migrations are applied and live** — verified: 27 base tables +
`shg_directory` view, 67 RLS policies, 6 helper functions.

Direct Postgres (`5432`) and the pooler (`6543`) are both unreachable from this
sandbox (HTTPS/443-only egress), so `supabase db push`/`supabase link` don't
work here. What did work: the Supabase **Management API**'s SQL endpoint —
`POST https://api.supabase.com/v1/projects/{ref}/database/query` with
`Authorization: Bearer <personal-access-token>` and body `{"query": "<sql>"}` —
which goes over plain HTTPS. The user supplied a personal access token
(different from the anon/service-role keys) for this.

**Gotcha for next time**: Windows PowerShell 5.1's `ConvertTo-Json` pathologically
bloats large strings when serializing a hashtable literal (a 17.7KB SQL file
became a 3.8MB "body", tripping the endpoint's 413 limit) — it appears to
serialize the String object's properties rather than just its value. Build the
JSON body by hand (escape `"`, `\`, and control chars, wrap in `{"query":"..."}"`)
instead of trusting `ConvertTo-Json` for large payloads. Both migration files
went through fine once built manually (18KB and 27.7KB bodies).

The DB password and service-role key the user shared were never written to any
repo file — only the URL + anon key went into `.env.json`. Both remain
sensitive since they were shared in plaintext chat; recommend rotating the DB
password.

## Live testing methodology (do this for every module, per user request)

Since browser automation can't drive Flutter web's text fields (see above),
real end-to-end verification happens **directly against the live database**
via the Management API's SQL endpoint, simulating each role's RLS context.
This actually exercises the real schema + real RLS policies, not just code
review. User has explicitly authorized creating temporary test fixtures for
this, on the condition they're always cleaned up afterward.

**Pattern** (PowerShell, using the `Invoke-Sql`/`Invoke-SqlAs` helpers built
during this session — recreate them each time, they aren't saved to a file):

1. Create fixtures once per test session: a `__TEST__`-prefixed SHG
   (`11111111-1111-1111-1111-111111111111`) + a member + a leader profile,
   with matching `auth.users` rows (needed because `profiles.id` FKs to
   `auth.users.id`). Use fixed, recognizable UUIDs so cleanup is trivial.
2. Simulate a specific user's RLS context within one SQL request via:
   `set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';`
   then the real query — `auth.uid()` reads this session-local claim, so
   every RLS policy evaluates exactly as it would for that real user.
3. **Always check actual affected/visible row counts, not HTTP success/failure.**
   An `UPDATE`/`DELETE` blocked by a `USING`-only policy (no `WITH CHECK`)
   doesn't error — it silently matches 0 rows and returns HTTP success. Wrap
   mutations as `with r as (<stmt> returning 1) select count(*) from r` and
   assert on the count. (First pass at this got a false "FAIL" by checking
   HTTP status instead — cost real time to debug. Don't repeat that.)
4. Test the real boundaries a module's RLS is supposed to enforce: the
   owning-member-can-write-their-own-row case, the wrong-role-denied case,
   the shared-shg-read case, and cross-tenant isolation (a user from a
   different SHG can't see this one's rows).
5. **Clean up every fixture row afterward** (`delete from ... where shg_id =
   '11111111-...'` across every table touched, plus the `auth.users` rows) —
   verify zero rows remain. Never leave synthetic data in the live project.

Verified this way already: Savings (own-entry insert, deny-insert-for-others,
leader-only verify, shared read), Loans (self-apply, deny-self-approve,
leader-approve), Meetings (leader-only schedule, shared read), My SHG
(shared roster read, cross-tenant SHG isolation). All passed — no real RLS
gaps found, only test-harness bugs of my own making (documented in point 3).

This DB-level testing proves the schema/RLS layer end-to-end. **Also test the
live UI** for each module's golden path in the Browser pane against the
`flutter-web` dev server, using the real-typing technique documented in
"Environment status" above (activate semantics, click by coordinate, verify
`document.activeElement`, type via real sequential `key` presses) — don't
settle for DB-only testing when the UI layer can genuinely be exercised too.
For deeper/regression-proof coverage, Flutter's own `integration_test`
package is still the more robust long-term answer.

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
- **2026-07-17 (cont'd)**: Flutter SDK finished installing (fixed the slow
  download — see environment status above). Got a Supabase personal access
  token from the user and pushed both migrations live via the Management API.
  Ran `flutter analyze` for the first time — 0 errors on the foundation +
  Savings + Loans modules (fixed a handful of trivial lints). Started the
  `flutter-web` dev server and verified it live in the Browser pane: renders
  correctly, Supabase initializes against the real project, real button
  navigation works; documented the browser-automation-vs-Flutter-web-text-input
  limitation above. Built the full Meetings module (6 screens) — `flutter
  analyze` caught one real bug during development (passed a non-existent
  `decoration` param to `AppTheme.sans()`, fixed by using `.copyWith()`
  instead), confirming the analyze-every-module habit is worth keeping.
  Next: My SHG (members/documents) or Financial Records module.
- **2026-07-17 (cont'd)**: Built the full My SHG module (4 screens: shg home
  with federation/bank details, members list, member detail combining
  profile + aggregated savings/loan totals via composition of
  SavingsRepository/LoanRepository, documents list). `flutter analyze` caught
  3 unused-import warnings (no real bugs this round), fixed. Next: Financial
  Records module.
- **2026-07-17 (cont'd)**: Established the live-testing methodology documented
  above (user explicitly asked for live E2E, not just static analysis). First
  attempt to create test fixtures was correctly blocked by the safety
  classifier (writing to `auth.users`/`profiles`/`shgs` needed explicit user
  sign-off); asked, user approved. Live-tested Savings, Loans, Meetings, and
  My SHG against the real database — all RLS boundaries verified correct,
  except two false alarms caused by my own test-harness bugs (documented
  above so they aren't repeated). Built the full Financial Records module
  (one shared screen reused across cashbook/ledger/bank/audit via an
  `entryType` param instead of 4 near-duplicate files) and live-tested it
  the same way — leader-only write correctly denied for members, shared
  read works. All test fixtures cleaned up after each round (verified zero
  remnants). Next: Livelihoods module.
- **2026-07-17 (cont'd)**: User asked to also test the live preview (not just
  DB-level). Cracked the Flutter-web browser-automation problem — full UI
  testing (typing included) does work, documented in detail above (activate
  semantics, coordinate click, verify real focus, real sequential keystrokes).
  Verified live: typed a full phone number on Login, tapped Send OTP, watched
  the real Supabase call fail gracefully (no SMS provider configured — expected)
  with correct error UI; verified the router's auth guard live by navigating
  directly to a protected route while unauthenticated and confirming redirect
  to Splash. This supersedes the earlier "browser automation doesn't work"
  conclusion — use real UI testing for golden paths going forward, alongside
  the DB-level RLS testing. Next: Livelihoods module, with both testing modes
  applied.
- **2026-07-17 (cont'd)**: Built the full Livelihoods module (3 screens) and
  live-tested it both ways. DB/RLS: member adds own activity, updates own
  revenue, leader can update a member's activity, cross-tenant isolation
  holds — all correct. **UI testing found a real bug**: added a second
  `flutter-web-demo` launch config (port 5001, no `--dart-define`, so
  `SupabaseService.isConfigured=false`) to reach authenticated screens
  without needing real SMS OTP. Walked the full onboarding flow (typing
  included) and found that completing Profile Setup skipped Role Select
  entirely, landing straight on the dashboard. Root cause:
  `hasSession`/`hasProfile` both read the same single `_legacyOnboarded`
  flag in demo mode, so completing profile setup satisfied both
  simultaneously and the router's "fully onboarded, leave the auth flow"
  redirect fired before Role Select could render. Fixed in
  `lib/state/app_state.dart` by splitting into two independent flags
  (`_legacySessionStarted` set after profile setup →  `hasSession`;
  `_legacyOnboarded` set after role select → `hasProfile`), mirroring how
  the two flags are already genuinely independent in the real-Supabase
  path. Verified the fix live: full flow now correctly stops at Role
  Select, and picking a role lands on the dashboard as expected. Also
  live-tested the Livelihoods list/entry/detail screens this way — all
  render and behave correctly (chip selection, typing, profit/loss
  coloring, demo-mode write no-ops). Minor unrelated finding: bottom nav
  overflows by 2px on an 812px-tall viewport (`lib/layout/app_shell.dart`)
  — cosmetic, not yet fixed, low priority. Next: Marketplace module.
