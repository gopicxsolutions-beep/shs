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

**No role is self-declared in live mode.** Every signup starts as a plain
`member`, and an SHG pick during Profile Setup is now mandatory (see §3.1) —
becoming a `leader` only ever happens when whoever reviews that SHG's pending
join request (its own leader, or staff) chooses to approve it *as leader*
rather than as a plain member. Staff roles (`crp`/`clf`/`admin`) are, as
before, assignable only by an existing Admin from the Admin Users screen, and
approving a request as leader is itself staff-only (a peer leader keeps her
existing approve-as-member/reject authority over her own SHG's queue, but
can't unilaterally mint a co-leader). This replaced an earlier design where a
live-mode Role Select screen let a new user self-declare "Leader" — that self-
declaration never actually linked her to an SHG (there was no self-service
"create an SHG" path), so a self-registered Leader routinely ended up
permanently unlinked with no indication anything was wrong; see
[ARCHITECTURE.md](ARCHITECTURE.md) §3.3 for the exact enforcement mechanism
and incident history. Role Select itself is now demo-mode-only (all 5 roles
remain selectable there, so every dashboard stays explorable without a
backend) — the router redirects any live-mode visit to it away.

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

**How it works.** The very first screen a fresh install ever reaches — before
Splash, before Login, before anything else in the auth flow — is a
**language picker** (`Paths.languageSelect`): three full-width rows
(English / తెలుగు / हिंदी), each showing its own name in its own script.
Tapping one calls `AppState.setLanguage`, which applies immediately and
persists to `SharedPreferences`, then continues into Splash. This shows
exactly once per device: the router's redirect gates it on
`AppState.languageSelected` (whether `shg_language` has ever been written,
not just whether the current session is authenticated), so a returning user
— including one whose account predates this feature and simply never opened
Settings → Language — is never interrupted mid-app to force a pick. The
language can always be changed again later from Settings → Language
(`LanguagePage`), which shares the same three rows.

Login takes a single 10-digit mobile number, validated
client-side against `^[6-9]\d{9}$` (Indian mobile numbers only — deliberately
rejects numbers that could never receive an SMS, rather than accepting any
10-digit string). Submitting sends an OTP via Supabase Auth
(`signInWithOtp`) in live mode, or skips straight through in demo mode. The
OTP screen presents 6 individual digit boxes with auto-advancing focus and
paste-distribution support (pasting a 6-digit code fills all boxes and moves
focus to the end), plus a 30-second resend cooldown. On verification, the app
loads (or discovers the absence of) a `profiles` row and routes onward.

Profile Setup collects Name (required), Village/Mandal/District (free text),
and a **mandatory** SHG search-and-pick (debounced, searches a safe public
`shg_directory` view — never the base `shgs` table's sensitive columns).
Picking an SHG does not directly link the profile to it — it files a
`shg_join_request` that whoever reviews it (the target SHG's own leader, or
staff) must approve. `role` is always initialized to `'member'` on signup;
SHG linkage — and, if the approver chooses, promotion to `'leader'` — happens
atomically together, at approval time (see `approve_shg_join_request`,
migration `0116`). There is no path to a `role='leader'` account with no
SHG, because leader is never granted independently of that same approval.

Immediately after the basic-info step, the same screen continues into the
**ICSSR baseline survey** — a 9-section research questionnaire ("A
Longitudinal Study of Women-Led Microenterprises and Social Transformation in
Andhra Pradesh through Digital Empowerment"): Demographics, Enterprise
Profile, Digital Access & Usage, Financial Inclusion, Entrepreneurial Skills,
Empowerment & Agency, Challenges & Needs, Expectations from Government/NGOs,
and Consent & Confidentiality. It's presented as a step-indexed wizard (chip
pickers for single/multi-select questions, plain fields for free text/
numbers) with a progress bar, and is **mandatory before dashboard access**:
every field on a section — including a conditional "specify" field revealed
by an "other(s)" choice — must be filled/selected before Next enables for
that section, all the way through the final Consent step (a checkbox plus a
typed signature). Submission writes to
`public.member_baseline_surveys`, one row per profile
(migration `0151`), alongside — not instead of — the `profiles`
row/join-request writes above. An account that existed before this
requirement shipped is routed back into the same wizard (survey-only, name/
village/SHG steps skipped) the next time it reaches the router, via
`AppState.needsBaselineSurvey`. This table is scoped to `member`/`leader`
(the survey is about a woman running or working in an SHG-linked
microenterprise, not the federation-oversight staff roles) and, unlike the
SHG-transparency data described in [ARCHITECTURE.md](ARCHITECTURE.md), is
**not** visible to a fellow member or even her own SHG leader — only the
respondent herself and federation staff (CRP/CLF/Admin, for research
reporting) can read it.

Every fresh signup lands on **SHG Approval Pending**, which polls her own
join-request status and offers "Choose a different SHG" if it's rejected —
there is no separate Role Select step in live mode to pass through first (see
above). A router-level redirect chain (`lib/routes/router.dart`) enforces
this sequence — no-session → profile setup → SHG approval — on every
navigation, so a partially-onboarded user can't reach the dashboard by typing
a URL directly; the router additionally redirects any live-mode visit to
Role Select's own route away, since it has nothing left to do there.

A distinct **Profile Load Error** screen (vs. a plain "no profile yet") exists
specifically so a returning, already-onboarded user who opens the app offline
isn't misrouted into onboarding — the router distinguishes "no profile because
none exists" from "no profile because the fetch failed for a network reason."

**Role-escalation prevention** is the most heavily audited property of this
module — see [ARCHITECTURE.md](ARCHITECTURE.md) §3.3 for the full client +
database defense-in-depth chain and its incident history.

| ID | Requirement | Roles |
|---|---|---|
| FR-AUTH-0 | First-run language picker (English/Telugu/Hindi) shown before Splash/Login/anything else, exactly once per device (gated on whether a language has ever been chosen, not on auth state), skippable by nobody since all three are complete UIs | All |
| FR-AUTH-1 | Phone + OTP authentication, Indian mobile number format validated client-side | All |
| FR-AUTH-2 | Profile setup: name (required), village/mandal/district, mandatory SHG search-and-request-to-join | All |
| FR-AUTH-2b | Mandatory 9-section ICSSR baseline survey (demographics through consent) at registration time, stored in `member_baseline_surveys`; every field on every section is required — Next stays disabled until all of a section's fields are filled/selected — through submitting the final Consent step | Member, Leader |
| FR-AUTH-3 | Role Select is demo-mode-only (all 5 roles explorable there); a live-mode visit to it is always redirected away | All |
| FR-AUTH-4 | A fresh signup's `shg_id` stays null and an approval-pending screen shows until the target SHG's join request is decided | Member |
| FR-AUTH-5 | Staff roles (CRP/CLF/Admin) are assignable only by an Admin via the Admin Users screen, never self-assigned, enforced at the RLS layer independent of the UI | Admin |
| FR-AUTH-6 | A network-caused profile-load failure shows a distinct, recoverable error screen rather than misrouting into onboarding | All |
| FR-AUTH-7 | A genuine deep link captured before login is replayed after successful OTP verification, once onboarding is fully complete | All |
| FR-AUTH-8 | Approving a join request can promote the requester to Leader instead of Member — staff-only; a peer leader reviewing her own SHG's queue can only approve as Member or reject | Leader, CRP, CLF, Admin |

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
staff-only. **Reversed as of round 190**: a leader/staff account can no
longer verify her own submitted deposit — `savings_update_leader_or_staff`
now self-excludes both branches (`member_id <> auth.uid()`), the same
self-dealing lockdown applied everywhere else in this schema. The ledger
UI (`savings_ledger_page.dart`, round 196) correspondingly no longer shows
the Verify/Reject controls on the viewer's own pending entry — it renders
a plain "Pending" status badge instead, since the server-side RLS
self-exclusion made the buttons a guaranteed silent no-op.

**Known gap, confirmed live (2026-07-25, round 147): FR-SAV-4/5 below had two
separate problems, and the same root cause turned out to be systemic across
five other modules.** First, FR-SAV-4 shared the exact "Leader/staff"
overclaim shape as FR-LOAN-2/5/6 and FR-RPT-2 (see their gap notes):
`savings_home_page.dart` and `savings_ledger_page.dart` both resolved "which
SHG" from `appState.profile?.shgId`, the *viewer's own* SHG — real for a
leader, always null for crp/clf/admin (platform-wide roles, never
SHG-scoped) — so a staff account saw a silently-empty/zero ledger (₹0 group
savings, 0 pending, "no entries yet") indistinguishable from a genuinely
quiet SHG. Second, FR-SAV-5 was simply mis-attributed, not just
overclaiming: the "per-member leaderboard and monthly trend" it describes is
`savings_group_report_page.dart`, which `savings_home_page.dart`'s own tile
routing (`isLeaderOrStaff ? Paths.savingsLedger : Paths.savingsGroupReport`)
sends to **members**, not leader/staff — leader/staff are routed to the flat
transaction ledger instead (FR-SAV-4's page, not a leaderboard). FR-SAV-5's
role list was never accurate for this screen.

Grepping the same `profile?.shgId` pattern surfaced five more pages sharing
Savings' first problem: `meetings_home_page.dart`, `meeting_attendance_page.dart`,
`meeting_qr_page.dart`, `financial_ledger_page.dart` (all four cashbook/
ledger/bank/audit views), `livelihood_home_page.dart` — plus `loans_home_page.dart`
and `loan_approval_page.dart`, already known from FR-LOAN's gap note.
`meeting_schedule_page.dart` had a milder version: a correct but *late*
`meetingScheduleNoShgError`, shown only after a staff account filled in the
whole form.

Unlike FR-LOAN's gap note, which concluded "not fixable by simply hiding a
tile... the real fix is a genuine new capability" and left the misleading
zero-state in place, this round found a third option that note didn't
consider: keep the page reachable, but replace the misleading empty/zero
rendering with an honest, explicit "this per-SHG view doesn't apply to your
role" message — the same design `shg_home_page.dart` already used correctly
for its own `shg == null` case, just not yet applied to these other files.
**Fixed this round** across all nine pages above (new shared string
`commonStaffNoShgMessage`, added to all three `.arb` files), gated on
`SupabaseService.isConfigured` and not just `shgId == null` — demo mode's
simulated identity leaves `profile` (and so `shgId`) null for *every*
previewed role, not just staff, so the guard had to exclude demo mode
explicitly or it would have wrongly swallowed that intentional mock-data
walkthrough for Leader/Member too. `meeting_schedule_page.dart` got the same
upfront guard as a strict improvement over its pre-existing late error
(which stays in place as a harmless fallback).

This closes the *misleading-UI* half of FR-LOAN's gap note too — crp/clf/
admin now see an honest explanation there as well. It does **not** close the
underlying *capability* gap: crp/clf/admin still cannot verify a savings
entry, approve a loan, or view any group ledger through this UI — the
genuine platform-wide "portfolio"/multi-SHG capability FR-LOAN's note
describes is still unbuilt. Role columns below reflect actual working
capability, not raw RLS permission. Not fixed (out of this pattern's scope —
no staff exposure): `savings_group_report_page.dart` has the identical
`shgId`-driven fetch but is only ever linked from the Member-facing tile;
the sole residual exposure is an *unlinked member* (pending SHG assignment,
not a staff/platform-wide role) reaching it directly, a narrower and much
rarer edge case left as a noted-but-unfixed observation rather than
expanded scope.

**Fixed (2026-07-26, round 168): the underlying capability gap this note
described is now closed for Savings — crp/clf/admin genuinely verify
entries platform-wide, not just see an honest explanation that they
can't.** Same fix template as §3.4's Loans note: `SavingsEntry` gained an
optional `shgName`; `SavingsRepository.fetchAllForStaff()` is the new
platform-wide fetch (`savings_select_shg_or_staff`/`savings_update_leader_
or_staff` were already unconditionally `is_staff()`-granted, confirmed by
re-reading the current policy text and, separately, live against the
deployed project — see below). `savings_home_page.dart` shows a real
"Platform Savings" stat and an "All SHGs" recent-entries list;
`savings_ledger_page.dart` shows a real cross-SHG pending-verification
queue (one-shot fetch, not the realtime stream the leader's own-SHG branch
uses — the same choice `loan_approval_page.dart` made, since Supabase
Realtime's `.stream()` API needs a specific row filter and an oversight
queue doesn't need sub-second freshness). Each row/card is tagged with its
SHG name. `Verify` itself needed no changes — already entry-scoped, not
viewer's-SHG-scoped. While adding this page's first-ever widget test, also
fixed a small, genuinely latent bug the new test surfaced: the ledger
page's member-name-roster fetch in `initState()` had no `.catchError`, so a
failed fetch was an *unhandled* Future rejection, not the silently-ignored
fallback its own comment claimed — harmless in a real app (Flutter's root
zone just logs it) but worth a one-line fix regardless. Live-verified
against the real deployed project: a real crp profile's cross-SHG
`select`/`update` on a `savings_entries` row it doesn't own succeeded (both
inside a rolled-back transaction); a real cross-SHG leader's identical
attempt returned 0 rows. **Still open**: the identical pattern in Meetings,
Financial Ledger, and Livelihood — see those sections' own notes.

| ID | Requirement | Roles |
|---|---|---|
| FR-SAV-1 | Member (or leader/staff for a roster member) records a savings entry, always starting `pending` | Member, Leader, staff |
| FR-SAV-2 | Member views own savings history and a running-balance statement (verified entries only) | Member |
| FR-SAV-3 | SHG members share realtime read access to the group's savings ledger | Member, Leader |
| FR-SAV-4 | Leader verifies a pending entry from her own SHG's queue (flat status flip; self-verification blocked as of round 190 — the button doesn't render for her own row); CRP/CLF/Admin verify platform-wide across every SHG (since round 168) | Leader, CRP, CLF, Admin |
| FR-SAV-5 | Member views a group savings report: per-member leaderboard and monthly trend, verified entries only (SHG transparency) — reached from Savings home's "Group" tile; leader/staff are routed to the ledger (FR-SAV-4) instead, not this report | Member |

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

**Known gap, confirmed live (2026-07-25, round 140): the "Leader/staff" and
"portfolio" language in FR-LOAN-2/5/6 below significantly overstates what
crp/clf/admin can actually do on this page today.** `loans_home_page.dart`'s
own data-fetching is `isLeaderOrStaff ? repo.fetchForShg(shgId) :
repo.fetchForMember(memberId)` — `shgId` is
`appState.profile?.shgId`, the *viewer's own* SHG. A leader has a real one;
federation staff (crp/clf/admin) never do (platform-wide roles, not
SHG-scoped — same fact behind round 138's Reports finding and round 139's
CLF-dashboard check). The result: every crp/clf/admin account sees the main
Loans page's "Group Outstanding" stat, "Pending Approval" count, and "All
Loans" list all render as zero/empty, while still being shown a real,
tappable "Pending Approvals" tile (`loans_home_page.dart` gates it on the
same `isLeaderOrStaff`) that leads to `loan_approval_page.dart` — which has
the identical `appState.profile?.shgId` bug and is *also* reachable via a
router-level `_leaderOrStaff` guard (`router.dart`) that lets staff straight
through. Unlike round 138's SHG Reports finding, this isn't fixable by
simply hiding a tile: `loans_home_page.dart` has no third rendering mode —
falling back to the member-shaped view (an "Apply for a Loan" button, "my
overdue" framing) would be equally wrong for a platform-wide oversight
role. The real fix is a genuine new capability: `LoanRepository` has no
platform-wide fetch method at all today (only `fetchForShg`/
`fetchForMember`) — RLS is already ready for one (`loans_select_shg_or_staff`'s
`is_staff()` branch already grants crp/clf/admin unrestricted read across
every SHG's loans, live-confirmed via `pg_policies`), so building a
`fetchAllPending()`/portfolio-style method and a staff-specific rendering
branch is a Dart/UI-only addition, no migration needed. Left undone here —
a genuine feature build (new repository method + a third UI branch,
possibly with a different approval-permission question for staff:
should any crp/clf/admin be able to approve any SHG's loan platform-wide,
or does that need narrowing?) rather than a one-line fix, matching this
project's established distinction (rounds 111, 135) between closing a
confirmed gap immediately and documenting one that needs a real design
decision for a dedicated development pass.

**Follow-up (2026-07-25, round 147): the *misleading-UI* half of the gap
above was fixed** — see the Savings gap note (§3.2) for the full nine-page
fix. `loans_home_page.dart` and `loan_approval_page.dart` showed an honest
"this per-SHG view doesn't apply to your role" message instead of the
silently-empty zero/portfolio state, gated on `SupabaseService.isConfigured`
so demo mode was unaffected. That fix explicitly did **not** close the
underlying capability gap — crp/clf/admin still couldn't approve a loan or
see a real portfolio through this UI at that point.

**Fixed (2026-07-26, round 168): the genuine capability itself is now
built — the honest dead-end message above is gone, replaced with a real
platform-wide portfolio and approval queue.** `LoanRepository.
fetchAllForStaff()` is the new platform-wide fetch this gap note always said
was missing — `select('*, profiles(name), shgs(name)')` with no `shg_id`
filter, relying on the same `loans_select_shg_or_staff` `is_staff()` branch
already confirmed live via `pg_policies`. `loans_home_page.dart` now shows a
real "Platform Outstanding" stat, a real platform-wide pending count, and an
"All Loans (All SHGs)" list (each row tagged with its SHG name, since a flat
cross-SHG list needs that to disambiguate two members who might share a
first name) whenever a crp/clf/admin account has no `shgId` of its own in
live mode. `loan_approval_page.dart` does the same for the pending-approval
queue, tagging each card with its SHG name.

**The second, previously-open product question this gap note raised —
"should any crp/clf/admin be able to approve any SHG's loan platform-wide?"
— resolved to yes, because it already was.** `loans_update_leader_or_staff`'s
`with check` clause (re-derived in migration `0023`, still current) is
`public.is_staff() or (...)` — an unconditional, unscoped grant, not narrowed
to the staff account's own SHG. Same for `loan_payments_insert_related`.
Building a narrower "staff can only act on SHGs assigned to them" model
would have been a real, separate feature (an assignment table that doesn't
exist yet) contradicting RLS already deployed and relied upon elsewhere in
this exact way (e.g. `AnalyticsRepository`'s cross-SHG reads) — so this
round's fix surfaces the capability RLS already grants, rather than
re-litigating it. `loan_detail_page.dart` and the approve/reject/
record-payment code paths needed **no changes at all** — they were already
loan-scoped, not viewer's-SHG-scoped, so they worked correctly for any loan
ID reachable from the new platform-wide list the moment that list existed.

**Live-verified against the real deployed project, not just reasoned about
from the policy text.** Impersonated a real crp profile (`begin; set local
role authenticated; set local request.jwt.claims ...`) and confirmed, inside
a transaction rolled back afterward: `select count(*) from public.loans`
returned 2 (both of the project's real loans, both belonging to a SHG this
crp is not a member of), and `update ... where id = <the other SHG's loan>
returning 1` genuinely affected 1 row — not a read of `pg_policies`, an
actual cross-SHG write. Negative control in the same session: a real leader
of a *different* SHG (not staff) querying/updating that same loan got 0 rows
both times, confirming `is_staff()` — not some accidentally-broader
condition — is what's granting the staff account's access. No fixtures
created (reused existing rows); both checks rolled back, re-queried
outside any transaction afterward to confirm the loan's `outstanding` was
genuinely untouched.

| ID | Requirement | Roles |
|---|---|---|
| FR-LOAN-1 | Member applies for a loan (purpose, amount, tenure); starts `pending`, fully undisbursed | Member |
| FR-LOAN-2 | Leader approves (setting EMI, disbursement date) or rejects a pending application — from her own SHG's queue (Leader), or platform-wide across every SHG (CRP/CLF/Admin, since round 168) | Leader, CRP, CLF, Admin |
| FR-LOAN-3 | A leader cannot approve/reject her own loan application — enforced at the database layer, not just hidden in the UI | System |
| FR-LOAN-4 | Member tracks her own loan(s): outstanding balance, EMI, status, payment history | Member |
| FR-LOAN-5 | Non-member roles record a payment against a loan; balance decrement, overpayment rejection, and auto-close-on-zero happen atomically | Leader, CRP, CLF, Admin |
| FR-LOAN-6 | Leader views her SHG's loan list with status badges; CRP/CLF/Admin view a platform-wide portfolio across every SHG, each row tagged with its SHG name (since round 168) | Leader, CRP, CLF, Admin |
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
post new entries. **Correction (round 197): the claim below this used to say
"no UI path or RLS policy permits editing or deleting an already-posted row"
— that was never accurate for the RLS layer** (per this project's own
security model, "no UI path" only describes the app's screens, not what a
direct REST call can do). No app screen exposes editing/deleting a ledger
row, but `financial_ledger_update_staff`/`financial_ledger_delete_staff` are
real, staff-only RLS policies reachable via direct REST: UPDATE locks every
real column and self-excludes the author (round 193); DELETE self-excludes
the author and, since round 194, is further restricted to only the single
most-recent row in a `(shg_id, entry_type)` chain (via `financial_ledger_
is_latest()`) — specifically because deleting a mid-sequence row would
desync every later row's chained balance with no trace, exactly the scenario
this paragraph's original wording described as structurally impossible when
it was actually just unexploited.

**Fixed (2026-07-26, round 168): crp/clf/admin (no `shgId` of their own) now
see a real platform-wide feed across all four record types, same fix
template as §3.3/§3.4/§3.7's Savings/Loans/Livelihood notes.** Round 147's
nine-page sweep had already replaced this shared page's silently-empty
zero-state with an honest "doesn't apply to your role" message, but left the
underlying capability unbuilt (undocumented here at the time — an oversight
this note corrects). `FinancialEntry` gained an optional `shgName`;
`FinancialRepository.fetchAllForStaff(entryType)` is the new platform-wide
fetch (`financial_ledger_select_shg_or_staff` was already unconditionally
`is_staff()`-granted, live-confirmed: a real crp profile's cross-SHG select
against a SHG it isn't a member of returned the real row count, inside a
rolled-back transaction). **Needed one design decision the other three
modules didn't**: `balance` is a per-SHG running total, so a flat cross-SHG
list without a visible SHG tag would show the number jumping between
unrelated SHGs' balances with no explanation — every row is tagged with its
SHG name to make that expected, not confusing. The Add-entry button is
hidden for the platform-wide view — not a new permission restriction (staff
already had unconditional `is_staff()` insert rights), just that there's no
"which SHG" picker for a platform-wide staff account to post against.

| ID | Requirement | Roles |
|---|---|---|
| FR-FIN-1 | Leader posts a ledger entry (description, amount, credit/debit) to one of Cashbook/Ledger/Bank/Audit; CRP/CLF/Admin can post too (RLS `is_staff()`-unconditional) but have no SHG of their own to post against | Leader |
| FR-FIN-2 | Running-balance computation and insert happen atomically per `(shg_id, entry_type)`, race-safe under concurrent postings | System |
| FR-FIN-3 | All SHG members have read access to the ledger; CRP/CLF/Admin see a platform-wide feed across every SHG, each row tagged with its SHG name (since round 168); no client path exists to edit or delete a posted entry | Member, Leader, CRP, CLF, Admin |

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

**Fixed (2026-07-26, round 168): crp/clf/admin (no `shgId` of their own) now
see a real platform-wide meeting feed and attendance picker, same fix
template as §3.3/§3.4/§3.5/§3.7's Savings/Loans/Financial Ledger/Livelihood
notes.** `Meeting` gained an optional `shgName`; `MeetingRepository.
fetchAllForStaff()` is the new platform-wide fetch
(`meetings_select_shg_or_staff` was already unconditionally `is_staff()`-
granted). `meetings_home_page.dart` shows a real cross-SHG upcoming/past
feed; `meeting_attendance_page.dart` shows a real cross-SHG meeting picker
that a staff account can mark attendance for — each meeting/row tagged with
its SHG name.

**Fixed (2026-08-18): `meeting_schedule_page.dart` now has a genuine
cross-SHG picker too, closing the one remaining dead end in this module.**
Every other write path here (attendance marking) was already platform-wide
for staff, but scheduling itself stayed hard-blocked behind
`commonStaffNoShgMessage` — and since attendance can only ever be marked for
a meeting that already exists, an SHG with no leader account yet on record
(a real, live-observed state, not a hypothetical) could never get a meeting
scheduled by *anyone*, permanently locking out the entire attendance feature
for that SHG despite staff being fully RLS-authorized to operate it
(`meetings_insert_leader_or_staff`'s unconditional `is_staff()` branch).
`meeting_schedule_page.dart` now shows a real SHG picker (`ShgRepository.
fetchAllShgs()`, RLS-readable by any staff role via `shgs_select_own_or_staff`)
for crp/clf/admin, and schedules against whichever SHG they pick instead of
their own (always-null) `shgId`. A leader with a genuinely broken/unlinked
account still gets the hard block — that part was never the gap.

**Found and fixed a real latent bug while building this, previously
unreachable and so invisible until now**: `meeting_attendance_page.dart`,
`meeting_detail_page.dart`, and `meeting_mom_page.dart` all resolved a
meeting's roster/attendance using the *viewer's own* `shgId`, not the
*selected meeting's own* `shgId`. For a leader these always coincided (she
could only ever reach her own SHG's meetings before this fix), so it was
invisible — but the moment a platform-wide staff account can reach a real
cross-SHG meeting (exactly what this round's fix enables), passing the
viewer's `shgId` (`null` for staff) into `fetchAttendance`/`fetchRoster`
would have silently returned an empty roster for a meeting that genuinely
has one. Fixed all three call sites to use `meeting.shgId` instead — a
strict correction for every role, not a platform-wide-only special case.

**Live-verified against the real deployed project.** A real crp profile's
cross-SHG `select` against `meetings`/`meeting_attendance` for a SHG it
isn't a member of returned the real row counts (2 meetings, 3 attendance
rows), and an `update` against one of those attendance rows genuinely
affected 1 row — all inside a rolled-back transaction. Negative control: a
real leader of a *different* SHG (not staff) got 0 rows on the identical
select/update.

**Correctly left unbuilt, not a gap**: `meeting_qr_page.dart` (member
self-check-in) keeps its existing "doesn't apply to your role" message for
crp/clf/admin, and that's the right permanent answer, not a stand-in for an
unbuilt capability. Self-check-in is inherently personal — "mark myself
present at my own SHG's meeting happening today" — and a platform-wide
staff role has no "own SHG" to check into. Unlike the other four modules'
gap, there is no genuine platform-wide capability to build here.

| ID | Requirement | Roles |
|---|---|---|
| FR-MTG-1 | Leader schedules a meeting (date/time/venue/agenda) for her own SHG; CRP/CLF/Admin do the same for any SHG via a picker (since 2026-08-18) | Leader, CRP, CLF, Admin |
| FR-MTG-2 | Any member self-checks-in (via QR gesture or a plain button — functionally identical) for whichever meeting is scheduled *today* — inherently personal/SHG-scoped, correctly not extended to platform-wide staff | Member |
| FR-MTG-3 | Leader marks/edits the attendance roster via per-row toggle for her own SHG; CRP/CLF/Admin do the same platform-wide across every SHG, via a cross-SHG picker (since round 168) | Leader, CRP, CLF, Admin |
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

**Fixed (2026-07-26, round 168): crp/clf/admin (no `shgId` of their own) now
see a real platform-wide activity feed, same fix template as §3.3/§3.4's
Loans/Savings notes.** Round 147's nine-page sweep had already replaced
`livelihood_home_page.dart`'s silently-empty zero-state with an honest
"doesn't apply to your role" message, but — like Loans/Savings — that left
the underlying capability unbuilt. `LivelihoodActivity` gained an optional
`shgName`; `LivelihoodRepository.fetchAllForStaff()` is the new
platform-wide fetch (`livelihood_select_shg_or_staff` was already
unconditionally `is_staff()`-granted, live-confirmed: a real crp profile's
cross-SHG `select count(*)` against a SHG it isn't a member of returned 2,
inside a rolled-back transaction). Each row is tagged with its SHG name
when viewed platform-wide. `updateProgress()` needed no changes — already
activity-scoped, not viewer's-SHG-scoped.

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
before this feature shipped). Placing an order calls an atomic RPC (`place_marketplace_order`, migration
`0057`) that, in one `security definer` transaction, decrements stock in a
single guarded statement (`stock - 1 where stock > 0`), reads the product's
real current price, and inserts the order itself — buyer identity
(`buyer_id`/`buyer_name`) is derived server-side from the session, never
accepted from the client. This closes two real, previously-live bugs, both
live-confirmed rather than just reasoned about: a buyer's own client-side
stock decrement was always a silent 0-row RLS no-op (only the seller/staff
may write to the product row) until an earlier RPC (`decrement_product_stock`,
migration `0008`) fixed the decrement itself — but that RPC only verified a
price and handed it back for the client to insert the order with
*separately*, a non-atomic two-step sequence nothing forced a client to
actually follow honestly. A direct API call could skip straight to
inserting the order with an arbitrary `amount` and stock never touched (a
real ₹5,000 test product was ordered at `amount: 1` this way), and the old
RPC was independently callable on its own with no order at all, letting any
authenticated user silently zero out any seller's stock as a pure
denial-of-service. `place_marketplace_order` closes both by performing the
entire purchase — not just the price-sensitive part — inside one function,
so there is no longer a gap between "stock/price verified" and "order
recorded" for a client to skip or forge.

**Order history** is visible to both sides of a purchase: `MarketplaceOrdersPage`
carries "My Purchases" and "My Sales" tabs, backed by
`fetchOrdersForBuyer`/`fetchOrdersForSeller` respectively. Buyers can see their
own order status; there is no buyer-initiated cancellation yet (would need a
new `'cancelled'` status plus a stock-restore RPC).

**Order status** (`new → packed → shipped → delivered`) is set by the seller
(or staff) via a chip row in the UI, but — unlike this section's own earlier
description — is guarded server-side since round 194: the seller's own RLS
`WITH CHECK` permits only a one-step forward-or-back transition per update
(a genuine "correct a mistake" design, not free-form), while staff retains
an unrestricted override for dispute resolution, gated only by a
self-exclusion (a staff account cannot force-transition her own purchase,
closed in round 199 after an audit found staff could otherwise force any
order straight to `'delivered'` and immediately post a "verified purchase"
review with no real fulfillment wait).

**Review eligibility is enforced at the database layer, not the UI**: posting
a review requires an existing order for that exact product under the
reviewer's own identity — you must have actually bought the product. A
partial unique index limits one review per reviewer per product. This
replaced an earlier, more permissive policy that let *anyone*, authenticated
or not tied to a purchase, post unlimited reviews under any free-text name —
closed before the "Write a Review" UI existed, specifically to prevent
self-boosting or rival review-bombing from ever becoming exploitable once it
shipped.

**Seller payment details + manual UPI pay (2026-08-18).** There is no real
payment gateway anywhere in this app (no gateway credentials exist to
integrate one) — placing an order has only ever recorded a sale, never
collected money. A seller can now add a UPI ID and an optional free-text
payment note (bank details, cash-on-delivery instructions, etc.) to her
listing (`marketplace_products.upi_id`/`payment_note`, migration `0150`); a
buyer sees these on the product detail page and can tap "Pay via UPI" to
open her own UPI app pre-filled (`upi://pay?pa=...&pn=...&am=...&cu=INR`,
via `url_launcher`) before placing the order through the existing flow —
this mirrors the manual-UPI-record pattern this app already uses for SHG
savings payments (`payments_qr_page.dart`), since a real gateway isn't
buildable without credentials. There is deliberately no payment-reference/
order linkage yet — the buyer confirms payment manually, and the seller
confirms receipt out-of-band, same as any real small-vendor UPI collection
today. Any user can view a product's payment details; they're not exposed
through any separate broadly-readable surface beyond the product row itself
(matching this schema's existing "sensitive-field" hygiene for other
tables).

**Seller listing management ("My Listings", 2026-08-18).** `Marketplace
Repository.fetchMyProducts()` existed with zero UI callers before this — a
seller could list a product but never edit its price/stock/photo/payment
details, or take it down. `MyListingsPage` now lists a seller's own
products with Edit and Delist/Relist actions. Sellers have **no DELETE
right** on `marketplace_products` (staff-only, and staff are excluded from
deleting their own too — hardened specifically so a seller can't erase a
listing's order/review history by deleting the row it hangs off of) — so
"delist" is a soft `is_active` flag toggled via the seller's existing
UPDATE rights, not a real delete. A delisted product hides from the general
catalog (`marketplace_products_select_all`'s RLS now requires `is_active`
on top of the seller being active) but stays fully visible to its own
seller and to staff, and a buyer with a pre-existing order on it keeps
seeing it (regression-tested against the `buyer_has_order_for_product`
visibility branch). `place_marketplace_order()` independently rejects an
order against a delisted product server-side — the UI already disables
"Place Order" for one, but RLS/RPC remains the real authorization boundary
here, not client-side hiding.

| ID | Requirement | Roles |
|---|---|---|
| FR-MKT-1 | Member/seller lists a product (name, description, price, stock, category, optional UPI ID + payment note) | Member, Leader |
| FR-MKT-2 | Any user browses the cross-SHG product catalog and product detail; a delisted product is hidden from general browsing but stays visible to its own seller, staff, and a past buyer | All |
| FR-MKT-3 | Any user places an order; stock decrement, price-locking, and the delisted-product check happen atomically | All |
| FR-MKT-4 | Seller sets order status one step forward/back at a time (RLS-guarded); staff may override to any value for a dispute they don't personally own | Member, Leader (seller), staff |
| FR-MKT-5 | Only a verified past buyer of the specific product may post a review; one review per reviewer per product | All |
| FR-MKT-6 | Review moderation (edit/delete another user's review) is staff-only | Staff |
| FR-MKT-7 | Seller edits her own listing (including payment details) or delists/relists it via "My Listings"; sellers cannot delete a listing outright | Member, Leader (seller) |
| FR-MKT-8 | Buyer sees a seller's UPI ID/payment note on the product detail page and can open her own UPI app pre-filled to pay manually — no real payment gateway, no order-payment linkage | All |

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

**Eligibility is enforced, not just displayed.** `SchemeDetailPage`'s Apply
button itself is disabled with the itemized failing reasons shown inline
when criteria aren't met — a member can't reach the apply flow at all on a
scheme she doesn't qualify for. This is independently re-verified at the
database layer too: `scheme_applications_insert_self`'s `WITH CHECK` calls
the same `scheme_eligibility_met()` function the UI evaluates against, so a
direct API call bypassing the UI is rejected identically — mirroring the
deadline check's own already-documented RLS re-verification above.

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
"Continue" button — this remains an intentional placeholder, independent of
whether a course's attached video was actually watched (no scroll tracking
either, for PDF/Audio-labeled courses); two taps takes any course from 0% to
100%. Certification is entirely separate from that progress number: it is
granted only by passing a quiz, reachable at any time regardless of
displayed progress.

**Closed: real video upload + in-app playback (migration `0115`).** A staff
member (crp/clf/admin) can now attach an actual video file to a course from
"Manage Training Courses" — `TrainingRepository.uploadCourseVideo` uploads it
to a new public `training-videos` storage bucket (staff-write, public-read,
200 MiB cap, MP4/WebM/MOV allow-list) and stores the resulting permanent URL
on `training_courses.video_url`. `CourseDetailPage` renders a real player
(`TrainingVideoPlayer`, built on `video_player`/`chewie` — play/pause/seek/
fullscreen controls, works on Flutter Web) whenever a course has a video
attached, replacing what used to be no content viewer of any kind regardless
of `format`. The "+50%-per-tap" progress button above is unchanged and stays
fully decoupled from actual video-watch behavior — playing a video to
completion does not itself advance progress or certify the course.

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
course), capped at 5 attempts per course per calendar day (server-enforced,
`submit_quiz_attempt`/`quiz_attempt_counters`, migration 0070 — a retry
beyond the cap raises rather than silently succeeding; the UI surfaces this
as a specific "try again tomorrow" message, not the generic quiz-submit
error). Passing upserts
`certified:true` and a completion date — this is the *only* path to
certification; reaching 100% progress via the Continue button does not by
itself certify a course. This seeded content is a genuine starting set, not
a transcription of any real curriculum — a subject-matter expert should
review/extend it before this is treated as the app owner's final course
material.

**Closed (2026-07-26, round 167): "Manage Training Courses" admin UI now
exists** — `admin_training_courses_page.dart` (course catalog: add/edit/
delete) plus `admin_training_quiz_page.dart` (per-course quiz question
authoring: question text, 2+ options, correct answer), mirroring
`admin_schemes_page.dart`'s pattern. Reachable from Admin's dashboard tile
and every staff role's Services tab. **Gated on `is_staff()` (crp/clf/admin),
not narrowed to `Role.admin`-only like `admin_schemes_page.dart`** — CRPs
are this app's actual day-to-day training content owners per this
document's own role glossary, and RLS (`training_courses_write_staff`/
`quiz_questions_write_staff`) already scoped writes to `is_staff()`, so an
admin-only gate would have left that already-granted capability just as
unreachable for crp/clf as before this page existed; a dedicated router
prefix (`/app/training/manage`, deliberately not nested under `/app/admin`)
carries this narrower rule. The prior round's live-verified emptiness is
now directly closable: a staff account can create a course and its quiz
content without touching SQL, and every write was live-RLS-boundary-tested
(a real crp-role session's insert into `training_courses` genuinely
succeeded; a real member-role session's identical insert genuinely raised
`42501` — both against the live linked project, not assumed).

One remaining rough edge, honestly disclosed rather than hidden: editing an
*existing* quiz question's correct answer requires re-selecting it (not
pre-filled) unless migration `0060_quiz_questions_staff_base_table_read.sql`
has been deployed — that migration re-grants staff read access to the base
`quiz_questions` table (needed only to show a saved correct answer back to
an editor; ordinary quiz-taking was never affected) and was written but not
yet pushed to the live project (`supabase db push` requires the project
owner's own action — see [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)
round 167). Creating new questions and deleting existing ones already work
fully today regardless.

**Second known gap, found the same way (2026-07-25, round 135): the
aggregate training-completion view this section's own FR-TRN-5 row
promises CRP/CLF is Admin-only in practice.** `AdminRepository.
fetchDashboardStats()` computes `trainingCompletionPct`
(`course_progress.progress` averaged across every member×course pair
platform-wide, via the same `is_staff()` RLS bypass every other
platform-wide aggregate in this app uses) — but it's called from exactly
one place, `admin_dashboard.dart`. Grepped the whole `lib/pages/` tree for
any other call site and for `trainingCompletionPct` itself: neither
`crp_dashboard.dart` nor `analytics_dashboard_page.dart` (the two
CRP/CLF-reachable dashboards) reference it at all. The underlying RLS is
already correctly staff-wide, not admin-scoped, so nothing here is a
security gap — this is purely a UI capability the original spec described
that was only ever wired to one of the three roles it names. Left as a
documented gap rather than built on the spot: `AdminDashboardStats` also
bundles `pendingReviewCount` and an admin-flavored `recentActivity` feed
(new users/new SHGs platform-wide) in the same call, so cleanly extending
just the training-completion figure to CRP/CLF is a real product/design
decision (what subset of that bundle actually belongs on their dashboard,
not just a mechanical wiring fix) — a good candidate for this project's
CRP/CLF-role development pass, alongside the courses/quiz-authoring gap
above.

**Fixed (2026-07-26, round 168): the design decision above resolved to "just
the stat, on its own."** `AdminRepository.fetchTrainingCompletionPct()` is a
new standalone method — the exact computation `fetchDashboardStats()`
already did, split out behind its own call site rather than refactoring the
bundled method's public shape (both now call the same shared logic; no
behavior change for the Admin dashboard, confirmed by the existing
`admin_dashboard_stats_test.dart` suite still passing unmodified).
`crp_dashboard.dart` and `clf_dashboard.dart` each gained a "Training
Completion" stat card wired to it — deliberately **not** pulling in
`pendingReviewCount`/`recentActivity`, matching this note's own original
scoping. Both dashboards already computed everything else client-side with
no server round trip of their own for this figure before; now it's one more
parallel `Future.wait` entry, same pattern each file already used for its
existing repository calls.

| ID | Requirement | Roles |
|---|---|---|
| FR-TRN-1 | Any user browses the course catalog and course detail | All |
| FR-TRN-2 | Progress advances via a flat increment per "Continue" tap — not real content-consumption tracking | All |
| FR-TRN-3 | A real per-course quiz (`quiz_questions` table) is the sole path to certification, proportional ≥2/3 pass threshold, capped at 5 retries per course per day | All |
| FR-TRN-4 | A certificate/completion date is issued on quiz pass | All |
| FR-TRN-5 | Aggregate training-completion view, now a real standalone stat on each of the three staff dashboards (since round 168) | CRP, CLF, Admin |
| FR-TRN-6 | Staff/admin author courses and quiz questions via `admin_training_courses_page.dart`/`admin_training_quiz_page.dart` (since round 167) | CRP, CLF, Admin |

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
optional, plus a `category` picked from a fixed 9-value list — general,
savings, loans, meetings, livelihood, marketplace, payments, account, other)
— status defaults to `open` at the database level and is never set explicitly
by the client, and `priority` (low/normal/high/urgent) defaults to `normal`
and stays staff-only to change. The ticket becomes a threaded, chat-style
conversation (`support_messages`, a flat append-only table rendered as chat
bubbles, capped at 500 chars per message and rate-limited to 20 messages per
10 minutes) with no realtime subscription — a reply from the other party
appears only on the next reload, not live. **Visibility is enforced twice**:
the client shapes its query differently for staff (no member filter — sees
every ticket platform-wide, capped at 500, with a search box + status-filter
row to narrow that list) versus a member (filtered to her own), and —
independently, as the actual boundary — RLS restricts a non-staff caller's
read to her own tickets regardless of what query shape the client sends.
Moving a ticket to `resolved`/`closed` — or changing `priority` — is
staff-only, both in the UI and at the RLS layer — closing a gap where a
member could otherwise self-close her own complaint via a direct API call
even though no UI ever exposed that action. The list is ordered by
`updated_at` (bumped by any ticket-field change AND by any new message on it,
via a security-definer trigger — a reply alone doesn't otherwise touch
`support_tickets`), not `created_at`, so a resolved-then-replied-to ticket
resurfaces at the top of the staff queue instead of staying buried at its
original creation time. **The ticket's own filer can reopen it**: moving
`resolved`/`closed` back to `open` is a member-writable transition (round
188/migration `0093`) — but only that one direction; a member can never move
a ticket directly to `resolved`/`closed`, which stays exclusively staff's to
set, and every other column (subject/description/category/priority/
member_id/resolved_by) stays locked on the member's own reopen branch.
Moving a ticket to `resolved`/`closed` records which staff account did it and
when (`resolved_by`/`resolved_at`, mirroring `shg_join_requests.decided_by`
and `scheme_applications.decided_by`/`decided_at`) — the timestamp is
stamped server-side by a trigger rather than trusted from the client, and
staff reopening an already-resolved ticket is likewise supported even when
done by a different staff member than the one who resolved it. `resolved_by`
can only ever be set to the calling staff account's own id (or left at
whatever it already was, covering reopen/other-status-change updates) — a
staff account cannot attribute a resolution to a colleague who never touched
the ticket (migration `0058`; live-confirmed round 128, after an earlier,
simpler pin shipped and was reverted in migration `0053` for incorrectly also
blocking the reopen workflow above).

FAQs are fully static content, not backed by any table. Voice Support follows
the same "record → transcribe → answer" state machine as the AI Voice
Assistant, backed by real on-device speech-to-text/text-to-speech
(`speech_to_text` + `flutter_tts`) in live mode, with a mock speech service
retained for demo mode — see [AI_MODULES.md](AI_MODULES.md) §3 for the shared
real/mock pattern.

| ID | Requirement | Roles |
|---|---|---|
| FR-SUP-1 | Any user browses static FAQ content | All |
| FR-SUP-2 | Any user raises a categorized ticket and follows a threaded (non-realtime) chat conversation | All |
| FR-SUP-3 | Any user accesses voice-based support (real on-device STT/TTS in live mode, mocked in demo mode, real underlying data where applicable) | All |
| FR-SUP-4 | A member sees only her own tickets; staff see all tickets platform-wide (capped at 500, with search/status-filter) — enforced independently at the RLS layer | Member vs. CRP/CLF/Admin |
| FR-SUP-5 | Resolving/closing a ticket and changing its priority are staff-only, both client-side and at RLS; a member may only reopen her own resolved/closed ticket back to `open` | Member (reopen only) vs. Staff |

### 3.14 AI Advisory (`ai/`)

Full technical detail — architecture, exact system prompts, rate limiting,
the Voice Assistant's real on-device STT/TTS, and an honest safety/moderation
accounting — is in the dedicated [AI_MODULES.md](AI_MODULES.md) document.
Summary for SRS purposes:

| ID | Requirement | Roles |
|---|---|---|
| FR-AI-1 | User chats with an AI Financial Advisor (Groq-backed), with real cross-turn memory within the current chat session (resets on leaving/reopening the page) | All |
| FR-AI-2 | User chats with an AI Scheme Recommender | All |
| FR-AI-3 | User chats with an AI Market Advisor | All |
| FR-AI-4 | User interacts with a Voice Assistant in English/Hindi/Telugu — **real on-device speech recognition and synthesis in live mode** (`speech_to_text` + `flutter_tts`, no vendor key), falling back to a mock speech service in demo mode; answer content for recognized intents is drawn from the user's real data | All |
| FR-AI-5 | Every chat-advisor exchange (not Voice Assistant) is logged for audit, retained indefinitely, staff-readable | System |
| FR-AI-6 | Chat-advisor requests are rate-limited server-side to 10/minute per member, fail-closed | System |
| FR-AI-7 | A persistent, localized disclaimer ("AI-generated guidance… not professional financial, legal, or medical advice") is shown on every AI-branded screen; a real two-layer server-side content-moderation/prompt-injection defense exists (regex pre-filter + a Groq Llama Guard 3 ML classifier, both on input and output), every rejection is logged and staff-visible on Admin Monitoring — **still missing gradual cross-turn abuse detection and proactive alerting/escalation on repeated blocks**, disclosed explicitly as the remaining pre-scale gap (see [AI_MODULES.md](AI_MODULES.md) §6 for the full accounting) | — |

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

**Fixed live, round 138 (2026-07-25): the "SHG Reports" tile (Financial
Summary/Audit Report/Performance Report) is leader-only, not
"leader-or-staff" as this section previously claimed.** All three pages
resolve which SHG to show purely from `appState.profile?.shgId` — the
*viewer's own* SHG — with no parameter for viewing a different one. A
leader has a real SHG there; crp/clf/admin never do (staff roles are
platform-wide, not SHG-scoped). Before this fix, `reports_hub_page.dart`
showed this tile to staff too (gated on `isLeaderOrStaff`, i.e. "not a
member"), so every crp/clf/admin account saw a tappable "SHG Reports" tile
that led to three report pages rendering permanently empty/zero with no
explanation and no way to ever reach a real SHG's data through that flow —
an always-reproducible dead end, not a rare edge case, for exactly the
roles this section's own FR-RPT-2 claimed the capability served. Closed by
scoping the tile to `role == Role.leader` only; staff's genuinely-working
per-SHG oversight is the Analytics drill-down below (FR-RPT-3), which does
take an explicit `shgId` and was live-verified against a real second SHG.
Extending the report *pages* themselves to accept an explicit `shgId` (so
staff could reach a specific SHG's Financial Summary/Audit/Performance via
an "Analytics → view full report" link) remains open — a reasonable future
enhancement, not implemented here since it's a multi-page feature addition
rather than a one-line fix.

**Fixed (2026-07-26, round 171): that "remains open" line above is now
closed for two of the three named reports — Financial Summary and
Performance Report.** The Audit Report was already closed as a side effect
of round 169's Financial Ledger fix (the "Audit Report" tile has always
routed to `FinancialLedgerPage(entryType: 'audit')`, which gained a real
platform-wide staff feed that round). `ShgFinancialSummaryPage`/
`ShgPerformanceReportPage` gained optional `shgId`/`shgName` constructor
params that override the viewer's own SHG when provided — both pages
already resolved their data via `ReportRepository.fetchShgReport(shgId)`/
`TrendRepository.attendanceTrend(shgId:)`, which take any explicit `shgId`
and were never viewer-bound at the repository layer (unlike Loans/Savings/
Livelihood/Financial Ledger/Meetings in rounds 168-170, this needed **no**
new repository method — every underlying table's SELECT policy
(`profiles`/`savings_entries`/`loans`/`meeting_attendance`, all already
`is_staff()`-unconditional) already supported an arbitrary `shgId` read;
the page itself just never accepted one as input). `AnalyticsShgDetailPage`
(crp/clf/admin's existing per-SHG oversight screen, which already resolves
an explicit `shgId`) gained two new "View Financial Summary"/"View
Performance Report" cards linking to new routes (`/app/analytics/shg/:id/
financial-summary`, `/app/analytics/shg/:id/performance`) — nested under
the existing `/app/analytics` prefix, which was already staff-only
restricted at the router level, so no new role-table entry was needed. The
SHG's name is passed through as a query parameter and shown in each
report's header subtitle, so a staff account always knows whose report
they're looking at, never confusable with their own (staff have none).

**Live-verified the one table not already spot-checked in rounds 168-170's
stretch**: `profiles` (used for `memberCount`). A real crp profile's
cross-SHG `select count(*)` against a SHG it isn't a member of returned 4
(the real count); a real leader of a *different* SHG got 0 on the identical
query. `savings_entries`/`loans`/`meeting_attendance` (this report's other
three sources) were already live-verified in rounds 168-170.

| ID | Requirement | Roles |
|---|---|---|
| FR-RPT-1 | Any user views her own personal report hub: Savings Statement, Loan Statement, Attendance Report | All |
| FR-RPT-2 | Leader views her own SHG's reports: Financial Summary, Audit Report, Performance Report (with attendance trend chart); CRP/CLF/Admin reach any SHG's version of all three via its Analytics detail page (since round 171 for Financial Summary/Performance, round 169 for Audit) | Leader, CRP, CLF, Admin |
| FR-RPT-3 | CRP/CLF/Admin view platform-wide analytics: KPIs, SHG list with health/grade (an attendance-based proxy, not a certified metric), SHG detail drill-down | CRP, CLF, Admin |
| FR-RPT-4 | CRP/CLF/Admin view federation-wide reports: growth, recovery rate, villages | CRP, CLF, Admin |

### 3.16 SHG (Group) Management (`shg/`)

**How it works.** "My SHG" shows the group's profile, a federation-info card,
and — client-gated to non-member roles only — a Bank Details card. That
client gate is backed server-side, not just cosmetic: `bank_account`/`ifsc`
live in their own `shg_bank_details` table (migration `0056`), with RLS
restricted to that SHG's leader or staff — no policy grants an ordinary
member's role any path to those two columns at all, direct-table or
otherwise. `ShgRepository.fetchShg()` reads `shg_own_masked` (migration
`0045`), a view over `shgs` left-joined to `shg_bank_details` that additionally
nulls both columns server-side unless the caller is leader/staff, so even a
leader/staff row's own fields are masked correctly for any other caller
querying the same view. See [ARCHITECTURE.md](ARCHITECTURE.md) §"Sensitive
columns never in a broadly-readable view" for the full RLS design and the
direct-base-table-bypass this table split closed.

Federation info (Village Organisation/CLF/Mandal/formation date) and bank
details (bank name/account/IFSC) were displayed on this page from the start
but had **no write path anywhere in the app** until a live user bug report
("my SHG page shows nothing") surfaced that every one of these fields was
genuinely `null` for the app's SHG, with no way for any role to ever set
them. Fixed with two write paths matching the RLS shape exactly:
`AdminShgsPage`'s Add/Edit dialogs now cover all six fields (admin is the
only role that can ever set `grade`/`clf`/`vo` — `shgs_update_leader_or_
staff`'s `with check`, migration `0082`, locks those three to the row's
current value for the leader branch); and a new leader-only self-service
edit (pencil icon on "My SHG"'s header) lets the SHG's own leader set
`mandal`/bank details herself, matching exactly what RLS already left open
to her (everything except grade/clf/vo). A CRP/CLF never sees this icon —
`shgs_update_leader_or_staff` has no branch for them at all, only
leader-of-own-SHG or admin.

Join-request approval is a leader-only screen; the underlying RPC
(`approve_shg_join_request`) also accepts staff, even though the router
restricts the *page* to leaders only. Approving now also lets the reviewer
choose to grant the requester `leader` instead of `member` — this is the
*only* way any account ever becomes a leader (see §3.1); a peer leader
reviewing her own SHG's queue can only approve as member or reject, since
minting a co-leader is reserved for staff. A rejected request's row is
immutable — there is no re-decision path; a member must file a fresh request
(with any prior pending request from her automatically superseded/deleted to
satisfy a one-pending-per-member constraint).

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
| FR-SHG-3 | Leader (or staff, via the same RPC) approves/rejects join requests; approving may promote the requester to Leader (staff-only) instead of Member; a rejected request cannot be re-decided | Leader, staff |
| FR-SHG-3a | A new pending join request is surfaced on the reviewer's own home dashboard, not just discoverable by navigating to Members/Analytics first — leader sees a badge on her Members tile plus a "Pending Join Requests" preview section (her own SHG only); crp/clf/admin each see a federation-wide "N join requests pending" banner (hidden entirely at 0) linking to a dedicated cross-SHG list showing every pending request with its SHG name | Leader, CRP, CLF, Admin |
| FR-SHG-4 | Document repository requires and uploads a real file (PDF/JPEG/PNG/WEBP, 10 MB cap) to Supabase Storage; downloads via a short-lived signed URL | Leader, staff |
| FR-SHG-5 | Bank account/IFSC are hidden from members in the UI **and** independently RLS-restricted from them at the table level (`shg_bank_details`, migration `0056`) — a direct `/rest/v1` query bypassing the client gets the same masking, not just a hidden UI section | — |
| FR-SHG-6 | Leader edits her own SHG's Mandal/Bank Name/Account/IFSC via a self-service dialog; Admin edits all six SHG fields (adding VO/CLF/grade, which are leader-locked) via Manage SHGs | Leader, Admin |

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

Admin can also **deactivate/reactivate an account** (two-step confirm, same
caution as role change) — this is the offboarding path for a member who
leaves a real SHG, previously entirely missing (the only alternatives were a
permanently stale account or a hard delete that this schema's own `on delete
restrict` FKs would either block or use to destroy historical loan/savings
records). Deactivation is enforced server-side: the 4 RLS identity-resolution
helpers (`current_role()`/`current_shg_id()`/`is_staff()`/
`is_leader_or_staff()`) resolve to null/false for a deactivated caller,
blocking most further reads/writes regardless of client behavior, and the
app itself detects its own deactivated profile on load and redirects to a
dedicated explanation screen rather than continuing to navigate an app that
silently rejects almost everything. Historical records (savings, loans,
meetings) are untouched — this is a status flag, not a delete.

Manage SHGs lets an admin create SHG records — this exists specifically
because the underlying RLS policy (`shgs_insert_staff`) permits *any* staff
role to create an SHG, but no other client anywhere called it, which was a
real onboarding blocker on a fresh deployment with zero seeded SHGs. Manage
Schemes supports full create/edit/delete, restricted to `admin` at the RLS
layer specifically (stricter than the SHG-creation policy, which is
any-staff).

System Monitoring shows **real row counts** from `profiles`/`shgs`/
`savings_entries`/`loans` (not synthetic numbers), plus real infrastructure
metrics — uptime, average/p95 latency, error rate, and a rolling 24h check
count (so a dead cron schedule is itself visible, not just masked as
100% uptime) — from the `system-health-check` Edge Function (see
`docs/ARCHITECTURE.md`'s Edge Functions section). That function runs a
genuine synthetic database round-trip check, both on a pg_cron schedule
(every 5 minutes) and on-demand every time a viewer opens this page, and
logs each result to `public.infra_health_checks`. Reachable by any
federation staff role (crp/clf/admin) — both the RLS policy and the edge
function's own `authorizeCaller()` were already staff-wide; the router
briefly (through gap-hunt iteration 36) blocked crp/clf regardless, since
the page lived under the admin-only `/app/admin` prefix — it now sits at
its own `/app/monitoring` route with a staff-wide restriction, matching
the access every other layer already granted. The UI's own "About
these metrics" note honestly scopes this as OUR OWN backend round-trip,
not a full third-party APM's view of every layer of the stack (CDN, DNS,
client rendering, etc.) — that broader claim would need a real APM vendor
and remains out of scope. This honest-scope framing must be preserved in
any future redesign of this screen, the same way the AI Advisor's own
disclosed gaps are (`docs/AI_MODULES.md` §6).

**Audit Log** (`AdminAuditLogPage`, `/app/admin/audit-log`) is the read
side of `public.audit_log` — role changes, SHG grade changes, livelihood
staff overrides, and loan decisions are all written there by real database
triggers, but until this screen existed nothing in the app ever read it
back. Keyset-paginated ("Load more"), admin-only per RLS
(`audit_log_select_admin`).

| ID | Requirement | Roles |
|---|---|---|
| FR-ADM-1 | Admin manages user accounts: role assignment (two-step confirmation), SHG assignment for unlinked staff, account deactivation/reactivation (server-enforced via RLS identity helpers, not just a hidden button) | Admin |
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
[DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)). **Corrected here
(2026-07-25, round 145): this appendix and FR-AI-7 above previously
claimed "no content moderation or prompt-injection defense exists yet" —
stale, and had been for a while. A real two-layer defense (regex
pre-filter + a Groq Llama Guard 3 ML classifier, both on input and output,
with prompt-injection "sandwich" hardening) shipped with migration `0044`
and is thoroughly documented in [AI_MODULES.md](AI_MODULES.md) §6, which
was itself kept current — only this document's own summary table and
appendix had drifted out of sync with it.** The AI-related gap actually
worth prioritizing before scaling real usage is narrower than "no
moderation at all": gradual cross-turn abuse detection (today's checks are
per-turn, not whole-conversation pattern analysis) and proactive
alerting/escalation on repeated blocks (today's Admin Monitoring stat is a
passive, staff-must-look count, not automated) — see
[AI_MODULES.md](AI_MODULES.md) §6 for the full, current accounting.
