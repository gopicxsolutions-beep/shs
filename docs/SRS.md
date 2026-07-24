# Software Requirements Specification
## SHG Saathi (NavaSakhi) — AI-Enabled Digital Platform for Self-Help Groups and Women-Led Microenterprises

Version 2.0 · 2026-07-22
Status: living document — update when a module's scope or role-access rules change.

This is one document in a production documentation suite. Read alongside:
- [MANIFESTO.md](MANIFESTO.md) — why the app is built this way, the quality bar
- [ARCHITECTURE.md](ARCHITECTURE.md) — technical layering, data model, RLS/security design, atomic RPCs
- [AI_MODULES.md](AI_MODULES.md) — full technical detail on the AI advisors and Voice Assistant
- [TESTING_STRATEGY.md](TESTING_STRATEGY.md) — how correctness is actually verified, and the bug classes that discipline exists to catch
- [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) — quality gates, security-audit history, production-readiness checklist
- [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md) — the running dev log; the authoritative current-state source when this document goes stale
- [CLAUDE.md](../CLAUDE.md) — the working rules an AI agent (or a new engineer) should follow session to session

Each module section below covers **how it actually works** — the real screens,
fields, validation, status lifecycles, and role enforcement as implemented —
not just a checklist of intended requirements. Where a feature is an
intentional placeholder, that is stated explicitly, not glossed over.

---

## 1. Introduction

### 1.1 Purpose

This SRS defines the functional and non-functional requirements for SHG
Saathi, a cross-platform (Android/iOS/Web) Flutter application that digitizes
the operations of Self-Help Groups (SHGs) — savings, credit, meetings,
livelihoods, and welfare-scheme access — for rural women's collectives in
India, and gives the federation hierarchy above them (CRPs, CLFs, Admins)
monitoring and analytics tools.

### 1.2 Scope

In scope: member/group financial tracking (savings, loans, ledger), governance
(meetings, attendance, minutes), livelihoods and marketplace commerce,
government scheme discovery/tracking, training/e-learning, digital payments,
announcements, support/helpdesk, AI-assisted advisory (financial/scheme/market/
voice), and multi-level analytics/reporting up to federation level — all gated
by a 5-role permission model and backed by Supabase (Postgres + Auth + RLS +
Edge Functions).

**Explicitly out of scope / not yet real** (see each module section and
[ARCHITECTURE.md](ARCHITECTURE.md) §7 for the full list): real bank/UPI
settlement, real government scheme e-filing, and real infrastructure
monitoring. Each of these has a working UI/workflow with a mocked or
metadata-only backend, architected so the real integration is a bounded,
one-file swap when commissioned. Speech-to-text/text-to-speech and file/
document upload were in this same category but are now real — on-device STT/
TTS (no vendor key needed) and Supabase Storage-backed uploads respectively.

### 1.3 Definitions and Acronyms

| Term | Meaning |
|---|---|
| SHG | Self-Help Group — a member-run village savings/credit group, the app's core unit |
| CRP | Community Resource Person — monitors and trains a set of SHGs |
| CLF | Cluster Level Federation — oversees SHGs at village/cluster level |
| RLS | Row-Level Security (Postgres) — the primary authorization mechanism |
| MoM | Minutes of Meeting |
| EMI | Equated Monthly Installment (loan repayment) |
| RPC | Remote Procedure Call — a Postgres function invoked via Supabase for atomic operations |
| Demo/offline mode | App runs against local mock data with no Supabase backend configured |
| Live mode | App runs against the real Supabase project with real Auth + RLS |

### 1.4 References

- [README.md](../README.md) — quick project overview and stack
- [docs/DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md) — authoritative running
  dev log: every bug found and fixed, dated round by round
- `supabase/migrations/*.sql` — the executable source of truth for schema and RLS

---

## 2. Overall Description

### 2.1 Product Perspective

Standalone mobile-first Flutter app, Supabase backend (Postgres, Auth,
Storage, Edge Functions, pg_cron). Runs fully functional in **demo/offline
mode** with zero backend configuration, and switches transparently to **live
mode** when `SupabaseService.isConfigured` — identical UI, identical routes,
only the data source and write-durability differ. See
[ARCHITECTURE.md](ARCHITECTURE.md) §1 for the technical mechanism.

### 2.2 User Classes and Characteristics

| Role | Who | Primary goals in the app |
|---|---|---|
| **Member** | Rural woman, SHG member, may have low digital literacy | Track own savings/loans, mark attendance, apply for loans/schemes, get AI financial guidance |
| **Leader** | SHG president/office-bearer, elected by members | Everything a member can do for herself, plus: approve loans, manage the ledger, run meetings, approve join requests, view group-level reports |
| **CRP** | Field staff supporting several SHGs | Monitor SHG health scores, deliver training |
| **CLF** | Cluster/village-level federation officer | Village-wide financial oversight, cross-SHG analytics, federation reporting |
| **Admin** | Platform operator | User/role management, SHG record management, scheme catalog management, system-wide monitoring |

**Self-service role selection is intentionally asymmetric**: in live mode, a
new user can only self-select `member` or `leader` at Role Select — the app
renders only those two as tappable options. Staff roles (`crp`/`clf`/`admin`)
are assignable only by an existing Admin, from the Admin Users screen. This is
enforced independently at the database layer (`profiles_insert_self`/
`profiles_update_self_or_admin`), not just by hiding the option — see
[ARCHITECTURE.md](ARCHITECTURE.md) §3.3 for the exact mechanism and its
incident history. All 5 roles remain selectable in demo mode only, so every
dashboard stays explorable without a backend.

### 2.3 Operating Environment

- Client: Flutter (Android, iOS, Web), Material-based design system
- Backend: Supabase (hosted Postgres + Auth + Storage + Edge Functions +
  pg_cron)
- AI: Groq OpenAI-compatible chat-completions API (`llama-3.3-70b-versatile`),
  proxied through the `ai-advisor-proxy` Edge Function — see
  [AI_MODULES.md](AI_MODULES.md)
- Languages: English, Hindi, Telugu (app chrome + AI Voice Assistant)

### 2.4 Design and Implementation Constraints

- **Dual-mode requirement** for every data-backed feature (demo + live) — not
  optional polish, the app's core testability and demo strategy.
- **Repository pattern** — all Supabase access goes through
  `lib/repositories/*`, never directly from a page/widget.
- **RLS is the authorization boundary**, not client-side role checks — a
  malicious client can call the REST API directly, bypassing the Flutter UI
  entirely. See [ARCHITECTURE.md](ARCHITECTURE.md) §3.
- **Navigation**: `context.go()` only, never `push()`/`pop()`.

### 2.5 Assumptions and Dependencies

- Members have access to a smartphone with SMS-based OTP delivery for login.
- Bank/UPI settlement, government scheme e-filing, and infra monitoring are
  represented as workflows/placeholders, not real third-party integrations
  (§1.2).

---

## 3. System Features — how each module actually works

Feature IDs are `FR-<MODULE>-<n>` for traceability. "Roles" lists who can
perform the action at the UI layer; the accompanying narrative states, where
it matters, whether that boundary is also independently enforced by RLS.

### 3.1 Authentication & Onboarding (`auth/`)

**How it works.** Login takes a single 10-digit mobile number, validated
client-side against `^[6-9]\d{9}$` (Indian mobile numbers only — deliberately
rejects numbers that could never receive an SMS, rather than accepting any
10-digit string). Submitting sends an OTP via Supabase Auth
(`signInWithOtp`) in live mode, or skips straight through in demo mode. The
OTP screen presents 6 individual digit boxes with auto-advancing focus and
paste-distribution support (pasting a 6-digit code fills all boxes and moves
focus to the end), plus a 30-second resend cooldown. On verification, the app
loads (or discovers the absence of) a `profiles` row and routes onward.

Profile Setup collects Name (required), Village/Mandal/District (free text),
and an *optional* SHG search-and-pick (debounced, searches a safe public
`shg_directory` view — never the base `shgs` table's sensitive columns).
Picking an SHG does not directly link the profile to it — it files a
`shg_join_request` that the target SHG's leader must approve. In live mode,
`role` is always initialized to `'member'` regardless of any later Role
Select choice; SHG linkage stays `null` until approval.

Role Select is only reachable once, right after profile creation, and (in
live mode) shows only Member and Leader as choices — a member who newly
selected an SHG then lands on **SHG Approval Pending**, which polls her own
join-request status and offers "Choose a different SHG" if it's rejected. A
router-level redirect chain (`lib/routes/router.dart`) enforces this entire
sequence — no-session → profile setup → role select → SHG approval — on every
navigation, so a partially-onboarded user can't reach the dashboard by typing
a URL directly.

A distinct **Profile Load Error** screen (vs. a plain "no profile yet") exists
specifically so a returning, already-onboarded user who opens the app offline
isn't misrouted into onboarding — the router distinguishes "no profile because
none exists" from "no profile because the fetch failed for a network reason."

**Role-escalation prevention** is the most heavily audited property of this
module — see [ARCHITECTURE.md](ARCHITECTURE.md) §3.3 for the full client +
database defense-in-depth chain and its incident history.

| ID | Requirement | Roles |
|---|---|---|
| FR-AUTH-1 | Phone + OTP authentication, Indian mobile number format validated client-side | All |
| FR-AUTH-2 | Profile setup: name (required), village/mandal/district, optional SHG search-and-request-to-join | All |
| FR-AUTH-3 | Role Select limited to Member/Leader in live mode; all 5 roles explorable in demo mode | All |
| FR-AUTH-4 | A member's `shg_id` stays null and an approval-pending screen shows until the target SHG's leader decides the join request | Member |
| FR-AUTH-5 | Staff roles (CRP/CLF/Admin) are assignable only by an Admin via the Admin Users screen, never self-assigned, enforced at the RLS layer independent of the UI | Admin |
| FR-AUTH-6 | A network-caused profile-load failure shows a distinct, recoverable error screen rather than misrouting into onboarding | All |
| FR-AUTH-7 | A genuine deep link captured before login is replayed after successful OTP verification, once onboarding is fully complete | All |

### 3.2 Dashboards (`dashboard/`)

**How it works.** One shared top bar (role pill, greeting, SHG name if
linked, an unread-announcements bell fetched once per page load) sits above a
role-specific body, selected purely by the signed-in user's `role` — there is
no separate gate on the dashboard switch itself, since the role value is what
Role Select/RLS already control.

- **Member**: loads savings/loan/meeting/training/scheme/announcement data in
  parallel; surfaces the active loan (if any), the *soonest* upcoming meeting
  (explicitly re-sorted ascending and filtered to not-yet-passed, since the
  underlying query returns newest-scheduled-first), an in-progress course, a
  savings trend chart, and up to 3 recent announcements.
- **Leader**: group savings/loans-outstanding stats, a red defaulter-alert
  banner if any loan is overdue, a pending-loan-approvals preview, next
  meeting, and an "SHG Health" row (grade, attendance %, a recovery-rate
  figure computed as `1 − overdue/active loan count`).
- **CRP**: SHGs-monitored count, an average health score explicitly labeled
  as an attendance-based proxy (not a validated composite metric), and a
  capped preview list of monitored SHGs (the full list lives one tap away in
  a properly lazy-loaded list, since a CRP can realistically monitor 30+
  SHGs and this dashboard renders eagerly).
- **CLF**: village-wide KPIs, a village-wise SHG bar chart, and
  financial-oversight mini-cards (loans disbursed, recovery rate).
- **Admin**: real total-SHG/active-member counts, plus a genuinely computed
  training-completion percentage (from real course-progress rows), a real
  pending-review count (from scheme applications actually awaiting review —
  the same queue Manage Schemes/Applications acts on, hidden entirely at
  zero rather than shown as "0 pending"), and a recent-activity feed
  assembled from real, recently-created profile/SHG/document rows across the
  platform — replacing the old hardcoded numbers and static 3-row feed that
  had no backing query at all. **Only the system-uptime figure remains a
  placeholder** (true uptime/latency/error-rate needs a real external
  infrastructure-monitoring service this app doesn't have), and it is now
  honestly labeled "Not live-monitored" in the UI rather than implying it's
  real telemetry.

| ID | Requirement | Roles |
|---|---|---|
| FR-DASH-1 | Member dashboard: savings/loan summary, attendance, upcoming meeting, training, AI advisor shortcut, announcements | Member |
| FR-DASH-2 | Leader dashboard: group financials, defaulter alert, pending approvals, SHG health | Leader |
| FR-DASH-3 | CRP dashboard: monitored-SHG list with health/grade, training catalog preview | CRP |
| FR-DASH-4 | CLF dashboard: village-wide KPIs and financial oversight | CLF |
| FR-DASH-5 | Admin dashboard: platform KPIs and quick links; training-completion/pending-review/recent-activity are now genuinely computed; only system uptime remains a disclosed placeholder | Admin |

### 3.3 Savings (`savings/`)

**How it works.** A member (or a leader/staff picking from the SHG roster)
enters an amount (validated `> 0` and capped at ₹1,000,000 as a fat-finger
guard), a mode (Cash/UPI/Bank Transfer), and a frequency (Weekly/Monthly/
Daily). **Every new entry starts `pending`, regardless of who submits it** —
even a leader-recorded deposit is not auto-verified. The SHG's savings ledger
is a **realtime** view (the one screen in this module using a live Supabase
subscription rather than a one-shot load) so a second leader's verification
appears without a manual refresh; verification is a flat, idempotent
status flip to `verified` with no other column touched, and is disabled
outright in demo mode since there's nothing to persist against.

Totals shown anywhere in the app (dashboards, group reports, statements) only
ever sum `verified` entries — a pending deposit never inflates a displayed
total. The statement view computes a running passbook-style balance by
folding verified entries forward chronologically.

**Enforcement**: any SHG member can read every other member's savings
entries (deliberate transparency, not a bug). Writing is scoped to
self-or-leader-for-a-verified-member-of-her-own-SHG-or-staff, and every
non-staff insert is forced to start `pending`/dated today. Updates are
leader/staff-only, with every column except `status` frozen — a leader
"verifying" a deposit cannot simultaneously alter its amount. Deletion is
staff-only. A leader verifying her *own* submitted deposit is deliberately
still permitted (judged lower-stakes than loan self-approval, since it moves
no money out of the SHG).

| ID | Requirement | Roles |
|---|---|---|
| FR-SAV-1 | Member (or leader/staff for a roster member) records a savings entry, always starting `pending` | Member, Leader, staff |
| FR-SAV-2 | Member views own savings history and a running-balance statement (verified entries only) | Member |
| FR-SAV-3 | SHG members share realtime read access to the group's savings ledger | Member, Leader |
| FR-SAV-4 | Leader/staff verify a pending entry (flat status flip; self-verification permitted) | Leader, staff |
| FR-SAV-5 | Leader/staff view a group savings report: per-member leaderboard and monthly trend, verified entries only | Leader, CRP, CLF, Admin |

### 3.4 Loans (`loans/`)

**How it works.** A member applies with a purpose, an amount (`>0`, capped at
₹1,000,000), and a tenure (6/12/18/24 months, chosen via chips). The
application is inserted `pending`, with `outstanding` initialized equal to
the full requested amount and `emi` at 0 — there is no interest-rate field or
amortization schedule anywhere in the codebase; EMI is a flat
`amount ÷ tenure` suggestion the leader can override at approval time.

**Status lifecycle**: `pending → active` (leader/staff approval — note the
schema-legal `approved` value is never actually used; approval jumps straight
to `active` and sets `disbursed_on`/`emi`/a 30-day-out `next_due_date`) or
`pending → rejected`. `active/overdue → closed` happens automatically, as a
side effect of a payment reducing `outstanding` to zero — there is no
separate "close loan" action. **`overdue` is a fully-supported status value
in the UI (badges, filters, a red-tinted detail view) that no code path in
the app ever actually sets** — it would require an external scheduled process
comparing due dates to today, which does not currently exist. Treat "overdue"
as a modeled-but-currently-unreachable state, not a working feature, until
such a process is built.

Approval is a leader/staff action from a pending-applications queue; both
Approve and Reject handle the case where a second staff member already
decided the same application concurrently (surfaced as "already decided by
someone else," not a generic error). **A leader can approve or reject any
other member's loan in her SHG, but is mechanically blocked — at the database
layer — from deciding her own loan application**, even though she is
otherwise a fully privileged approver.

Recording a payment is restricted in the UI to non-member roles (a member
cannot record her own EMI payment — this mirrors both real SHG practice,
where the leader/treasurer collects and records EMI at meetings, and the
underlying RLS, which does not permit the borrowing member to update her own
loan's outstanding balance). The payment amount is validated against the
outstanding balance both client-side (immediate feedback) and, as the actual
trust boundary, inside an atomic RPC (`record_loan_payment`) that row-locks
the loan, rejects overpayment outright rather than clamping it, and closes
the loan atomically with the balance decrement if it reaches zero — see
[ARCHITECTURE.md](ARCHITECTURE.md) §3.4 for the concurrency guarantee this
provides and why a plain client-side read-then-write would be unsafe.

| ID | Requirement | Roles |
|---|---|---|
| FR-LOAN-1 | Member applies for a loan (purpose, amount, tenure); starts `pending`, fully undisbursed | Member |
| FR-LOAN-2 | Leader/staff approve (setting EMI, disbursement date) or reject a pending application | Leader, staff |
| FR-LOAN-3 | A leader cannot approve/reject her own loan application — enforced at the database layer, not just hidden in the UI | System |
| FR-LOAN-4 | Member tracks her own loan(s): outstanding balance, EMI, status, payment history | Member |
| FR-LOAN-5 | Non-member roles record a payment against a loan; balance decrement, overpayment rejection, and auto-close-on-zero happen atomically | Leader, staff |
| FR-LOAN-6 | Leader/staff view the group/portfolio loan list with status badges | Leader, CRP, CLF, Admin |
| FR-LOAN-7 | `overdue` status is modeled in schema and UI but has no automated trigger in the current codebase — documented as not-yet-implemented, not broken | — |

### 3.5 Financial Ledger (`financial/`)

**How it works.** One physical table (`financial_ledger`) serves four screens
— Cashbook, Ledger, Bank, Audit — discriminated purely by an `entry_type`
column, each maintaining its **own independent running balance**. A
leader/staff posts a description, an amount, and a Credit/Debit toggle; the
new balance (`previous + credit − debit` for that specific `(shg_id,
entry_type)` pair) is computed atomically inside an RPC
(`add_financial_ledger_entry`) using a transaction-scoped advisory lock keyed
on that pair — this closes a real race where two concurrent postings of the
same ledger type could both read the same stale previous balance and
permanently desync every later row's chained total. The RLS `INSERT` policy
independently re-derives and checks the same balance formula, so even a raw
REST call bypassing the RPC can't post an arbitrary balance.

All SHG members can read the ledger (transparency); only the SHG's leader can
post new entries, and — critically — **no UI path or RLS policy permits
editing or deleting an already-posted row** (update/delete is staff-only, and
even staff editing a mid-sequence entry would desync every later row's chained
balance with no trace, which is exactly what this design prevents by
omission).

| ID | Requirement | Roles |
|---|---|---|
| FR-FIN-1 | Leader posts a ledger entry (description, amount, credit/debit) to one of Cashbook/Ledger/Bank/Audit | Leader |
| FR-FIN-2 | Running-balance computation and insert happen atomically per `(shg_id, entry_type)`, race-safe under concurrent postings | System |
| FR-FIN-3 | All SHG members have read access to the ledger; no client path exists to edit or delete a posted entry | Member, Leader |

### 3.6 Meetings (`meetings/`)

**How it works.** A leader schedules a meeting (date, time, required venue,
optional agenda). A leader/staff can now genuinely **cancel** a scheduled
meeting (a confirm dialog on the detail page calls
`MeetingRepository.setStatus(id, 'cancelled')`) — this was previously dead
code with zero call sites anywhere in the app, so `status` could never
actually change. `status` still never advances to `'completed'` on its own:
"has this meeting happened" is derived from date math (`meeting_date` vs.
today) everywhere it's used, **except** that a cancelled meeting is now
correctly excluded from every completed-meeting/attendance-percentage
calculation regardless of its date — a meeting a leader cancelled no longer
silently counts as a "completed meeting with 0% attendance" and drags down
the SHG's real stats, which it did before this fix (since nothing could ever
mark a meeting cancelled).

Check-in has two entry points — "Scan QR" and "Check In Without Scanning" —
that both call the **identical** attendance-marking logic. Scanning a QR code
does not encode or validate anything meeting- or member-specific; the
scanned content is discarded entirely once the camera detects *any* readable
code. What the QR affordance actually provides is a familiar gesture that
closes the camera and triggers self-check-in for whichever meeting is
scheduled *today* (deliberately not "the next upcoming meeting," which could
be weeks out — this hard gate to the exact calendar day stops a member from
marking herself present for a future meeting). A member can only check in
for herself; there is no cross-member/proxy check-in path.

Leader-side attendance marking is a per-row toggle switch with no separate
"save" step — each toggle immediately upserts. Minutes of Meeting are
append-only: each "add decision" writes a brand-new row containing the entire
updated decision list, and the page always displays only the latest row.
Action items have per-item ownership: only the item's owner, the SHG leader,
or staff can toggle it done — a leader/staff now genuinely **assigns** an
action item to a specific SHG member via a roster picker when creating it
(previously `ownerId` was always written as null with no UI to set it, so a
plain member could never satisfy the "I'm the owner" branch and only
leader/staff could ever toggle any item, regardless of who it was actually
for).

**Enforcement**: leader/staff can schedule and mark attendance; deletion of
meeting records is staff-only (hardened specifically because a leader could
otherwise scrub an inconvenient meeting and cascade-delete its minutes and
every member's attendance record via foreign-key cascade).

| ID | Requirement | Roles |
|---|---|---|
| FR-MTG-1 | Leader schedules a meeting (date/time/venue/agenda) | Leader |
| FR-MTG-2 | Any member self-checks-in (via QR gesture or a plain button — functionally identical) for whichever meeting is scheduled *today* | Member |
| FR-MTG-3 | Leader marks/edits the attendance roster via per-row toggle | Leader |
| FR-MTG-4 | "Has this meeting happened" is derived from date, not from `status` — `status` reaching `'completed'` is still not implemented — but a leader/staff can genuinely cancel a meeting, and a cancelled meeting is correctly excluded from every completed/attendance stat regardless of date | Leader, staff |
| FR-MTG-5 | Leader/owner records Minutes of Meeting (append-only decisions) and action items, assignable to a specific SHG member via a roster picker, with per-owner toggle | Leader |
| FR-MTG-6 | Meeting record deletion is staff-only, to protect minutes/attendance from cascade-loss | System |

### 3.7 Livelihoods (`livelihood/`)

**How it works.** A member records an activity (type, description, initial
investment); it always starts `status:'planned'` with zero revenue. Any SHG
member can read every other member's activities (same transparency pattern as
savings/loans); a leader/staff sees the whole SHG's activities, a plain
member sees only her own on the home list. "Update Progress" (revenue-to-date
and status) is client-gated to the activity's own owner or leader/staff —
specifically to prevent a teammate who can *see* the button (because reads
are SHG-wide) from tapping it and hitting a silent RLS no-op that looks like a
successful save. Progress updates overwrite revenue/status directly; there is
no history of intermediate updates retained.

| ID | Requirement | Roles |
|---|---|---|
| FR-LIV-1 | Member records a livelihood activity, starting `planned`/zero revenue | Member |
| FR-LIV-2 | Owner (or leader/staff) updates revenue-to-date and status; overwrites, no history kept | Member (own), Leader, staff |
| FR-LIV-3 | SHG members share read access to the group's livelihood activity for transparency | Member, Leader, staff |

### 3.8 Marketplace (`marketplace/`)

**How it works.** This module is explicitly **cross-SHG** — any member can
list a product and any other member across the whole platform can browse and
buy it. Listing sets a price (capped at ₹1,000,000, same fat-finger guard
pattern as other money fields), a stock count, and an **optional photo** —
picked via `file_picker` (5 MB cap, JPEG/PNG/WEBP) and uploaded to the public
`product-images` Storage bucket under the seller's own folder; the resulting
public URL is stored on the product row and shown on both the catalog grid
and the product detail page, falling back to the original storefront-icon
placeholder for products with no photo (including every product listed
before this feature shipped). Placing an order calls an
atomic RPC (`decrement_product_stock`) that decrements stock in a single
guarded statement (`stock - 1 where stock > 0`) — this closes a real,
previously-live bug where a buyer's own client-side stock decrement was
always a silent 0-row RLS no-op (only the seller/staff may write to the
product row), meaning stock had genuinely never decremented for a real
purchase before this RPC existed. The order is recorded using the **RPC's
returned price**, never a client-supplied value, closing a trust-boundary gap
where a stale page could otherwise record any amount for a real order.

**Order status** (`new → packed → shipped → delivered`) is a free-form chip
row the seller (or staff) can set to *any* value at *any* time, including
backward — this is an intentional "correct a mistake" design, not a bug, and
is not guarded by any lock/RPC the way the loan/scheme decision flows are.

**Review eligibility is enforced at the database layer, not the UI**: posting
a review requires an existing order for that exact product under the
reviewer's own identity — you must have actually bought the product. A
partial unique index limits one review per reviewer per product. This
replaced an earlier, more permissive policy that let *anyone*, authenticated
or not tied to a purchase, post unlimited reviews under any free-text name —
closed before the "Write a Review" UI existed, specifically to prevent
self-boosting or rival review-bombing from ever becoming exploitable once it
shipped.

| ID | Requirement | Roles |
|---|---|---|
| FR-MKT-1 | Member/seller lists a product (name, description, price, stock, category) | Member, Leader |
| FR-MKT-2 | Any user browses the cross-SHG product catalog and product detail | All |
| FR-MKT-3 | Any user places an order; stock decrement and price-locking happen atomically | All |
| FR-MKT-4 | Seller (or staff) freely sets order status to any of the 4 values, including backward, without a locking RPC | Member, Leader (seller), staff |
| FR-MKT-5 | Only a verified past buyer of the specific product may post a review; one review per reviewer per product | All |
| FR-MKT-6 | Review moderation (edit/delete another user's review) is staff-only | Staff |

### 3.9 Government Schemes (`schemes/`)

**How it works.** Any user browses a platform-wide scheme catalog. Applying
is **member-self-service only** — the Apply button is hidden for leader/staff
personas, matching an RLS restriction that only lets a member apply on her own
behalf. A scheme past its deadline shows "Applications closed" instead of an
Apply button; this deadline check is independently re-verified inside the
INSERT policy itself (`WITH CHECK ... deadline is null or deadline >=
current_date`), closing a real gap where the app's own seed data already
carried past deadlines that an unchecked insert would have silently accepted.
Duplicate applications are prevented purely by a database uniqueness
constraint on `(scheme_id, member_id)`; there is no application-withdrawal
feature — an application, once filed, is a permanent record (no DELETE
policy exists for it at all).

**The Eligibility Checker is now a real structured rules engine, not a
keyword heuristic.** `EligibilityCriteria`/`evaluateSchemeEligibility()`
(`lib/models/scheme.dart`) evaluates a scheme's structured
`requiresShgMembership`/`minShgAgeMonths`/`minShgGrade` criteria (stored in
`schemes.eligibility_criteria`, a JSONB column, migration `0040`) against the
member's *actual* SHG membership/registration age/grade, and shows an
itemized ✓/✗ result per criterion with a plain-language reason ("✓ SHG
registered 18+ months (requires 12+)", "✗ Requires SHG grade B or above —
yours is graded C"). This is deliberately scoped to the only structured
member/SHG facts this app's data model actually carries — there is no
income, gender, caste/category, age, or occupation field anywhere in
`profiles`, so no criteria were invented for those; a scheme's existing
free-text eligibility list is still shown for requirements that genuinely
need manual/documentary verification. This is a real evaluation over real
stored facts, not a connection to any government eligibility API (none
exists or is reachable from this project).

Staff review pending applications from a shared, platform-wide queue (not
scoped to their own SHG); Approve/Reject goes through an atomic RPC
(`decide_scheme_application`) that row-locks the application and rejects a
second decision on an already-decided one — the same already-decided race
guard pattern used for loan approval.

| ID | Requirement | Roles |
|---|---|---|
| FR-SCH-1 | Any user browses the scheme catalog and scheme detail | All |
| FR-SCH-2 | Eligibility checker evaluates real structured SHG-membership/age/grade criteria and shows an itemized ✓/✗ result — still not a government e-filing determination, and criteria needing income/gender/caste/occupation data remain manual-verification-only | All |
| FR-SCH-3 | Member applies to a scheme (self-service only) before its deadline; tracks application status; no withdrawal path exists | Member |
| FR-SCH-4 | Staff review and decide pending applications from a shared platform-wide queue, with an already-decided race guard | CRP, CLF, Admin |
| FR-SCH-5 | Admin manages the scheme catalog (create/edit/delete) | Admin |

### 3.10 Training / E-Learning (`training/`)

**How it works.** Any user browses a platform-wide course catalog. Progress
toward a course advances by a **flat +50 percentage points per tap** of a
"Continue" button — there is no real content-consumption tracking (no
video-watched percentage, no scroll tracking); two taps takes any course from
0% to 100%. Certification is entirely separate from that progress number: it
is granted only by passing a quiz, reachable at any time regardless of
displayed progress.

**The quiz now has real, per-course content**, backed by a new
`quiz_questions` table (migration `0041`: course-scoped question/options/
correct-index rows, RLS mirroring `training_courses` — any authenticated
user reads, only staff/admin authors). Each demo course was seeded with a
genuine, on-topic starting set of questions (household budgeting, EMI/
interest mechanics, micro-enterprise basics, UPI/QR payment safety, etc. —
written from that course's own real title/topic, not generic filler) —
replacing the old single fixed 3-question set shared by every course
regardless of topic. Passing requires a proportional ≥2/3 correct (a
generalization of the old fixed rule to a variable question count per
course), with no attempt limit or cooldown on retrying. Passing upserts
`certified:true` and a completion date — this is the *only* path to
certification; reaching 100% progress via the Continue button does not by
itself certify a course. This seeded content is a genuine starting set, not
a transcription of any real curriculum — a subject-matter expert should
review/extend it before this is treated as the app owner's final course
material.

| ID | Requirement | Roles |
|---|---|---|
| FR-TRN-1 | Any user browses the course catalog and course detail | All |
| FR-TRN-2 | Progress advances via a flat increment per "Continue" tap — not real content-consumption tracking | All |
| FR-TRN-3 | A real per-course quiz (`quiz_questions` table) is the sole path to certification, proportional ≥2/3 pass threshold, unlimited retries | All |
| FR-TRN-4 | A certificate/completion date is issued on quiz pass | All |
| FR-TRN-5 | Staff/CRP view training completion at an aggregate level | CRP, CLF, Admin |

### 3.11 Digital Payments (`payments/`)

**How it works.** A user scans a QR code (parsing a `upi://pay?...`-style
payload for payee/amount if present, or treats a bare numeric payload as an
amount) or enters an amount and mode manually, then pays. **The payment
gateway itself is fully mocked** — `MockPaymentProcessor` always succeeds
after a simulated delay and synthesizes a fake reference; no real UPI/bank
settlement occurs anywhere in this codebase. The repository writes the
charge's outcome (success or failure) to the `payments` table once and never
updates that row again — a payment record is genuinely append-only from the
client's perspective, mirroring the atomic-once semantics a real gateway
integration would need. A member can update her own payment's `status`
directly is explicitly **not** permitted at the RLS layer — closing a gap
where a client could otherwise flip a failed charge to "success" without a
real gateway ever confirming it.

| ID | Requirement | Roles |
|---|---|---|
| FR-PAY-1 | User scans a QR code or enters details manually to pay; gateway is currently mocked, not real settlement | All |
| FR-PAY-2 | User views payment history (read-only, own payments) | All |
| FR-PAY-3 | A payment row is written once on charge outcome and is not client-updatable afterward — real gateway webhook handling exists as an integration point, not yet wired to a real provider | System |

### 3.12 Announcements (`announcements/`)

**How it works.** A leader/staff posts a title, body, and category
(Circular/Meeting/Training/Scheme) scoped to her own SHG, or — for staff —
platform-wide (`shg_id: null`). Members see their own SHG's announcements
**plus every platform-wide one**, merged in one query. Opening the detail
page is the sole "mark as read" trigger — there is no separate read-receipt
button — implemented as an upsert so re-opening an already-read announcement
is a harmless no-op.

| ID | Requirement | Roles |
|---|---|---|
| FR-ANN-1 | Leader posts an SHG-scoped announcement; staff may post platform-wide | Leader, staff |
| FR-ANN-2 | Any user sees their SHG's announcements plus platform-wide ones, with unread/read state | All |

### 3.13 Support / Helpdesk (`support/`)

**How it works.** A user raises a ticket (subject required, description
optional) — status defaults to `open` at the database level and is never set
explicitly by the client. The ticket becomes a threaded, chat-style
conversation (`support_messages`, a flat append-only table rendered as chat
bubbles) with no realtime subscription — a reply from the other party appears
only on the next reload, not live. **Visibility is enforced twice**: the
client shapes its query differently for staff (no member filter — sees every
ticket platform-wide, capped at 500) versus a member (filtered to her own),
and — independently, as the actual boundary — RLS restricts a non-staff
caller's read to her own tickets regardless of what query shape the client
sends. Status changes (open/in_progress/resolved/closed) are staff-only, both
in the UI and at the RLS layer — closing a gap where a member could otherwise
self-close her own complaint via a direct API call even though no UI ever
exposed that action.

FAQs are fully static content, not backed by any table. Voice Support follows
the same "record → transcribe → answer" state machine as the AI Voice
Assistant, backed by real on-device speech-to-text/text-to-speech
(`speech_to_text` + `flutter_tts`) in live mode, with a mock speech service
retained for demo mode — see [AI_MODULES.md](AI_MODULES.md) §3 for the shared
real/mock pattern.

| ID | Requirement | Roles |
|---|---|---|
| FR-SUP-1 | Any user browses static FAQ content | All |
| FR-SUP-2 | Any user raises a ticket and follows a threaded (non-realtime) chat conversation | All |
| FR-SUP-3 | Any user accesses voice-based support (real on-device STT/TTS in live mode, mocked in demo mode, real underlying data where applicable) | All |
| FR-SUP-4 | A member sees only her own tickets; staff see all tickets platform-wide (capped at 500) — enforced independently at the RLS layer | Member vs. CRP/CLF/Admin |
| FR-SUP-5 | Ticket status changes are staff-only, both client-side and at RLS | Staff |

### 3.14 AI Advisory (`ai/`)

Full technical detail — architecture, exact system prompts, rate limiting,
the Voice Assistant's real on-device STT/TTS, and an honest safety/moderation
accounting — is in the dedicated [AI_MODULES.md](AI_MODULES.md) document.
Summary for SRS purposes:

| ID | Requirement | Roles |
|---|---|---|
| FR-AI-1 | User chats with an AI Financial Advisor (Groq-backed, single-turn, no memory across questions) | All |
| FR-AI-2 | User chats with an AI Scheme Recommender | All |
| FR-AI-3 | User chats with an AI Market Advisor | All |
| FR-AI-4 | User interacts with a Voice Assistant in English/Hindi/Telugu — **real on-device speech recognition and synthesis in live mode** (`speech_to_text` + `flutter_tts`, no vendor key), falling back to a mock speech service in demo mode; answer content for recognized intents is drawn from the user's real data | All |
| FR-AI-5 | Every chat-advisor exchange (not Voice Assistant) is logged for audit, retained indefinitely, staff-readable | System |
| FR-AI-6 | Chat-advisor requests are rate-limited server-side to 10/minute per member, fail-closed | System |
| FR-AI-7 | A persistent, localized disclaimer ("AI-generated guidance… not professional financial, legal, or medical advice") is shown on every AI-branded screen; **no content moderation or prompt-injection defense exists yet** — disclosed explicitly as a remaining pre-scale gap, not silently accepted | — |

### 3.15 Analytics & Reports (`analytics/`, `reports/`)

**How it works.** Personal/SHG-level reports (financial summary, performance,
attendance, loan statement) are computed from live queries against the
underlying tables at read time. Platform-wide analytics (KPIs, SHG list with
health/grade, drill-down detail) and federation-wide reports (growth,
recovery rate, villages) are the CRP/CLF/Admin-facing views; a nightly,
`pg_cron`-triggered Edge Function (`generate-report-snapshots`) exists to
precompute heavier report data rather than recomputing it on every request.
"Health score"/"grade" figures surfaced on CRP/CLF dashboards and the
analytics SHG list are attendance-based proxies computed client-side, not a
validated composite health methodology — treat them as a heuristic ranking
signal, not a certified metric.

| ID | Requirement | Roles |
|---|---|---|
| FR-RPT-1 | Member views her own personal report | Member |
| FR-RPT-2 | Leader/staff view SHG-level reports (financial summary, performance, attendance, loan statement) | Leader, CRP, CLF, Admin |
| FR-RPT-3 | CRP/CLF/Admin view platform-wide analytics: KPIs, SHG list with health/grade (an attendance-based proxy, not a certified metric), SHG detail drill-down | CRP, CLF, Admin |
| FR-RPT-4 | CLF/Admin view federation-wide reports: growth, recovery rate, villages | CLF, Admin |

### 3.16 SHG (Group) Management (`shg/`)

**How it works.** "My SHG" shows the group's profile, a federation-info card,
and — client-gated to non-member roles only — a Bank Details card. Note this
specific gate is **UI-only**: the underlying RLS policy for reading `shgs`
permits any member of the SHG (not just leader/staff) to read the full row
including `bank_account`/`ifsc`, so this is a case where the client hides a
sensitive field from members but the database does not independently
restrict it from them — worth a deliberate decision (tighten the RLS, or
accept the current in-person-SHG-transparency norm extends to bank details
too) rather than assuming the UI gate is sufficient.

Join-request approval is a leader-only screen; the underlying RPC
(`approve_shg_join_request`) also accepts staff, even though the router
restricts the *page* to leaders only. A rejected request's row is immutable —
there is no re-decision path; a member must file a fresh request (with any
prior pending request from her automatically superseded/deleted to satisfy a
one-pending-per-member constraint).

The Documents screen wires a real upload: "Add document" requires picking a
PDF/JPEG/PNG/WEBP file (`file_picker`, 10 MB cap) alongside the name, uploads
it to the `shg-documents` Storage bucket under the SHG's own folder, and
persists the resulting `storagePath` (plus a human-readable size) on the
`shg_documents` row. The list's download icon requests a short-lived signed
URL (the bucket is private) and opens it — pre-existing metadata-only rows
from before this feature (or demo-mode's mock records) correctly show "No
file is attached to this record" instead of attempting to open nothing. Both
this write path and the write path to Bank Details visibility are genuinely
leader/staff-gated at the RLS layer, unlike the read-visibility gap noted
above.

| ID | Requirement | Roles |
|---|---|---|
| FR-SHG-1 | Any user searches/browses SHGs via a safe public directory view (bank fields never exposed through it) | All |
| FR-SHG-2 | Leader views the member roster and per-member detail | Leader |
| FR-SHG-3 | Leader (or staff, via the same RPC) approves/rejects join requests; a rejected request cannot be re-decided | Leader, staff |
| FR-SHG-4 | Document repository requires and uploads a real file (PDF/JPEG/PNG/WEBP, 10 MB cap) to Supabase Storage; downloads via a short-lived signed URL | Leader, staff |
| FR-SHG-5 | Bank account/IFSC are hidden from members in the UI, but not independently RLS-restricted from them at the table level — flagged for a deliberate decision, not currently a database-enforced boundary | — |

### 3.17 Admin Console (`admin/`)

**How it works.** Manage Users lists all profiles via real keyset pagination
(a "Load more" control fetches the next page by cursor rather than the old
flat `LIMIT 500` with an unreachable alphabetical tail) and lets an admin
change a user's role through a
two-step confirmation dialog (deliberately two steps, since a role change can
grant or revoke admin authority) or assign an SHG to a staff account that has
none (staff signups have no join-request path, so without this screen they'd
be permanently stuck unlinked). If an admin changes her *own* role or SHG, the
app explicitly refreshes her cached profile afterward, so the UI doesn't keep
offering now-server-rejected actions.

Manage SHGs lets an admin create SHG records — this exists specifically
because the underlying RLS policy (`shgs_insert_staff`) permits *any* staff
role to create an SHG, but no other client anywhere called it, which was a
real onboarding blocker on a fresh deployment with zero seeded SHGs. Manage
Schemes supports full create/edit/delete, restricted to `admin` at the RLS
layer specifically (stricter than the SHG-creation policy, which is
any-staff).

System Monitoring shows **real row counts** from `profiles`/`shgs`/
`savings_entries`/`loans` (not synthetic numbers), but is explicitly and
visibly labeled in its own UI as placeholder metrics — "not real
infrastructure metrics (uptime, latency, error rate)." This label must be
preserved in any future redesign of this screen.

| ID | Requirement | Roles |
|---|---|---|
| FR-ADM-1 | Admin manages user accounts: role assignment (two-step confirmation), SHG assignment for unlinked staff | Admin |
| FR-ADM-2 | Admin (or, at the RLS layer, any staff role) creates SHG records | Admin |
| FR-ADM-3 | Admin manages the scheme catalog (create/edit/delete), RLS-restricted to `admin` specifically | Admin |
| FR-ADM-4 | Admin views system monitoring — real row counts, explicitly labeled in-UI as placeholder, not real infrastructure telemetry | Admin |

### 3.18 Services Directory (`services/`)

**How it works.** A single grouped navigation page lists every module
reachable by the current role (SHG Management / Commerce / Learning &
Support groupings), as the full-grid counterpart to each dashboard's curated
shortcuts. Purely a navigation aid — no independent data or write behavior of
its own.

| ID | Requirement | Roles |
|---|---|---|
| FR-SVC-1 | Full grouped nav grid of every module reachable by the current role | All |

---

## 4. Data Requirements

27 base Postgres tables + 1 view (`shg_directory`). Full table list, entity
purposes, and the atomic RPCs that guard concurrency-sensitive operations are
in [ARCHITECTURE.md](ARCHITECTURE.md) §2 and §3.4 — not duplicated here to
avoid the two documents drifting out of sync.

---

## 5. External Interface Requirements

| Interface | Purpose | Current state |
|---|---|---|
| Supabase Auth | Phone/OTP authentication | Real |
| Supabase Postgres/PostgREST | All CRUD, gated by RLS | Real |
| Supabase Storage | Document/product-image storage | Real — `shg-documents` (private)/`product-images` (public) buckets, real `file_picker` upload UI |
| Groq LLM API | AI Advisor chat completions | Real, see [AI_MODULES.md](AI_MODULES.md) |
| Device speech (STT/TTS) | Voice Assistant, Voice Support | Real — on-device `speech_to_text`/`flutter_tts`, no vendor key; see [AI_MODULES.md](AI_MODULES.md) §3 |
| Payment gateway | Real money movement | **Mocked** — `MockPaymentProcessor` always succeeds; `payment-webhook-handler` Edge Function exists as the integration point for a real gateway |
| Device camera | QR scanning (meeting check-in, pay) | Real (`mobile_scanner`) |
| Device SMS | OTP delivery | Real (Supabase Auth phone provider) |
| Device local notifications | Meeting/loan-due/announcement reminders (Settings toggles) | Real, **local-only** — `flutter_local_notifications`, no push/remote backend (would need a Firebase/APNs project this app doesn't have); cannot be click-tested in a web browser preview, only via a real device/emulator |

Convention: any new third-party API gets an interface in `lib/services/` with
a `Mock*` implementation, so swapping the real provider later is a one-file
change — see [ARCHITECTURE.md](ARCHITECTURE.md) §1.

---

## 6. Non-Functional Requirements

Full detail lives in the dedicated documents; summarized here for
completeness.

### 6.1 Security
RLS is the authorization boundary, not client-side checks. Full design
decisions, helper functions, and the atomic-RPC concurrency guarantees are in
[ARCHITECTURE.md](ARCHITECTURE.md) §3. The audit history — every CRITICAL
finding, the systematic CRUD-completeness sweep, and current status — is in
[QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §2.

### 6.2 Performance
Avoid N+1 query patterns (use PostgREST embedded selects). Realtime
subscriptions are reserved for screens where collaborative live updates
genuinely matter (the savings ledger), not used by default.

### 6.3 Localization & Accessibility
English/Hindi/Telugu parity is required for every new string; audit findings
and the disclosed ~99-file non-localized-screen gap are in
[QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §4. Text-scale (1.3x–2x)
resilience is required; accessibility audit findings are in
[QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §3.

### 6.4 Reliability & Offline Behavior
Demo/offline mode is a first-class product mode, not a fallback — see
[MANIFESTO.md](MANIFESTO.md) principle 3. Session/token expiry must be
handled gracefully everywhere an API call can occur.

### 6.5 Maintainability
New modules follow the exact layering in
[ARCHITECTURE.md](ARCHITECTURE.md) §1 and §6. Mock data in `lib/data/*.dart`
is never deleted when a module gains a real backend.

### 6.6 Verification
No feature is considered done on the strength of compiling or being read and
reasoned about — see [TESTING_STRATEGY.md](TESTING_STRATEGY.md) §1 for why,
and [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §1 for the definition-of-
done checklist this implies.

---

## 7. Appendix: Implementation Status Snapshot

Point-in-time only — for current state, check
[docs/DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)'s tail, not this
appendix.

As of the last recorded update: all 18 functional modules in §3 are
implemented end-to-end against the live Supabase backend; 36 migrations
deployed; `flutter analyze` clean; **713/713 automated tests passing**;
**277 confirmed, fixed bugs across 82 audit/live-testing rounds** (see
[TESTING_STRATEGY.md](TESTING_STRATEGY.md) §4 for the taxonomy). Deliberately
disclosed, not-yet-real items, all covered above and in
[ARCHITECTURE.md](ARCHITECTURE.md) §7 and
[QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md) §7: real file/document upload,
real payment-gateway settlement, real voice STT/TTS, real infrastructure
monitoring, and scheme-eligibility/course-quiz content (both intentional
generic heuristics). The AI advisor disclaimer and app crash-reporting gaps
flagged in the first version of this doc suite were closed the same round
they were identified (round 83 in
[DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)) — the remaining
AI-related gap worth prioritizing before scaling real usage is content
moderation/prompt-injection defense (see [AI_MODULES.md](AI_MODULES.md) §6).
