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
5. **To jump directly to a deep route once the app has already booted, set
   `location.hash` via `javascript_tool` — do NOT call `navigate()` with a
   `#/...` URL.** `navigate()` triggers a full browser page reload (confirmed
   via DOM inspection: `document.body` reverts to the raw un-hydrated
   `index.html`, no `<canvas>`/`flt-glass-pane`), forcing a full Flutter web
   cold boot (~20-30s) that looks identical to a permanently blank page if
   you don't wait long enough — cost real time misdiagnosing this as a bug
   before finding the cause. `location.hash = '#/app/whatever'` changes the
   route within the already-running SPA instantly, no reboot.
6. **Never call `navigate()` on a tab right after `preview_start` opens it,
   not even once.** Doing so before the Flutter web app's first cold boot
   finishes orphans the debug connection — the tab gets stuck on the raw
   un-hydrated `index.html` indefinitely, and no amount of waiting recovers
   it (this is worse than the plain reload case in point 5, which does
   eventually re-boot). If you need a clean tab, use `tabs_create` +
   exactly one `navigate()` call on the *new* tab, then wait from there —
   or just wait on the tab `preview_start` already opened without touching
   it further.
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
| Marketplace (products/orders/reviews) | ✅ done | 6 screens (home, product detail, add product, orders, order detail, reviews). Live-tested DB/RLS (own-listing insert, deny-listing-as-another-seller, cross-shg browse, seller-only order status update) and UI (grid + product detail render correctly). Needs Supabase Storage for product images eventually (not wired) |
| Government schemes | ✅ done | Model, repository, 4 screens (catalog, detail, eligibility checker, tracking). Eligibility checker is a client-side keyword-matching heuristic against each scheme's eligibility text, not a real rules engine — documented as a deliberate placeholder. Live-tested DB/RLS (own-application insert, deny-apply-for-another-member, deny-direct-catalog-edit) and UI (status badges render correctly, eligibility filter toggle verified to actually change results) |
| Training | ✅ done | Model, repository, 4 screens (catalog, course detail, quiz, certificates). Quiz is a small generic 3-question set (not tied to specific course content — no quiz-content table in the schema), passing ≥2/3 marks the course certified; documented as a placeholder. Live-tested DB/RLS (own-progress insert, deny-progress-for-another-member, deny-direct-catalog-edit, shared shg visibility) and UI (progress bars, radio quiz, disabled-in-demo-mode submit) |
| Digital payments | ✅ done | `PaymentProcessor` abstraction (`lib/services/payment_processor.dart`) with a `MockPaymentProcessor` that always succeeds and synthesizes a reference — swapping in a real gateway later is a one-file change. 3 screens (home, scan & pay, history). Live-tested DB/RLS: payments are **private to the owning member**, not shared shg-wide like savings/loans (deliberate — confirmed correct), deny-recording-for-another-member also confirmed. UI-tested: amount entry, mode chips, disabled-in-demo-mode Pay button |
| Announcements | ✅ done | Model, repository, 2 screens (home list with unread-dot indicator + leader/staff-only post dialog, detail with read-receipt tracking via `announcement_reads`). Global (`shg_id is null`) + shg-scoped announcements merged via `.or()` query. Live-tested DB/RLS (member-post denied, leader-post allowed, shared shg read visibility, own read-receipt insert allowed, marking another member's receipt denied) and UI (list + detail render correctly in demo mode, member correctly sees no post button) |
| Support (chat/voice/FAQ/tickets) | ✅ done | Model, dual-mode repository, 5 screens (hub, full ticket list, raise-ticket form, ticket detail/chat thread with staff status-change menu, FAQ accordion) + `VoiceSupportService` abstraction (`MockVoiceSupportService` cycles canned Q&A pairs) for the record→transcribe→answer flow, wired incl. `/app/support/ticket/:id`. Tickets are private per-member, visible to staff (crp/clf/admin) — staff see all tickets with the member's name shown; member sees only their own. Live-tested DB/RLS (own-ticket insert, deny-insert-for-another-member, own-ticket read, deny-read-for-non-owner-non-staff, staff-can-read-any, own-message insert, deny-message-for-non-owner-non-staff, staff-can-message-any, own-status-update, deny-status-update-for-non-owner-non-staff, staff-can-update-any — 10/10 passed) and UI (hub, ticket list, chat bubbles with correct mine/theirs alignment, raise-ticket form validation, FAQ accordion, voice support page all render correctly) |
| AI Advisors (financial/scheme/market) | ✅ done | Model, dual-mode repository, hub + one shared `AiAdvisorChatPage(advisorType, title, hint)` reused across all 3 routes (identical shape, scoped by type) — chat bubbles + composer, wired incl. `/app/ai/financial-advisor` etc. `AiAdvisorService` abstraction (`MockAiAdvisorService` keyword-matches canned responses per advisor type, generic fallback otherwise) — unlike Payments/Support, the ask flow works in both demo and live mode (only the log persistence is live-only), so the chat is fully interactive without a Supabase connection. Live-tested DB/RLS (own-log insert, deny-insert-for-another-member, own-log read, deny-read-for-non-owner-non-staff, staff-can-read-any — 5/5 passed), fixtures cleaned up and verified zero remnants. UI-tested: hub renders all 3 advisor cards, Financial Advisor chat loads mock history correctly, composer input focuses and accepts real keystrokes (confirmed via `activeElement.value`) — the final send-button tap hit the same coordinate-calibration friction as the Voice Support mic button in the prior iteration and wasn't click-verified, but the ask()/setState logic is structurally identical to the already-proven Support ticket composer |
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
6. **When you need a scalar (e.g. a generated id) back from a SELECT for use
   in a later query, don't rely on `(Invoke-Sql "select id from ...").id`.**
   PowerShell 5.1 deserializes a 1-row JSON array result inconsistently vs.
   a 2+-row one (sometimes unwrapped to a bare object, sometimes an array
   needing `[0]`), and got this wrong twice, producing confusing empty-string
   UUID errors downstream. Use a `Get-Scalar` helper that always wraps the
   query in `select json_agg(t)::text from (<query>) t` and parses the JSON
   string with `ConvertFrom-Json` — this guarantees a consistent array shape
   every time, regardless of row count.

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
- **2026-07-18**: Built the full Marketplace module (6 screens: home/browse,
  product detail with reviews + place-order, add product, orders, order
  detail with status-update chips, reviews). `flutter analyze` clean. Hit a
  **sandbox-wide network outage** (DNS resolution failing for api.supabase.com,
  google.com, github.com alike — confirmed not Supabase-specific) partway
  through live DB/RLS testing, so that's deferred until connectivity returns
  (marked 🟡 in the status table, not ✅). Continuing to build the next module
  in the meantime since `flutter analyze` and local file work don't need
  network — will circle back and finish Marketplace's DB testing once the
  outage clears.
- **2026-07-18 (cont'd)**: Network recovered. Built the full Government
  Schemes module (4 screens including a keyword-heuristic eligibility
  checker) while waiting, `flutter analyze` clean. Finished the deferred
  Marketplace DB/RLS tests plus new Schemes tests — all correct (own-listing
  insert, deny-as-another-seller, cross-shg browse, seller-only order
  status update, own-application insert, deny-apply-for-another-member,
  deny-direct-catalog-edit). Hit and fixed the PowerShell scalar-extraction
  bug documented above (point 6) along the way. Live-tested both modules'
  UI on the demo server — grid/detail rendering, disabled-in-demo-mode
  buttons, and the eligibility filter actually changing results when a
  toggle flips, all confirmed correct. All fixtures cleaned up (verified
  zero remnants). Next: Training module.
- **2026-07-18 (cont'd)**: Built the full Training module (4 screens
  including a generic quiz). `flutter analyze` clean (2 new info-level
  `RadioListTile` deprecation notices, left as-is). Live-tested DB/RLS —
  all 4 checks passed on the first try (own-progress insert, deny-for-
  another-member, deny-direct-catalog-edit, shared visibility). Hit a real
  UI-testing snag: navigating straight to a deep route via `navigate()`
  silently triggers a full page reload that looks exactly like a stuck
  blank screen unless you wait ~20-30s for a full cold boot — traced it via
  DOM inspection (no canvas/glass-pane = un-hydrated raw HTML) and fixed by
  using `location.hash` assignment instead for same-session navigation,
  documented above (point 5) so it isn't re-diagnosed from scratch next
  time. Verified the full course list → detail → quiz flow renders and
  behaves correctly once past that. Next: Digital Payments module.
- **2026-07-18 (cont'd)**: Built the full Digital Payments module (mock
  processor abstraction + 3 screens). `flutter analyze` clean. Live-tested
  DB/RLS — all 4 checks passed, confirming payments are correctly private
  per-member (not shg-shared like most other modules). The demo server
  (port 5001) had actually died between iterations (not just slow to boot
  — `preview_list` showed it missing entirely); a plain restart fixed it.
  UI-tested payments home, scan & pay form (amount entry + mode chips both
  verified interactive), all correct. Next: Announcements module.
- **2026-07-18 (cont'd)**: Built the full Announcements module (model,
  dual-mode repository merging global + shg-scoped announcements via
  `.or()`, home list with unread indicator + leader/staff post dialog,
  detail page with read-receipt tracking). `flutter analyze` clean (same 9
  pre-existing info-level lints, 0 new issues). Live-tested DB/RLS — all 5
  checks passed (member-post denied, leader-post allowed, shared shg read
  visibility, own read-receipt insert allowed, marking another member's
  receipt denied); fixtures cleaned up and verified zero remnants
  afterward. Hit a new variant of the known `navigate()`-reload gotcha:
  calling it even *once* right after `preview_start` (before the app's
  first cold boot finished) orphaned the Flutter debug connection and left
  the tab stuck on un-hydrated raw HTML indefinitely — a plain wait never
  recovered it. Fix: after `preview_start`, don't call `navigate()` at all;
  either just wait on the tab it already opened, or open a fresh tab via
  `tabs_create` + a single `navigate()` call and wait from there. UI-tested
  the golden path on a fresh tab: list renders with unread dots, detail
  page renders title/date/body, member correctly has no post button
  (demo-mode auto-session as "Lakshmi", SHG Member). Next: Support module.
- **2026-07-18 (cont'd)**: Built the full Support module (model, dual-mode
  repository, 5 screens, `VoiceSupportService`/`MockVoiceSupportService`
  abstraction). Tickets are private per-member but staff (crp/clf/admin)
  can see and act on all of them — the same list/detail screens serve both
  audiences by branching the query on `isStaff`, avoiding a separate staff
  inbox. `flutter analyze` clean (same 9 pre-existing info-level lints, 0
  new issues). Live-tested DB/RLS with a 3-profile fixture set (member A,
  member B, staff) — all 10 checks passed (own-ticket insert, deny
  insert-for-another-member, own-ticket read, deny read for a non-owner
  non-staff member, staff-can-read-any, own-message insert, deny message
  for a non-owner non-staff member, staff-can-message-any, own
  status-update, staff-can-update-any); fixtures cleaned up and verified
  zero remnants. Confirmed the `flutter-web-demo` server had gone stale
  again (running but built before this iteration's new files — it never
  hot-reloads) — restarted it, and this time even a *single* `navigate()`
  call on the tab `preview_start` had just opened reproduced the same
  orphaned-connection freeze from the Announcements iteration, confirming
  that gotcha is real and not a one-off: `tabs_create` + one `navigate()`
  on the fresh tab booted cleanly instead. UI-tested the golden path: hub
  (quick-access tiles + ticket list), ticket detail (chat bubbles correctly
  aligned mine-right/theirs-left with sender labels), raise-ticket form
  (empty-subject validation error rendered correctly), FAQ accordion
  (expands to show the answer), and the voice support page (mic button +
  idle label render; the mock transcribe→answer tap flow render-verified
  but not click-verified — this session's resized browser viewport
  (412×915) produced a screenshot/click coordinate mismatch not seen on
  the default viewport size, so exact-coordinate taps landed inconsistently;
  worth avoiding `resize_window` on the demo tab in future iterations
  unless truly needed). Next: AI Advisors module.
- **2026-07-18 (cont'd)**: Built the full AI Advisors module (model,
  dual-mode repository, hub + one shared `AiAdvisorChatPage` reused across
  all 3 advisor routes, `AiAdvisorService`/`MockAiAdvisorService`
  abstraction). Deliberately made the ask flow work in both demo and live
  mode (only DB persistence is live-gated) since a chat-style feature reads
  as broken if it's inert in demo mode — a different call than
  Payments/Support, where disabling the composer in demo mode is correct
  because those actions have real financial/support consequences.
  `flutter analyze` clean (same 9 pre-existing info-level lints, 0 new
  issues). Live-tested DB/RLS with a 3-profile fixture set — all 5 checks
  passed (own-log insert, deny insert-for-another-member, own-log read,
  deny read-for-non-owner-non-staff, staff-can-read-any); fixtures cleaned
  up and verified zero remnants. UI-tested on a fresh tab (no `resize_window`
  this time, confirming the coordinate mismatch isn't resize-specific — it
  recurred even at the default viewport): hub renders all 3 cards
  correctly, Financial Advisor chat loads its mock history, composer input
  focus and real keystroke typing both confirmed via
  `document.activeElement.value` (`"Howmuchtosave?"` — note `key` action
  with `"space"` tokens didn't produce actual space characters, only
  visible via reading the input value, not screenshots). The final
  send-button tap didn't land after several coordinate attempts — same
  friction as the Voice Support mic button last iteration. Root cause is
  still unconfirmed (possibly semantics-tree hit-testing being imprecise
  for small icon-button targets specifically, since text-field-sized
  targets have consistently focused correctly all session); worth
  investigating directly if a future module's golden path depends on a
  small icon-button tap succeeding. Next: Reports module.
