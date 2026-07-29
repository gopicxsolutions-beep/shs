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

33 base Postgres tables + 3 views (`shg_directory`, `shg_own_masked`,
`quiz_questions_public`), defined starting in
`supabase/migrations/0001_init_schema.sql` and hardened across 55 further
migrations:

| Table | Domain |
|---|---|
| `shgs` | SHG (group) master record — general profile fields only; base table read directly only by admin/staff (`fetchAllShgs()`) |
| `shg_bank_details` (migration `0056`) | `bank_account`/`ifsc`, split out of `shgs` into their own 1:1 table so RLS can restrict them to that SHG's leader/staff — a plain member's role has no policy granting it access to this table at all, direct or otherwise |
| `shg_directory` (view) | Safe public subset of `shgs` for onboarding search — excludes bank fields entirely |
| `shg_own_masked` (view, migrations `0045`/`0056`) | What an ordinary member's/leader's own-SHG lookup (`fetchShg()`) actually reads — same row scope as `shgs`' own RLS, left-joined to `shg_bank_details`, with `bank_account`/`ifsc` additionally nulled server-side unless the caller is leader/staff for that SHG |
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
| `training_courses`, `course_progress`, `quiz_questions` | E-learning catalog (`training_courses.video_url`, migration `0115`, points into the public `training-videos` storage bucket for real in-app playback) + per-member progress/certification + real per-course quiz content (migration `0041`) — see §7 |
| `quiz_questions_public` (view, migration `0051`) | What `TrainingRepository.fetchQuizQuestions()` actually reads — same rows as the base table, `correct_index` excluded entirely; direct base-table `SELECT` is revoked from `authenticated` so a client can't request the answer key by asking a raw REST call for a column its own query omits |
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
| `current_role()` | Caller's `profiles.role` — null if the caller's account is deactivated |
| `current_shg_id()` | Caller's `profiles.shg_id` — null if deactivated |
| `is_staff()` | `role in ('crp','clf','admin')` — false if deactivated |
| `is_leader_or_staff()` | `role in ('leader','crp','clf','admin')` — false if deactivated |
| `profile_shg_id(uuid)` | Another profile's `shg_id` (for staff/leader cross-member checks) — NOT gated by that profile's own `is_active`, since it's answering a question about a referenced member, not resolving the caller's own authorization |

**Account deactivation (migration 0083, `profiles.is_active`/`deactivated_at`,
admin-only writable):** the 4 caller-identity functions above all now
additionally check `is_active`, so deactivating an account transitively
blocks every RLS policy branch keyed on role or SHG membership — not a
separate flag each policy has to remember to check. A handful of policies
also have a bare `member_id = auth.uid()`/`created_by = auth.uid()` branch
(e.g. a member reading their own `savings_entries` row) that this does
**not** close — those branches don't route through any of the 4 functions
above, so a deactivated member's own client is relied on (via
`AppState.accountDeactivated` forcing a sign-out) as the practical
mitigation for that specific gap, not the RLS layer alone.

**Last-admin guard (migrations 0084/0085, `guard_last_admin_deactivation`/
`guard_last_admin_delete`):** since deactivation collapses `current_role()`
to null, three distinct actions all have the identical "nobody can ever
resolve `current_role() = 'admin'` again" effect if performed on the
platform's only remaining active admin — deactivating them, changing their
`role` away from `'admin'`, or deleting their `profiles` row outright (the
last one irreversible). All three are blocked: a `BEFORE UPDATE` trigger
covers the first two (0084, broadened by 0085 to also catch a role change,
not just `is_active`), and a `BEFORE DELETE` trigger covers the third
(0085). Each raises a specific exception rather than silently no-opping,
leaving every other case — including an admin deactivating/demoting
themselves, as long as another active admin still exists — unaffected.

**Why these exist and must be reused, not reinlined**: a policy on table `T`
that subqueries `T` itself to check the caller's own row re-triggers the same
policy, causing Postgres error `42P17` (infinite recursion). This happened in
production on `marketplace_orders_update_seller_or_staff` and again on the
equivalent `loans` policy — both fixed by moving the self-referencing read into
one of these `security definer` helpers, whose own internal query bypasses RLS
on its way to answering the question. New policies needing "is this the
caller's own row in this table" must use or extend these helpers, never
inline an equivalent subquery.

**Grant hygiene — `revoke ... from public` is not enough**: this project's
`public` schema grants EXECUTE on every newly created function to
`anon`/`authenticated`/`service_role` via a default-privilege rule, independent
of the `PUBLIC` pseudo-role. Every new `security definer` function must
explicitly `revoke execute on function ... from anon;` (not just `from
public`) before granting to `authenticated` — omitting this leaves the
function callable by a fully unauthenticated caller. Confirmed live via
`pg_proc.proacl` twice: migration `0055` diagnosed and fixed it for two
functions; migrations `0093`/`0094` (round 188) repeated the same mistake for
two new functions — one of which, `support_messages_recent_count()`, had no
internal ownership check at all and was a genuine, live, unauthenticated
metadata-disclosure bug until fixed in `0095`. A full project-wide sweep
(`0096`/`0097`, round 189) confirmed and closed 27 more instances of the same
grant gap; every one of those 27 turned out to already be internally gated on
`auth.uid()`-derived checks, so none were independently exploitable — but the
grant itself should still never be left open, since a function's internal
logic is a much easier thing to get wrong later than a `revoke` statement is
to get right up front.

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
  her own. The identical shape protects `profiles.role` (§3.3) and — since
  round 96 — `marketplace_reviews`: a seller could self-place an order
  against her own listing (nothing cross-checks buyer/seller on
  `marketplace_orders`) and then use that order to satisfy the "real
  purchase" requirement on her own review, inflating her product's rating.
  Live-verified exploitable before the fix (self-product, self-order, self-
  review all succeeded end-to-end as one test account). Fixed in migration
  `0048` by adding `not exists (select 1 from marketplace_products p where
  p.id = marketplace_reviews.product_id and p.seller_id = auth.uid())` to
  the identified-reviewer branch of `marketplace_reviews_insert_authenticated`.
  - **Round 97 correction**: `scheme_applications_update_staff` had *no*
    self-exclusion at all until this round — just `is_staff()`, unlike every
    other decision-workflow table's policy. A staff account (crp/clf/admin)
    who is also a real SHG member could apply for a scheme, then approve or
    reject her own application from the same platform-wide review queue —
    and, unlike the loans/meetings gaps below, this one wasn't merely a
    confusing UI in front of an RLS block: the write would have genuinely
    succeeded. Fixed by adding `member_id <> auth.uid()` to both `using` and
    `with check` (migration `0049`), plus filtering the reviewer's own
    application out of `scheme_applications_review_page.dart`'s queue,
    mirroring the loans/meetings client-side fixes. That round's fix did
    **not** reach `AdminRepository.fetchDashboardStats()`'s separate
    "N scheme applications pending review" banner count on the Admin
    Dashboard — a distinct code path reading the same underlying pending
    set with no self-exclusion of its own, so the banner could show one
    more than the review queue it links to actually let that same staff
    account act on. Closed in round 101 by passing the viewer's own id into
    that method and applying the identical `!= viewerId` filter there too.
    Full live behavioral verification (self rejected, other-party allowed)
    wasn't possible this round — the live project has exactly one real
    profile, role `leader`, and creating a crp/clf/admin test profile to
    exercise `is_staff()` would cross into the same class of action already
    blocked earlier this session (assigning a profile a staff role). Verified
    instead by reading the deployed policy expression directly before and
    after the fix via `pg_get_expr(polwithcheck, polrelid)`.
  - The RLS block alone isn't sufficient UX — the client must mirror it, or
    the user hits a confusing generic failure for an action that could never
    succeed. This was missed for two of the three loan screens until round
    92's live testing: a leader who applies for her own loan (a legitimate
    thing to do — she's still a real SHG member) saw her own pending loan
    sitting in `loan_approval_page.dart`'s actionable list, and
    `loan_detail_page.dart`'s "Record Payment" button for her own active
    loan, both silently guaranteed to fail. Fixed by filtering
    `loan.memberId != <viewer's own profile id>` in both places (and in the
    "Pending Approval" badge count on `loans_home_page.dart`, so the count
    stays consistent with what the list shows) — the same precedent
    `loans_home_page.dart` already set by hiding "Apply" from leader/staff to
    avoid an equivalent confusing affordance.
- **Column-lock independent of row-access**: "can write this row" and "can
  write this column to this value" are enforced separately. A seller updating
  a marketplace order's `status` must not, in the same `WITH CHECK`, be able to
  rewrite its `amount`/`buyer_id`; a leader verifying a savings entry must not
  be able to rewrite its `amount`/`member_id` in the same statement. This class
  of gap (column-lock completeness) was audited explicitly across every
  writable table in dedicated rounds — see
  [TESTING_STRATEGY.md](TESTING_STRATEGY.md) §3.
- **Assignee columns scoped to the caller's own SHG**: whenever a leader
  writes a *different* member's id into a row (savings/attendance/livelihood
  member assignment, a meeting action item's `owner_id`), the `WITH CHECK`
  must verify `profile_shg_id(<that id>) = <this row's shg_id>`, not just that
  the caller herself is a leader of that SHG — otherwise she could point the
  column at a profile in a completely different SHG. `meeting_action_items`
  carried exactly this gap, explicitly disclosed and left open across three
  rounds (0015/0024/0026) on the reasoning that the app never actually
  populated `owner_id` — that premise silently went stale once
  `meeting_mom_page.dart` grew a real "Assign to" picker, and was only
  caught by re-checking a disclosed gap's justification against current code
  rather than trusting it indefinitely. Fixed in migration `0047`.
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
  exact bullet's own stated principle. Migration `0045` first closed the
  app's own read path with `shg_own_masked` (above): the same row-visibility
  rule as the base table, but `bank_account`/`ifsc` were nulled server-side
  via a `CASE is_leader_or_staff()` unless the caller actually is
  leader/staff for that SHG, and `ShgRepository.fetchShg()` switched to read
  from this view instead of the base table.
  That masking view only protects callers who choose to query it, though —
  RLS on the base `shgs` table itself was untouched, so a plain member's own
  already-valid session could still reach the real values by querying
  `/rest/v1/shgs?select=bank_account,ifsc` directly instead of the masked
  view, no special access needed. Live-confirmed this gap directly (round
  122, genuine plain-member RLS simulation, not just code review) and closed
  it completely with migration `0056`: `bank_account`/`ifsc` moved out of
  `shgs` entirely into their own `shg_bank_details` table (1:1 on `shg_id`),
  whose *only* SELECT policy is leader-or-staff-of-that-SHG — a plain
  member's role has no path to those columns from any query shape now,
  direct-table or otherwise, since they simply don't exist anywhere a wider
  policy could reach them. `shg_own_masked` was updated in the same
  migration to left-join `shg_bank_details` and keep the same `CASE`-masked
  shape its callers already depend on, so `ShgRepository.fetchShg()` needed
  no Dart-side change. `shg_directory` (the older, narrower "public search"
  view) remains unchanged and still excludes the bank fields entirely rather
  than masking them.

### 3.3 Role-escalation prevention (the single most re-audited security property)

Defense in depth across three layers, only the last of which is the real
boundary:

1. **Client UX**: `RoleSelectPage` no longer offers a live-mode Member/Leader
   choice at all (the router redirects any live-mode visit to it away — see
   §7 below) — every signup starts as `member`, and becoming `leader` only
   ever happens via `ShgJoinRequestsPage`'s approve-as-leader option, itself
   only rendered for a staff viewer. Each admin page's write affordances are
   likewise hidden behind an `isAdmin`/`isStaff` check.
2. **Fail-fast client guard**: `AppState.setRole()` throws immediately if asked
   to set a staff role in live mode — a backstop against a future UI
   regression, not the boundary itself (and, with Role Select no longer
   reachable in live mode, this method itself is now unreachable there too —
   kept only for demo mode's role-preview switcher).
3. **Database** (the actual boundary):
   - `profiles_insert_self`: `WITH CHECK (id = auth.uid() AND role IN
     ('member','leader') AND shg_id IS NULL)` — closes the INSERT-side path
     where a brand-new signup could `POST` a profile already carrying
     `role:'admin'`.
   - `profiles_update_self_or_admin`: a non-admin self-update may only move
     `role` between `member`/`leader`, and only while `shg_id` stays `NULL` —
     i.e. only during onboarding, before any real SHG linkage exists. Once
     `shg_id` is non-null, `role` is frozen for self-service; only
     `current_role() = 'admin'` unlocks further changes. This remains a real,
     independent guard against a raw REST `PATCH` even though the client no
     longer offers a Leader self-selection UI at all.
   - `approve_shg_join_request()` (migration `0116`) — the RPC that links a
     member to an SHG, and the *only* path by which any account ever becomes
     `'leader'`. Takes an explicit `p_as_leader` param from the approver; the
     resulting `role` is derived **solely** from that parameter, never from
     whatever value happens to already be sitting in `profiles.role` (unlike
     the earlier version of this RPC, which reactively reset a self-declared
     `'leader'` back to `'member'` on approval). This is a strict
     improvement, not just a rename: it structurally can't be defeated by a
     pre-set `role` value on the row (e.g. via the `profiles_update_self_or_
     admin` path above), because the RPC never reads that column when
     deciding the outcome. `p_as_leader = true` additionally requires
     `is_staff()` — a peer leader approving her own SHG's queue can only
     grant `member`, never mint a co-leader.

This sequence (client fix → still-exploitable-via-REST → DB fix → adversarial
re-audit finds a second path → second DB fix) is the project's own history,
not a hypothetical — see [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §2 for
the full incident list.

### 3.4 Atomic RPCs — where a plain `UPDATE` isn't safe under concurrency

Five operations mutate money, stock, or a decision outcome in a way that a
naive client-side read-then-write race could corrupt. Each is a Postgres
function the repository calls via `supabase.rpc(...)`. Four of the five have
a documented, explicitly-labeled-as-a-compatibility-shim non-atomic fallback
for the case where the migration defining them hasn't been deployed
(`PGRST202`) — `place_marketplace_order` (below) deliberately does not, see
its own row.

| RPC | Locking | Guarantees | Errors raised |
|---|---|---|---|
| `record_loan_payment(loan_id, amount)` | `SELECT ... FOR UPDATE` row lock on `loans` | Payment + balance decrement + close-on-zero happen atomically; rejects overpayment; explicit internal SHG/staff-scope + self-exclusion check (see below) | `payment amount must be positive`; `loan not found`; `cannot record a payment on your own loan`; `not authorized to record a payment on this loan`; `payment amount (%) exceeds outstanding balance (%)` |
| `add_financial_ledger_entry(shg_id, entry_type, ...)` | Transaction-scoped `pg_advisory_xact_lock` keyed on `(shg_id, entry_type)` | Running-balance read + insert happen atomically per ledger key, even for the very first entry of a key (no row yet to lock) | Table CHECK constraints catch invalid inputs |
| `place_marketplace_order(product_id)` (migration `0057`, replaced `decrement_product_stock`) | Single atomic `UPDATE ... WHERE stock > 0` | Stock check-and-decrement AND the `marketplace_orders` INSERT happen in one `security definer` transaction — not just the stock/price part. `decrement_product_stock` (0008) only verified price and handed it back for the client to insert with in a *separate* round trip; nothing forced a client to actually do that honestly. A direct REST insert could set `amount` to anything with stock never touched (live-confirmed round 125: a real ₹5,000 test product ordered at `amount: 1`), and the old RPC was independently callable with no order at all — any authenticated user could silently zero out any seller's stock as a pure DoS, live-confirmed the same round. `buyer_id`/`buyer_name` are derived from `auth.uid()`/`profiles.name` inside the function, never accepted as parameters | Returns `success:false` rather than raising, for the ordinary "already sold out" case |
| `approve_loan` / `reject_loan` | `SELECT ... FOR UPDATE` row lock on `loans` | Rejects a second decision on an already-decided loan; explicit internal SHG/staff-scope + self-exclusion check; `approve_loan` additionally requires the borrower still be `is_active` | `loan not found`; `loan is no longer pending (current status: %)`; `cannot approve/reject your own loan`; `not authorized to approve/reject this loan`; `cannot approve a loan for a deactivated member` (`approve_loan` only) — surfaced to the UI as `LoanAlreadyDecidedException` ("already decided by someone else") for the status case |
| `decide_scheme_application(id, approve)` | `SELECT ... FOR UPDATE` row lock on `scheme_applications` | Same already-decided race guard, for a shared, non-SHG-scoped staff review queue | `application not found`; `application already decided (current status: %)`; `not authorized to decide this application, or application not found` |

`add_financial_ledger_entry` and `decide_scheme_application` are `security
invoker` — each RPC's own internal write is still subject to the underlying
table's RLS, so the function provides atomicity, not a privilege bypass.

`record_loan_payment`/`approve_loan`/`reject_loan` were `security invoker`
too until round 185's finding that this left a critical gap: since RLS was
the only authorization boundary these RPCs' writes went through, and
`loans_update_leader_or_staff` (round ~59) never actually locked any of the
state-machine columns (`status`/`outstanding`/`emi`/`disbursed_on`/
`next_due_date`/`decided_by`/`decided_at`) or applied self-exclusion to the
`is_staff()` branch, a direct `PATCH /rest/v1/loans` was exactly as capable
as these RPCs, with none of their checks — including any crp/clf/admin
account self-approving her own loan outright. Migration `0088` converted
all three to `security definer` with their own explicit internal
authorization checks (mirroring the RLS scope they used to rely on, plus
universal self-exclusion), and correspondingly locked down
`loans_update_leader_or_staff` so a direct update can now only ever be a
true no-op — every legitimate state-machine transition must go through
these RPCs.

`place_marketplace_order` is the original, longest-standing example of the
same principle — it must be `security definer`, because an ordinary buyer
has no RLS grant to update a product she doesn't sell
(`marketplace_products_update_seller_or_staff` is seller-or-staff-only) and
the whole point of the function is to cross that boundary safely for
exactly one narrow, self-contained operation. Precisely *because* it's a
privilege bypass, it derives every identity-bearing value (`buyer_id`,
`buyer_name`) from the session itself rather than trusting a
parameter, and performs the entire purchase — not just the part that needed
elevated privilege — inside the one function, so there's no gap afterward
for an uncooperative client to exploit.

---

## 4. Backend services

- **Supabase Postgres** — schema + RLS, per above.
- **Supabase Auth** — phone/OTP. `lib/services/auth_service.dart` wraps
  `signInWithOtp`/`verifyOTP`. OTP generation/storage/verification stay
  entirely inside Supabase Auth; only the "deliver this code by SMS" step is
  swappable, via Supabase's Send SMS Auth Hook
  (`supabase/functions/send-sms-hook`) — currently wired to relay through
  Fast2SMS instead of Supabase's built-in Twilio provider. Swapping the
  hook's downstream gateway again later is a server-side-only change; the
  client-side call shape never changes. See the function's own header
  comment for activation steps (secrets + dashboard hook config) and round
  172 in `docs/DEVELOPMENT_PROGRESS.md` for why.
- **Supabase Realtime** — used narrowly, only where collaborative live updates
  genuinely matter (the savings ledger, so a second leader's verification
  appears without a manual refresh; `loans` is wired the same way in the
  repository layer, not yet consumed by any page). Every other list is a
  one-shot `AppAsyncBuilder<T>` load — an open realtime channel has an
  ongoing cost and isn't justified for screens nobody else is editing
  concurrently.
  - **A table must be explicitly added to the `supabase_realtime` Postgres
    publication before `.stream()` can work at all** — independent of RLS,
    independent of the client code being correct. This is a genuine,
    previously-undiscovered production gap found during live end-to-end
    testing of the Savings module: `savings_entries` was never added to
    that publication by any migration, so `SavingsLedgerPage` (the leader's
    verification screen) hit a generic error on every single live-mode
    visit, for as long as the feature existed — invisible to demo mode
    (which never opens a real channel) and to `flutter analyze`/
    `flutter test` (no automated test exercises a real Realtime
    connection). Fixed in migration `0046` (`alter publication
    supabase_realtime add table ...`) for both `savings_entries` and
    `loans`. Adding a table to the publication does **not** bypass RLS —
    Supabase Realtime evaluates every change event against the subscribing
    client's own role and that table's existing policies before delivering
    it, the same boundary the REST API already enforces. Any future
    `.stream()` call on a new table needs the identical migration step, or
    it will fail exactly the same way.
- **Edge Functions** (Deno/TypeScript, `supabase/functions/`):
  - `ai-advisor-proxy` — see [AI_MODULES.md](AI_MODULES.md).
  - `generate-report-snapshots` — pg_cron-triggered nightly report
    precomputation, secured with a caller-supplied `x-cron-secret` header
    checked against a `CRON_SECRET` value (the secret itself is an app-owner
    deployment step, not something committed to the repo — see
    [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §5).
  - `payment-webhook-handler` — inbound payment-gateway webhook handling;
    the real gateway itself is not wired (§7).
  - `system-health-check` — real infra metrics (uptime/latency/error rate)
    for the Admin Monitoring page: runs a genuine synthetic database
    round-trip check, both pg_cron-scheduled (every 5 minutes) and on-demand
    whenever an admin opens that page, logging each result to
    `public.infra_health_checks` and returning rolling 24h aggregates. Two
    valid callers, both authenticated inside the function itself (not at
    the platform gateway, since the cron caller has no user JWT at all):
    the same shared `x-cron-secret` header/`CRON_SECRET` value
    `generate-report-snapshots` already uses, OR a real staff (crp/clf/
    admin) session JWT, verified via `auth.getUser()` since `verify_jwt` is
    disabled at the platform level for this function.

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
| Training course quiz | Real per-course questions (`quiz_questions` table, migration `0041`) replacing the old single generic 3-question set; seeded with a genuine starting question set per demo course, not a transcription of any real curriculum — a subject-matter expert should review/extend it. Grading is now genuinely enforced server-side (migration `0051`, round 98) — previously the pass threshold was real in name only: `correct_index` shipped to the client before the quiz was answered, and certification trusted an unverified client claim with no score ever sent to the server. `submit_quiz_attempt` (`security definer`) now grades from the base table's real answer key, which the client never sees (`quiz_questions_public` view), and `course_progress`'s `certified`/`completed_on` columns are locked so only that RPC (or staff) can set them. |
| Reports/Analytics server-side precomputation | `report_snapshots` and `analytics_kpis` both exist with staff-write RLS specifically so an Edge Function could eventually precompute and cache this data, but `ReportRepository`/`TrendRepository`/`AnalyticsRepository` all compute every report/chart/KPI client-side from live tables at read time instead — the client never reads either table. The two tables aren't in the same state as each other: `report_snapshots` has a real, deployed, nightly `pg_cron`-triggered writer (`generate-report-snapshots`, §4), just one the client doesn't consume yet; `analytics_kpis` has no writer at all anywhere in `supabase/functions/` — its RLS policy (staff-write, self-or-staff-read) is provisioned for a function that was never built, making it an orphaned table rather than a populated-but-unused one. |
