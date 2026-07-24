# Architecture — SHG Saathi (NavaSakhi)

Technical reference for how the system is actually built: layering, data model,
security design, atomicity guarantees, and the concrete rules a new module must
follow. For *what* the app does, see [SRS.md](SRS.md). For AI-specific
architecture, see [AI_MODULES.md](AI_MODULES.md).

---

## 1. Layering

```
lib/pages/<domain>/*.dart        UI screens (one file per screen)
        │  reads/writes via
lib/repositories/<domain>_repository.dart   dual-mode data access
        │  branches on
        │    _live = SupabaseService.isConfigured
        │        true  → real Supabase (Postgres via PostgREST, RPC, Realtime)
        │        false → lib/data/<domain>.dart mock constants ("demo mode")
lib/models/<domain>.dart          plain Dart class, fromMap(Map) factory
lib/state/app_state.dart          ChangeNotifier: session, profile, role, language
lib/routes/{paths,router}.dart    go_router — path constants + route table + redirect guard
lib/services/*.dart               third-party integrations, each with an interface + Mock*
lib/widgets/*, lib/layout/*       shared design-system components, app shell/nav
```

**Why dual-mode is load-bearing, not a nice-to-have**: the app must be fully
explorable — every dashboard, every role, every screen — with zero backend
configured, for demos and low-connectivity use. Every repository therefore
branches at the top of every method: `if (!_live || id == null) return
_mockXxx();` else a real query. Demo-mode "writes" go into static in-memory
fields on the repository class (survive the session, never persist, reset on
restart) rather than being no-ops that look broken.

**Model shape**: plain Dart classes with a `fromMap(Map<String, dynamic>)`
factory that mirrors the Supabase table row 1:1, including PostgREST embedded
joins (`select('*, profiles(name)')` → `map['profiles']['name']`). No ORM, no
code generation for models.

**Navigation**: `context.go()` everywhere, never `push()`/`pop()` — this app
replaces the navigation stack rather than pushing onto it. Every write flow
navigates to a known destination *before* showing a result `SnackBar` on the
captured `ScaffoldMessenger`, because `context.go()` tears down the current
`Scaffold` before a pre-navigation SnackBar would ever get a frame to render.

**State management**: a single app-wide `ChangeNotifier` (`AppState`) holds
session, profile, role, and language. Pages read it via `context.watch` (for
values that should trigger a rebuild) or `context.read` (for one-off actions).

**Services**: any third-party API integration gets an interface in
`lib/services/` plus a `Mock*` implementation, selected the same way
repositories select live-vs-demo — see `ai_advisor_service.dart` as the
canonical example. This makes swapping a real provider in later a one-file
change, and it's why the Voice Assistant and Voice Support features can ship a
complete, testable UI/UX today with a documented mock STT/TTS underneath (see
[AI_MODULES.md](AI_MODULES.md) §3).

---

## 2. Data model

28 base Postgres tables + 1 view (`shg_directory`), defined starting in
`supabase/migrations/0001_init_schema.sql` and hardened across 41 further
migrations:

| Table | Domain |
|---|---|
| `shgs` | SHG (group) master record — includes sensitive `bank_account`/`ifsc`; base table read directly only by admin/staff (`fetchAllShgs()`) |
| `shg_directory` (view) | Safe public subset of `shgs` for onboarding search — excludes bank fields entirely |
| `shg_own_masked` (view, migration `0045`) | What an ordinary member's/leader's own-SHG lookup (`fetchShg()`) actually reads — same row scope as the base table's own RLS, but `bank_account`/`ifsc` are nulled server-side unless the caller is leader/staff for that SHG |
| `profiles` | One row per user; `role`, `shg_id`, identity |
| `shg_join_requests` | Member → SHG join workflow, one-pending-per-member |
| `shg_documents` | Document metadata + real Storage `storage_path` (real `file_picker` upload UI, private `shg-documents` bucket) |
| `savings_entries` | Member savings deposits, `pending`/`verified` |
| `loans`, `loan_payments` | Loan lifecycle and repayment history |
| `financial_ledger` | SHG cashbook/ledger/bank/audit entries, one table, `entry_type`-discriminated |
| `meetings`, `meeting_attendance`, `meeting_minutes`, `meeting_action_items` | Meeting lifecycle, attendance, MoM |
| `livelihood_activities` | Member microenterprise tracking |
| `marketplace_products`, `marketplace_orders`, `marketplace_reviews` | Commerce |
| `schemes`, `scheme_applications` | Government welfare scheme catalog + applications; `schemes.eligibility_criteria` (JSONB, migration `0040`) backs the real structured eligibility rules engine — see §7 |
| `training_courses`, `course_progress`, `quiz_questions` | E-learning catalog + per-member progress/certification + real per-course quiz content (migration `0041`) — see §7 |
| `payments` | Digital payment records (gateway is mocked — see §7) |
| `announcements`, `announcement_reads` | Circulars + per-member read receipts |
| `support_tickets`, `support_messages` | Helpdesk tickets + threaded messages |
| `ai_advisor_logs` | AI advisor Q&A audit trail — see [AI_MODULES.md](AI_MODULES.md) §4 |
| `ai_advisor_rate_limits` | Fixed-window per-member rate-limit counters |
| `report_snapshots` | Precomputed report data (nightly Edge Function) |
| `analytics_kpis` | Platform-wide KPI cache |
| `audit_log` | Admin/privileged-action audit trail |

Every table holding SHG-scoped operational data carries (directly or via a
resolvable join) a `shg_id`/`member_id`, since RLS policies key off
`current_shg_id()`/`current_role()`/`is_staff()` (§3).

---

## 3. Security model — RLS is the authorization boundary

Client-side role checks throughout `lib/pages/**` (`isLeaderOrStaff`, route
prefix gating in `router.dart`) are **UX only** — they make the right thing
easy to find, they do not make the wrong thing impossible, because a client can
always call the PostgREST API directly. The actual boundary is Postgres RLS,
verified independently table-by-table.

### 3.1 Helper functions (`security definer`, avoid self-referencing recursion)

| Function | Returns |
|---|---|
| `current_role()` | Caller's `profiles.role` |
| `current_shg_id()` | Caller's `profiles.shg_id` |
| `is_staff()` | `role in ('crp','clf','admin')` |
| `is_leader_or_staff()` | `role in ('leader','crp','clf','admin')` |
| `profile_shg_id(uuid)` | Another profile's `shg_id` (for staff/leader cross-member checks) |

**Why these exist and must be reused, not reinlined**: a policy on table `T`
that subqueries `T` itself to check the caller's own row re-triggers the same
policy, causing Postgres error `42P17` (infinite recursion). This happened in
production on `marketplace_orders_update_seller_or_staff` and again on the
equivalent `loans` policy — both fixed by moving the self-referencing read into
one of these `security definer` helpers, whose own internal query bypasses RLS
on its way to answering the question. New policies needing "is this the
caller's own row in this table" must use or extend these helpers, never
inline an equivalent subquery.

### 3.2 Design decisions that recur across every module

- **SHG-scoped read transparency**: within an SHG, members share **read**
  access to savings/loans/meetings/ledger/livelihood — this mirrors real SHG
  practice (figures are read out and reviewed together at meetings), not a
  default picked for convenience. Writes are scoped to the owning member, the
  SHG's leader, or staff.
- **No self-escalation, anywhere**: a row's own owner never has authority over
  the decision made about that row. Concretely enforced via a
  `security definer` helper that resolves the *other* party's identity inside
  the `WITH CHECK` clause — e.g. `loans_update_leader_or_staff`'s check
  includes `loans_member_id(loans.id) <> auth.uid()`, so a leader can approve
  any other member's loan in her SHG but is mechanically blocked from deciding
  her own. The identical shape protects `profiles.role` (§3.3) and scheme
  application decisions.
- **Column-lock independent of row-access**: "can write this row" and "can
  write this column to this value" are enforced separately. A seller updating
  a marketplace order's `status` must not, in the same `WITH CHECK`, be able to
  rewrite its `amount`/`buyer_id`; a leader verifying a savings entry must not
  be able to rewrite its `amount`/`member_id` in the same statement. This class
  of gap (column-lock completeness) was audited explicitly across every
  writable table in dedicated rounds — see
  [TESTING_STRATEGY.md](TESTING_STRATEGY.md) §3.
- **Lifecycle-column locks on INSERT**: a member applying for a loan must not
  be able to `POST` a row that's already `status:'active'` with an arbitrary
  disbursed amount — INSERT `WITH CHECK` clauses pin every lifecycle column
  (`status`, `outstanding`, `emi`, `disbursed_on`, etc.) to its only-legal
  starting value.
- **Append-only / no-DELETE tables**: `loan_payments`, `ai_advisor_logs`,
  `scheme_applications` have no DELETE policy at all — they are permanent
  audit-trail records by design, not editable/removable history.
- **Sensitive columns never in a broadly-readable view**: `shgs.bank_account`/
  `ifsc` were, for a while, reachable by *any* member of the SHG via the base
  table's row-level policy (`shgs_select_own_or_staff` has no column
  distinction — a plain `select *` from any member's client returned them),
  even though `shg_home_page.dart` only ever *rendered* the "Bank Details"
  section for leader/staff — a client-side check, not the real boundary. An
  adversarial audit of the "My SHG" module found this contradicted this
  exact bullet's own stated principle. Migration `0045` closed it with
  `shg_own_masked` (above): the same row-visibility rule as the base table,
  but `bank_account`/`ifsc` are nulled server-side via a `CASE
  is_leader_or_staff()` unless the caller actually is leader/staff for that
  SHG. `ShgRepository.fetchShg()` now reads from this view, not the base
  table; `shg_directory` (the older, narrower "public search" view) remains
  unchanged and still excludes the bank fields entirely rather than masking
  them.

### 3.3 Role-escalation prevention (the single most re-audited security property)

Defense in depth across three layers, only the last of which is the real
boundary:

1. **Client UX**: `RoleSelectPage` renders only Member/Leader as tappable once
   live; each admin page's write affordances are hidden behind an `isAdmin`
   check.
2. **Fail-fast client guard**: `AppState.setRole()` throws immediately if asked
   to set a staff role in live mode — a backstop against a future UI
   regression, not the boundary itself.
3. **Database** (the actual boundary):
   - `profiles_insert_self`: `WITH CHECK (id = auth.uid() AND role IN
     ('member','leader') AND shg_id IS NULL)` — closes the INSERT-side path
     where a brand-new signup could `POST` a profile already carrying
     `role:'admin'`.
   - `profiles_update_self_or_admin`: a non-admin self-update may only move
     `role` between `member`/`leader`, and only while `shg_id` stays `NULL` —
     i.e. only during onboarding, before any real SHG linkage exists. Once
     `shg_id` is non-null, `role` is frozen for self-service; only
     `current_role() = 'admin'` unlocks further changes.
   - `approve_shg_join_request()` (the RPC that links a member to an SHG)
     unconditionally resets `role` back to `'member'` on approval if it
     currently reads `'leader'` — closing a chained path where someone
     self-declared `role:'leader'` with no SHG yet, then had an unrelated
     leader's ordinary approval silently hand them real leadership authority.

This sequence (client fix → still-exploitable-via-REST → DB fix → adversarial
re-audit finds a second path → second DB fix) is the project's own history,
not a hypothetical — see [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §2 for
the full incident list.

### 3.4 Atomic RPCs — where a plain `UPDATE` isn't safe under concurrency

Five operations mutate money, stock, or a decision outcome in a way that a
naive client-side read-then-write race could corrupt. Each is a Postgres
function the repository calls via `supabase.rpc(...)`, with a documented,
explicitly-labeled-as-a-compatibility-shim non-atomic fallback for the case
where the migration defining it hasn't been deployed (`PGRST202`).

| RPC | Locking | Guarantees | Errors raised |
|---|---|---|---|
| `record_loan_payment(loan_id, amount)` | `SELECT ... FOR UPDATE` row lock on `loans` | Payment + balance decrement + close-on-zero happen atomically; rejects overpayment; rolls back the whole transaction (including the `loan_payments` insert) if the underlying `UPDATE` is silently filtered to 0 rows by RLS | `payment amount must be positive`; `loan not found`; `payment amount (%) exceeds outstanding balance (%)`; `not authorized to update this loan, or loan not found` |
| `add_financial_ledger_entry(shg_id, entry_type, ...)` | Transaction-scoped `pg_advisory_xact_lock` keyed on `(shg_id, entry_type)` | Running-balance read + insert happen atomically per ledger key, even for the very first entry of a key (no row yet to lock) | Table CHECK constraints catch invalid inputs |
| `decrement_product_stock(product_id)` | Single atomic `UPDATE ... WHERE stock > 0` | Prevents overselling under concurrent buyers; returns the server's real current price so the order is always recorded at the true price, never a possibly-stale client value | Returns `success:false` rather than raising, for the ordinary "already sold out" case |
| `approve_loan` / `reject_loan` | Implicit via status re-check | Rejects a second decision on an already-decided loan | `LoanAlreadyDecidedException` surfaced to the UI as "already decided by someone else" |
| `decide_scheme_application(id, approve)` | `SELECT ... FOR UPDATE` row lock on `scheme_applications` | Same already-decided race guard, for a shared, non-SHG-scoped staff review queue | `application not found`; `application already decided (current status: %)`; `not authorized to decide this application, or application not found` |

All are `security invoker`, not `definer` — the RPC's own internal write is
still subject to the underlying table's RLS, so the function provides
atomicity, not a privilege bypass. `record_loan_payment` explicitly checks
Postgres's `FOUND` after its `UPDATE` and rolls back the transaction if RLS
silently filtered it to zero rows, rather than leaving an orphaned payment
insert with no corresponding balance change.

---

## 4. Backend services

- **Supabase Postgres** — schema + RLS, per above.
- **Supabase Auth** — phone/OTP. `lib/services/auth_service.dart` wraps
  `signInWithOtp`/`verifyOTP`.
- **Supabase Realtime** — used narrowly, only where collaborative live updates
  genuinely matter (the savings ledger, so a second leader's verification
  appears without a manual refresh). Every other list is a one-shot
  `AppAsyncBuilder<T>` load — an open realtime channel has an ongoing cost and
  isn't justified for screens nobody else is editing concurrently.
- **Edge Functions** (Deno/TypeScript, `supabase/functions/`):
  - `ai-advisor-proxy` — see [AI_MODULES.md](AI_MODULES.md).
  - `generate-report-snapshots` — pg_cron-triggered nightly report
    precomputation, secured with a caller-supplied `x-cron-secret` header
    checked against a `CRON_SECRET` value (the secret itself is an app-owner
    deployment step, not something committed to the repo — see
    [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §5).
  - `payment-webhook-handler` — inbound payment-gateway webhook handling;
    the real gateway itself is not wired (§7).

---

## 5. Routing & role gating

`lib/routes/router.dart`'s `redirect` callback runs on every navigation and
enforces, in order: no-session → confined to public routes (capturing a
genuine `/app/**` deep link for replay after login) → session-but-no-profile →
confined to Profile Setup → profile-but-no-role → confined to Role Select →
member-with-undecided-join-request → confined to SHG Approval Pending →
fully onboarded → bounced out of any auth-flow screen to the dashboard. A
table of role-restricted path prefixes (`/app/admin`, `/app/loans/approval`,
`/app/shg/join-requests`, etc.) bounces a fully-onboarded user of the wrong
role back to their dashboard — **this is a UX guard, not a security
boundary**; the same restriction is independently enforced by RLS on whatever
table that screen reads or writes.

---

## 6. Architecture pattern for adding a new module

Copy this shape exactly — do not invent a parallel pattern for "just this one
module":

1. `lib/models/<domain>.dart` — plain class + `fromMap`.
2. `lib/repositories/<domain>_repository.dart` — dual-mode, as in §1; reads
   take caller-resolved ids rather than re-fetching `AppState` internally;
   writes no-op (return `false`, not throw) when the actor has no linked SHG,
   and the calling page must check that before showing a success message —
   see the recurring "false-success" bug class in
   [TESTING_STRATEGY.md](TESTING_STRATEGY.md) §3.
3. `lib/pages/<domain>/*.dart` — one file per screen; `AppAsyncBuilder<T>` for
   one-shot loads.
4. `lib/routes/router.dart` — real `GoRoute` replacing any `comingSoon(...)`
   stub; add a role-prefix entry if the screen should be role-restricted.
5. A migration adding the table, its RLS policies (reusing the helpers in
   §3.1), and — if the operation needs atomicity under concurrency — an RPC
   per §3.4's pattern.

---

## 7. Known architectural placeholders (disclosed, not hidden)

| Area | Current state |
|---|---|
| Payment gateway | `MockPaymentProcessor` always succeeds after a simulated delay; `payment-webhook-handler` exists for when a real gateway is commissioned |
| Admin system monitoring | Training completion %, pending-review count, and recent activity are now genuinely computed from real data (`AdminRepository.fetchDashboardStats()`); only System Uptime remains a placeholder, and is now honestly labeled "Not live-monitored" in the UI rather than presented as real telemetry — true uptime/latency/error-rate needs an external APM/monitoring service this app doesn't have |
| Crash/error telemetry | Wired (`sentry_flutter`), opt-in via `Env.sentryDsn`/`SENTRY_DSN` — disabled by default until a real DSN is supplied; see [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §6 |
| Government scheme eligibility | Real structured rules engine (`EligibilityCriteria`/`evaluateSchemeEligibility()` in `lib/models/scheme.dart`) over SHG membership/age/grade — the only structured facts this app's data model actually carries; still not a connection to any government eligibility API (none exists), and criteria needing income/gender/caste/occupation data remain manual-verification-only via each scheme's free-text list |
| Training course quiz | Real per-course questions (`quiz_questions` table, migration `0041`) replacing the old single generic 3-question set; seeded with a genuine starting question set per demo course, not a transcription of any real curriculum — a subject-matter expert should review/extend it |
