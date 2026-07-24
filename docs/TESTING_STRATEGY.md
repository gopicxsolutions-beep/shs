# Testing Strategy — SHG Saathi (NavaSakhi)

This document is the project's testing philosophy, not just its test
inventory: why the project distrusts "it compiles" and "it should work," what
methodology replaces that distrust, and what classes of bug that methodology
has actually caught. See [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) for how
this feeds into release go/no-go decisions.

---

## 1. The core belief

> Compiling, or reasoning that a policy "should" work, is not verification.

This isn't a slogan — it's a direct response to a real incident. A previously
reviewed and deployed RLS fix (`marketplace_orders_update_seller_or_staff`)
was silently broken in production for hours: the fix's own `WITH CHECK` clause
self-referenced its table, triggering Postgres's `42P17` infinite-recursion
error on every legitimate seller order-status update. No code review or
migration-consistency check caught it, because none of them actually executed
the SQL path — it was found only because a strict rule ("verify against the
real live system, not by reasoning about it") forced someone to try the exact
real user action and read the raw Postgrest error. That incident is why the
methodology below exists in its current, deliberately paranoid form.

---

## 2. Automated test suite

**Frameworks**: `flutter_test` only — no `mockito`/`mocktail`, no
`integration_test` package, no golden-file tooling. **CI is now wired**:
`.github/workflows/ci.yml` runs `flutter analyze`/`flutter test` on every
push and PR (demo mode only, no secrets needed) — not yet committed/merged
as of this writing, but no longer the "nothing runs automatically" gap
described in earlier rounds (see
[QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §7).

**Inventory** (71 files under `test/`):

| Directory | Count | What it tests |
|---|---|---|
| `test/models/` | 4 | Pure unit tests of model getters/parsing (e.g. `Meeting.hasPassed` date math, timezone parsing, scheme eligibility evaluation) |
| `test/repositories/` | 8 | Aggregation logic, dual-mode fallback behavior, meeting cancellation/stats exclusion, admin dashboard stats, scheme/quiz-question repositories, file-upload wiring |
| `test/pages/` | 26 | Widget tests of individual pages — mostly regression tests pinned to a specific previously-fixed bug, now including admin pagination, meeting cancel/action-item assignment, scheme eligibility, course quiz content, and notification-sync-on-load coverage |
| `test/widgets/` | 16 | Shared components, including 3 WCAG contrast-ratio tests and several tests that reproduce a *bug shape* (double-submit guard, dialog-mounted guard, stale-response guard) in an isolated minimal widget, because demo-mode repositories resolve too fast to observe the real race in situ |
| `test/routes/` | 9 | The heaviest-weight tests: exhaustive route sweeps and layout-stress tests, several of which loop over every registered route and generate one test per route dynamically |
| top-level | 3 | Full boot-to-login smoke test; router error-page test; locale-switching regression test |
| `test/services/` | 4 | HTTP timeout client, voice intent classifier, notification-sync decision logic, payment processor |

A literal grep for `test(`/`testWidgets(` call sites finds 183 static
occurrences — this undercounts the real number, since the route-sweep files
generate one test per route inside a loop. The **reliable figure is the one
tracked by hand after each round's actual `flutter test` run**: **931 passing
tests** as of the most recent recorded round. A single earlier round (looping
a new stress test over all 75 routes) added 152 permanent regression tests in
one commit — this loop-generation pattern is *part of how* the suite grew
from roughly 480 to 713 tests without 230 hand-written test bodies, and it has
continued to grow since (713 → 931) across subsequent rounds of module work
and localization coverage.

---

## 3. Manual/live testing methodology — the primary verification strategy

Because browser automation cannot reliably drive Flutter Web's text inputs in
this environment, real end-to-end verification for anything backend/RLS-related
happens by hitting Supabase's Management API SQL endpoint directly and
**simulating each role's RLS context in raw SQL** — this exercises the real
schema and real policies, not a mock of them.

### 3.1 The technique

1. **Fixtures**: a `__TEST__`-prefixed SHG + member + leader profile, with
   matching `auth.users` rows (required — `profiles.id` FKs to
   `auth.users.id`), using fixed recognizable UUIDs for trivial cleanup.
   User-authorized in advance, on the explicit condition they're always
   cleaned up.
2. **RLS context simulation**, within one SQL session:
   ```sql
   set local role authenticated;
   set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';
   -- the real query, exactly as the app would run it
   ```
   `auth.uid()` reads this session-local claim, so every policy evaluates
   exactly as it would for that real user — without needing a real JWT per
   role under test.
3. **The row-count rule — the single most important lesson in this
   methodology**: *always check actual affected/visible row counts, never
   HTTP status.* A `WITH CHECK`-less, `USING`-only policy doesn't error when
   it blocks a mutation — it silently matches 0 rows and still returns HTTP
   200/success. A first attempt at this methodology got a false "PASS" by
   checking status code instead of row count, and it cost real debugging time
   before the mistake was caught. The fix: wrap every tested mutation as
   ```sql
   with r as (<statement> returning 1) select count(*) from r;
   ```
   and assert on the count, never on whether the call "succeeded."
4. **Four boundary cases tested per table, every time**: owning-member-can-
   write-her-own-row, wrong-role-denied, shared-SHG-read, and cross-tenant
   isolation (a user from a *different* SHG cannot see this SHG's rows).
5. **Cleanup discipline**: delete every fixture row across every table
   touched, plus the `auth.users` rows, and **verify zero rows remain by
   re-querying** — never leave synthetic data in the live project.
6. A secondary, purely-tooling gotcha worth keeping in mind: PowerShell 5.1
   deserializes a 1-row JSON result inconsistently versus a 2+-row one, so
   scalar lookups always go through a helper that wraps the query in
   `select json_agg(t)::text from (<query>) t` and parses with
   `ConvertFrom-Json`, guaranteeing a consistent shape regardless of row count.

### 3.2 Paired with real UI testing, not a replacement for it

DB-level RLS testing proves the schema/policy layer end-to-end, but the
methodology explicitly does **not** treat that as sufficient on its own — the
golden path for each module is also exercised in the Browser pane against the
real `flutter-web` dev server (activate the accessibility semantics tree once
per load, click by coordinate, verify `document.activeElement`, type via real
sequential key presses — the technique this environment needed to actually
drive Flutter Web's CanvasKit-rendered text fields). Flutter's own
`integration_test` package is explicitly flagged in the project's own history
as "the more robust long-term answer" versus this manual live-SQL-simulation
technique — it was never adopted, and remains a real gap (§5).

### 3.3 The strict rule this methodology is governed by

> Demo mode is permitted ONLY for pure UI/UX/layout checks (overflow,
> text-scale) where no backend is involved. Every other check — functionality,
> data, backend, features — uses the real Supabase-backed live app, never
> demo mode.

This was made an explicit standing rule after early rounds risked treating a
clean demo-mode click-through as equivalent to a verified live fix, which it
is not: demo mode's mock repositories cannot fail the way a real RLS policy,
a real race condition, or a real network error can.

---

## 4. Bug taxonomy — what 82 rounds of this methodology actually found

277 confirmed, fixed bugs across 82 rounds as of the most recent recorded
session. The categories below recur enough to be worth naming as classes,
each with a representative example and current status.

| Category | Scope found | Representative example | Status |
|---|---|---|---|
| **RLS infinite recursion** (`42P17`) | 2 confirmed instances | A `WITH CHECK` clause subquerying its own table re-triggered the same policy — the incident described in §1, live in production for hours before being caught | Fixed via `security definer` helper functions that read the "other party" without re-triggering the policy |
| **Column-lock / `WITH CHECK` gaps** | 6+ dedicated rounds, still surfacing new instances as late as round 82 | A leader-approves-loan policy locked `shg_id`/`member_id` but never `amount`/`purpose`/`tenure_months` — approving one member's loan could simultaneously rewrite its terms | Fixed per-instance; the *pattern itself* (row-access ≠ column-access) is now a standing design rule (see [ARCHITECTURE.md](ARCHITECTURE.md) §3.2) |
| **INSERT lifecycle-column gaps** | 1 dedicated round, 8 gaps, 1 critical | A member could self-`INSERT` a loan already `status:'active'`, fully disbursed — skipping the entire approval workflow, not just bypassing it after the fact | All fixed; every lifecycle column now pinned to its only-legal starting value on INSERT |
| **DELETE-scope gaps** | 1 dedicated round, 3 gaps | A leader could delete a completed meeting row outright, cascading to permanently erase its minutes and every member's attendance — no trace left | Fixed by splitting broad `FOR ALL` policies into scoped INSERT/UPDATE plus a staff-only DELETE |
| **Role-escalation / self-promotion** | 3 rounds (1 critical, 2 follow-on paths found by adversarial re-audit) | An approved member could `PATCH {"role":"leader"}` on her own profile, since the original fix only checked `shg_id` didn't change *in the same statement* — not whether it was already null | Fixed with defense-in-depth; see [ARCHITECTURE.md](ARCHITECTURE.md) §3.3 for the full chain |
| **Dead/stale lifecycle state after mutation** | Large family, 5+ rounds | `MeetingRepository.setStatus()` has zero call sites anywhere in the app — a meeting's `status` never advances past `'upcoming'`, silently breaking attendance reports, home-screen bucketing, and QR check-in's "today's meeting" lookup at 6+ independent call sites | Fixed by deriving "has this happened" from date math (`hasPassed`) everywhere, never trusting `status`; now has dedicated regression coverage |
| **Stale UI after a successful same-page write** | 2 rounds | Placing a marketplace order genuinely decremented stock server-side every time, but the already-open product page never reloaded, so stock appeared unchanged — a strong, false nudge to re-order | Fixed with an explicit reload-after-write pattern; swept across all `AppAsyncBuilder` call sites for the same shape |
| **Accessibility / screen-reader gaps** | 1 dedicated round, 5 gaps | The 6 OTP digit boxes at login — every single user's entry point — announced as 6 identical, indistinguishable nodes with no indication they're digits 1–6 | Fixed with `MergeSemantics` + per-digit labels; 5 new accessibility tests added |
| **Localization gaps** | 1 dedicated round, 8 gaps, plus a later full-coverage round | `AppAsyncBuilder`'s default error message and Retry button — backing 50+ call sites app-wide — were hardcoded English | Fixed for shared/high-traffic widgets first; full coverage has since been completed — 91 of 92 page files under `lib/pages/` reference `AppLocalizations` (the 92nd, `dashboard_page.dart`, is a pure role-dispatcher with no literal UI strings to localize) |
| **N+1 queries** | 1 real instance, then a dedicated zero-new-found audit | An analytics repository issued 1+5N queries — 150+ round trips for a 30-SHG federation | Fixed; dedicated audit of all repositories found no further instances |
| **Session/token expiry handling** | 1 dedicated round | The app's auth listener refetched the full profile on every auth event, including the hourly silent token-refresh tick — two unnecessary round trips per hour, per session | Fixed to skip refetch specifically for that event type |
| **Double-submit / race conditions** | Multiple rounds | A support-ticket composer's Send button was correctly guarded against a double-tap, but the same composer's Enter-key path bypassed the guard entirely | Fixed; a systematic sweep of all write methods/call sites found this as the sole remaining gap |
| **Layout overflow / text-scale / narrow-screen stress** | Large, escalating family across several rounds | Combining two previously-separately-passing stresses (320px width *and* 2.0x text scale) found genuine overflow on 15 of 75 routes — including the login and OTP pages, every user's entry point — invisible to either single-axis test alone | Fixed; this round alone added 152 permanent regression tests |
| **Security-definer RPC over-exposure** | 3 independent discoveries + 1 dedicated audit | A helper function correct for its RLS-internal use was also directly callable as a public RPC, leaking unscoped data | Each fixed on discovery; a full inventory audit of every such function found zero further instances |

**What this taxonomy implies for new work**: the categories that kept
resurfacing even after a "complete" dedicated audit (column-lock gaps,
dead-lifecycle-state) are exactly the ones worth re-checking whenever a new
table or a new status-driving column is added — treat "we already audited
this class" as provisional, not final, the way round 82 (the last recorded
round) still found two more column-lock gaps in tables not previously
covered.

---

## 5. Current health snapshot and disclosed gaps

As of the most recent recorded round:
- `flutter analyze`: 0 issues.
- `flutter test`: 931/931 passing.
- RLS CRUD sweep (SELECT/INSERT/UPDATE/DELETE, systematically re-derived
  against every column) declared complete across ~29 RLS-enabled tables — yet
  new instances of the same bug *shape* still surfaced afterward in tables not
  previously in scope, which is the honest reading: the methodology is sound,
  the table surface was not fully exhausted even after 82 rounds.

**Disclosed, not hidden, gaps in the testing approach itself**:
- CI is now wired (`.github/workflows/ci.yml`), committed on this working
  branch, but not yet merged into main — until it is, `analyze`/`test` still
  only run manually per round in practice.
- No `integration_test` adoption, despite the project's own log flagging it as
  the more robust long-term answer to the manual live-SQL-simulation
  technique.
- No load/performance testing.
- Full localization coverage is now real (91 of 92 page files), but the
  translation quality itself was produced by parallel agents in one pass and
  verified only structurally (compiles, renders, existing `l10n_test.dart`
  locale-smoke tests pass) — not reviewed string-by-string by a native
  Hindi/Telugu speaker. Worth a human linguistic QA pass before treating the
  translations as launch-ready, even though they are structurally complete.

Before treating "931/931 passing, 0 analyze issues" as current, re-check
[docs/DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)'s tail — these numbers
are a point-in-time snapshot, not a live figure this document can guarantee.
