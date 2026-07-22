# Quality Management & Production Readiness — SHG Saathi (NavaSakhi)

How quality is defined, gated, and audited on this project, and an honest
go/no-go accounting of what's done versus outstanding before a real production
launch. Pairs with [TESTING_STRATEGY.md](TESTING_STRATEGY.md) (how correctness
is verified) and [MANIFESTO.md](MANIFESTO.md) (why these gates exist).

---

## 1. Definition of done

A feature is not done because it compiles or because the code was read and
reasoned about. It is done when:

- [ ] It works in **both** demo mode and live mode.
- [ ] Every role that should have access does, and every role that shouldn't
      is blocked **at the RLS layer**, not just hidden in the UI.
- [ ] New user-facing strings exist in **all three** `.arb` files
      (`app_en.arb`, `app_hi.arb`, `app_te.arb`).
- [ ] The layout survives a large text-scale setting (1.3x–2x) without
      clipping/overflow.
- [ ] It was actually exercised — a real UI click-through or a real query
      against real RLS — not merely read and reasoned about (see
      [TESTING_STRATEGY.md](TESTING_STRATEGY.md) §1 for why this line exists).
- [ ] Any intentional placeholder (scheme-eligibility heuristic, generic
      course quiz, admin monitoring metrics, mocked voice STT/TTS) is
      documented as a placeholder in-code and in the docs, not presented as
      authoritative.

If any box can't be checked — no live preview available, a dependency wasn't
testable — that must be stated explicitly, not silently skipped.

---

## 2. Security review cadence and history

Security is not a one-time pass; it's a series of dedicated, systematic sweeps
by CRUD operation, each covering *every* RLS-enabled table, not just the table
that prompted the round. As of the last recorded audit: **36 migrations**,
**44 `security definer` function declarations across 18 files**, **130
`CREATE POLICY` statements across 21 files**, **149 `WITH CHECK` clauses
across 23 files**.

### 2.1 Every bug explicitly marked CRITICAL, in order found

1. **Self-service privilege escalation to Admin** — any authenticated user
   could set their own `profiles.role` to `admin`/`crp`/`clf` via the
   self-service Role Select flow. The headline finding of the entire audit
   history. Closed.
2. **Missing `INTERNET` permission in the Android release manifest** — the
   permission existed only in debug/profile source sets, never merged into
   release builds; a real Play Store build would have failed every Supabase
   call at runtime. Fixed.
3. **`profiles_insert_self` had no column-level check** — the INSERT-side
   twin of #1: a freshly-authenticated user could `POST` a profile already
   carrying `role:'admin'` on their very first row. Closed.
4. **Self-promotion to leader via two independent paths** — an adversarial
   re-audit (round 46, itself run specifically to look for exactly this)
   found the original fix for #1 didn't verify `shg_id` was already non-null,
   so an approved member could still self-promote to leader. Closed with
   defense-in-depth (see [ARCHITECTURE.md](ARCHITECTURE.md) §3.3).
5. **`loans_insert_self` allowed a self-disbursed, pre-approved loan** — a
   member applying for a loan could `INSERT` it already `status:'active'`
   with an arbitrary disbursed amount, completely bypassing the
   pending→leader-approval workflow — judged more severe than the earlier
   self-*approval* bug (fixed on UPDATE) since here no approval step was ever
   reachable to bypass; the loan simply existed, funded, from creation.
   Closed.

### 2.2 The systematic CRUD sweep

Each operation type got its own dedicated, full-table-surface audit round
(not spot checks): SELECT-scope, INSERT-lifecycle-columns, UPDATE
column-locks, DELETE-scope. Findings per round are in
[TESTING_STRATEGY.md](TESTING_STRATEGY.md) §4's bug taxonomy. The sweep was
declared complete after covering all ~29 RLS-enabled tables — and then round
82 (the last recorded round) still found two more column-lock gaps in tables
not previously in scope. **Read this as confirmation the methodology works,
not that the surface is provably exhausted** — a new table or a new
status-driving column should be assumed to need the same sweep applied to it,
not assumed safe by association with an already-audited module.

---

## 3. Accessibility

One dedicated audit round found 5 real screen-reader gaps in components that
sit on every user's path, most notably: the 6 OTP digit boxes at login
announced as 6 identical, indistinguishable nodes with no "digit 1 of 6"
context — the single highest-traffic screen in the whole app, since every
user passes through it. All 5 fixed, with matching regression tests added.
Confirmed already fine at the time: every `IconButton` has a tooltip; all
charts route through one shared, already-accessible component; all status
indicators pair color with text. This was a **bounded** audit pass — contrast
ratios and full app-wide focus order were not separately certified.

---

## 4. Localization QA

One dedicated audit found and fixed 8 real hardcoded-string gaps, prioritized
by traffic: the shared error/retry component backing 50+ call sites, the
back button, the discard-changes dialog, the 404 page, and the QR scanner
sheet's 9 strings. Zero placeholder/untranslated values found — key parity
across all three `.arb` files was exact after the additions.

**The disclosed, larger gap**: only ~10 of 109 page/widget files use
`AppLocalizations` at all. Most feature screens (Savings, Loans, Meetings,
Marketplace, Schemes, Reports, Admin) are English-only **by current scope**,
not by oversight — fully localizing the remaining ~99 files is explicitly
flagged as a multi-hundred-key initiative beyond any single bounded audit
pass. Treat "localization audited" as "the highest-traffic shared surface is
covered," not "the app is fully localized."

---

## 5. Release readiness — native config and ops

### 5.1 Android

- Conditional release signing is wired: reads `android/key.properties` if
  present, **falls back to the debug keystore if absent**. `key.properties`
  does not currently exist in the repo (correctly `.gitignore`d).
  **Outstanding**: generate a real release-signing keystore and populate
  `key.properties` — this is a genuine credential only the app owner can
  provide.
- `minSdk`/`targetSdk`/`compileSdk`/version fields are left at Flutter's own
  defaults — not reviewed/pinned for this specific app.
- `applicationId` is still the default template value
  (`com.shgsaathi.shg_saathi`) with the template's own "specify your own
  unique Application ID" comment left in place — worth a deliberate decision
  before store submission, not an oversight to silently keep.
- `INTERNET` and `CAMERA` permissions are declared (the former only after the
  CRITICAL fix in §2.1). **No `RECORD_AUDIO`** — consistent with the Voice
  Assistant being fully mocked (see [AI_MODULES.md](AI_MODULES.md) §3); if a
  real STT provider is ever wired, this permission becomes required.

### 5.2 iOS

- `NSCameraUsageDescription` is declared ("scan QR codes for meeting check-in
  and payments"). No `NSMicrophoneUsageDescription` — same reasoning as
  Android.
- **Outstanding**: App Store submission requires the app owner's own Apple
  Developer Program membership — not something a development session can
  provide.

### 5.3 Ops / environment

- All 3 Edge Functions are written and deployed
  (`ai-advisor-proxy`, `generate-report-snapshots`, `payment-webhook-handler`).
  `pg_cron`/`pg_net` are enabled; the nightly report-snapshot job is wired to
  send an `x-cron-secret` header.
  **Outstanding**: the `CRON_SECRET` value itself must still be set in both
  Supabase Vault and the Edge Function's environment
  (`supabase secrets set CRON_SECRET=...`) — the migration only wires the
  plumbing, it doesn't supply the secret. Until set, the function runs with a
  safe generic error rather than failing insecurely.
- **Outstanding**: audit `profiles.role` for any account that was already
  `admin`/`crp`/`clf` *before* the self-escalation fix (§2.1 #1) landed, in
  case a real account exploited the gap before it was closed.

---

## 6. Observability

**Crash/error reporting is wired** (`sentry_flutter`), following the same
compile-time-config pattern already used for Supabase: `Env.sentryDsn`
(`SENTRY_DSN` via `--dart-define-from-file`) is blank by default, and
`main.dart` only activates `SentryFlutter.init` when a real DSN is supplied —
without one, the app falls through to the same `runZonedGuarded` +
`debugPrint` behavior it always had, so nothing changes for a build that
doesn't opt in. Once initialized, both uncaught errors and widget-build
errors (`FlutterError.onError`) are reported automatically.

**Outstanding**: no DSN is committed to the repo — a real Sentry project and
its DSN are an app-owner deployment step, the same pattern as
`CRON_SECRET`/the Groq API key/the Android release keystore (§5). Until a
real DSN is supplied to a release build, that build runs with reporting
disabled, identically to today. The `audit_log` table (admin/privileged-
action audit trail) remains a separate concern and does not substitute for
this.

---

## 7. Production-readiness checklist

| Area | Status |
|---|---|
| `flutter analyze` | Clean (0 issues) as of last recorded check |
| `flutter test` | 713/713 passing as of last recorded check |
| CI enforcing analyze/test automatically | **Not set up** — manual, per-round only |
| RLS CRUD sweep (SELECT/INSERT/UPDATE/DELETE) | Systematically completed once; new instances of known bug shapes still surfaced afterward — treat as an ongoing discipline, not a one-time certification |
| Privilege-escalation closure | Closed (5 CRITICAL findings, all fixed, one via adversarial re-audit) |
| Accessibility | Bounded audit complete for highest-traffic screens; not a full WCAG certification |
| Localization | Bounded audit complete for shared/high-traffic widgets; ~99 page files remain English-only by disclosed scope |
| Android release signing | Wired, but real keystore credential still needed from app owner |
| iOS release | Needs app owner's Apple Developer account |
| `CRON_SECRET` | Plumbing deployed, secret value still needs setting |
| Crash/error telemetry | **Wired** (Sentry, opt-in via `SENTRY_DSN`) — a real project DSN is still an app-owner deployment step |
| Real payment gateway | Mocked — `payment-webhook-handler` exists for when one is commissioned |
| Real file/document upload | Metadata-only — no Storage wiring yet |
| Real voice STT/TTS | Mocked — see [AI_MODULES.md](AI_MODULES.md) §3 |
| AI advisor disclaimer | **Shown on every AI-branded screen** (see [AI_MODULES.md](AI_MODULES.md) §6) |
| AI advisor content moderation / prompt-injection defense | **Absent** — a deliberate scope gap, worth a design decision before scaling real usage |

This table is a snapshot, not a live source — re-verify against
[docs/DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)'s latest entries and
the actual current migration/test state before using it to make a real launch
decision.
