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
| Onboarding (Login/OTP/Profile Setup/Role Select/SHG Approval) | ✅ done | Real phone-OTP via Supabase Auth; profile setup persists to `profiles`; SHG search via `shg_directory` view. **Spec gap closed**: a member's `shg_id` now stays null until their SHG leader approves a `shg_join_requests` row (via the `approve_shg_join_request()` security-definer RPC) — live mode only, gated by `AppState.needsShgApproval` + a new `ShgApprovalPendingPage`; demo mode is untouched (its own simplified two-flag onboarding is unaffected by design). Also fixed a real live-mode-only latent bug found while building this: `hasProfile` flipped true the instant `completeProfileSetup()` ran, skipping Role Select entirely — the same bug already fixed for demo mode, never fixed for live mode since real phone OTP can't complete in this environment and this path was never exercised until now. Fixed with a `needsRoleSelection` flag mirroring the demo-mode two-flag pattern. Leader-side approval screen at `Paths.shgJoinRequests`, linked from the Members list. |
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
| AI Advisors (financial/scheme/market/voice) | ✅ done | Model, dual-mode repository, hub + one shared `AiAdvisorChatPage(advisorType, title, hint)` reused across all 3 chat routes (identical shape, scoped by type) — chat bubbles + composer, wired incl. `/app/ai/financial-advisor` etc. `AiAdvisorService` abstraction (`MockAiAdvisorService` keyword-matches canned responses per advisor type, generic fallback otherwise) — unlike Payments/Support, the ask flow works in both demo and live mode (only the log persistence is live-only), so the chat is fully interactive without a Supabase connection. Live-tested DB/RLS (own-log insert, deny-insert-for-another-member, own-log read, deny-read-for-non-owner-non-staff, staff-can-read-any — 5/5 passed), fixtures cleaned up and verified zero remnants. UI-tested: hub renders all 3 advisor cards, Financial Advisor chat loads mock history correctly, composer input focuses and accepts real keystrokes (confirmed via `activeElement.value`) — the final send-button tap hit the same coordinate-calibration friction as the Voice Support mic button in the prior iteration and wasn't click-verified, but the ask()/setState logic is structurally identical to the already-proven Support ticket composer. **Spec gap closed**: added a 4th, distinct "AI Voice Assistant" (`ai_voice_assistant_page.dart`) — deliberately separate from Support's generic FAQ-style Voice Support (`support_voice_page.dart`). New `VoiceRecognitionService`/`MockVoiceRecognitionService` abstraction recognizes a small fixed set of intents (loan details, savings-this-month, read-announcements, add-savings) in Telugu/Hindi/English (the spec's exact example Telugu phrases are the Telugu command set), then the *page* resolves each intent against real repositories (`LoanRepository`/`SavingsRepository`/`AnnouncementRepository`) rather than returning a canned answer — this is what makes it genuinely different from Voice Support, not just a reskin. "Fill forms through voice" from the spec is honestly scoped to voice-triggered navigation into the target form (real dictation into fields isn't feasible without a live STT engine) — recognizing "add a savings entry" navigates to the Savings Entry page. No new RLS surface (reuses repositories already proven in the Loans/Savings/Announcements modules). UI-tested on flutter-web-demo: confirmed via the semantics tree that Telugu glyphs render as real script (not tofu boxes) in a screenshot, then cycled through all 4 intents by tapping the mic repeatedly — each produced a real, data-accurate response (a real loan's outstanding balance, "₹0 this month across 0 entries" because the mock savings dates genuinely aren't in the current month, two real announcement titles), and the 4th correctly navigated to `/app/savings/entry` |
| Reports | ✅ done | Models, dual-mode repository, role-gated top hub (My Reports always; SHG Reports for leader/staff; Federation Reports for crp/clf/admin), wired incl. this also activates the pre-existing dashboard link at `Paths.reportsMember`. The repository always computes client-side from live tables (savings/loans/meetings/attendance) — a documented placeholder for the server-side Edge Function generation `report_snapshots` (staff-write-only) is meant for; the Flutter client never reads/writes that table directly yet. **Spec gap closed**: each of the 3 top-level pages is now itself a hub linking to the spec's named sub-reports rather than one combined stat page — Member: Savings Statement (reuses the existing `SavingsStatementPage`), Loan Statement (new), Attendance Report (new, backed by a new `MeetingRepository.fetchAttendanceHistory()`); SHG: Financial Summary (the original combined page, kept and renamed), Audit Report (reuses the existing Financial Records audit trail at `Paths.financialAudit`), Performance Report (new — attendance % + a monthly attendance trend chart); Federation: Village-wise SHGs (new, live-grouped by `shgs.village`), Loan Recovery (reuses `AnalyticsRepository.fetchPlatformKpis`), Savings Growth (new — monthly federation-wide savings trend chart). The trend-chart infrastructure (`lib/models/trend.dart`, `lib/repositories/trend_repository.dart`, `lib/widgets/trend_chart.dart`, an `fl_chart` `LineChart` wrapper) was built once here and is reused unchanged by the Analytics dashboard's 4 trend charts (next task) — not duplicated. Live-tested: no new RLS surface was introduced (all 9 sub-reports reuse tables/policies already proven in the Reports/Analytics iterations), so verification focused on confirming the new query shapes (`meetings`/`meeting_attendance` join for attendance history, `shgs`+`savings_entries` grouping for village-wise) execute correctly against a fixture with known data — matched expectations exactly; fixtures cleaned up and verified zero remnants. UI-tested all 9 screens on flutter-web-demo: hub role-gating still correct, Loan Statement/Attendance Report/Performance Report (with its attendance trend line chart)/Village-wise SHGs/Loan Recovery/Savings Growth (with its savings trend line chart) all render correctly with mock data — the `fl_chart` `LineChart` renders a real visible curve with data points, no console errors beyond the pre-existing unrelated `app_shell.dart` 2px overflow |
| Analytics | ✅ done | Models (`PlatformKpis`/`ShgHealth`), dual-mode repository (composes `ReportRepository.fetchShgReport` for per-shg member/savings/attendance figures rather than duplicating that logic), 3 screens (platform dashboard, SHGs monitoring list, per-SHG detail), wired incl. `/app/analytics/shg/:id` — this also activates the pre-existing CRP/CLF/Admin dashboard links (`Paths.analytics`, `Paths.analyticsShgList`, `Paths.analyticsShgDetail`) that were pointing at `ComingSoon` stubs. Same placeholder story as Reports: `analytics_kpis` exists for a future Edge Function to populate (staff-write-only), the Flutter client always computes client-side for now. SHG "health score" is currently the SHG's average completed-meeting attendance rate — a real, defensible proxy metric documented as a placeholder for a richer future formula. Live-tested DB/RLS: `analytics_kpis` staff-write-only (staff insert allowed, member insert denied), member can read their own SHG's scoped rows but not global (`shg_id is null`) rows, staff can read global rows — 6/6 checks passed; fixtures cleaned up and verified zero remnants. UI-tested on flutter-web-demo: all 3 screens render correctly with mock data (platform KPIs, SHG list with health progress bars, per-SHG detail). **Spec gap closed**: the platform dashboard now also shows the spec's 4 trend charts (Savings/Loan/Revenue/Attendance Trends), all federation-wide, reusing the `TrendRepository`/`TrendChart` infrastructure built for the Reports module's Federation "Savings Growth" report rather than duplicating `fl_chart` setup a 5th time — `revenueTrend()` reads `marketplace_orders` (federation-wide only, since orders aren't scoped to a single SHG in the schema and the only caller is this staff-only view). Live-tested: no new RLS surface (`marketplace_orders_select_related`'s existing `is_staff()` bypass already covers the new revenue query, confirmed by reading the policy directly rather than re-testing); verified via the semantics accessibility tree that all 4 charts render with real data (`"Savings Trends Feb Feb Mar Mar Apr Apr May May Jun Jun Jul"` etc.) and a screenshot confirmed a real visible line-chart curve, no console errors beyond the pre-existing unrelated `app_shell.dart` overflow |
| Admin (users/schemes/monitoring) | ✅ done | Model (`SystemHealth`), `AdminRepository` (user list + role change, system health row counts) + `SchemeRepository` extended with admin CRUD (createScheme/updateScheme/deleteScheme, reusing the existing member-facing repository since it's the same table), 3 screens, wired incl. this activates 5 pre-existing dashboard links (Admin's Users/Schemes/Monitoring quick tiles + "Review" banner + CLF's federation reports link was already live). Confirmed via RLS testing that `profiles_update_self_or_admin` and `schemes_write_admin` are **admin-only, not staff-wide** — a crp/clf user (which passes `is_staff()`) is correctly denied on both, unlike every other staff-gated table in this schema; UI mirrors this by checking `role == Role.admin` specifically, not the `is_staff()`-equivalent set used elsewhere. System Monitoring is explicitly documented as a row-count placeholder, not real infra metrics (uptime/latency/error-rate would need an Edge Function or external monitoring integration). Live-tested DB/RLS: crp denied role-change, admin allowed; crp denied scheme insert/delete, admin allowed — 7/7 checks passed; fixtures cleaned up and verified zero remnants. UI-tested on flutter-web-demo: all 3 screens render correctly with mock data, write controls correctly hidden for the non-admin demo persona |
| Profile, Settings, Language, Services | ✅ done | The last 4 `ComingSoon` stubs in the whole app — `Paths.profile`/`profileSettings`/`profileLanguage`/`services`, all already linked from the dashboard top bar and bottom nav. **Profile**: avatar/name/role badge, mobile/village/SHG (fetched live via `ShgRepository.fetchShg`), an edit dialog (name + village only — `shgId`/`role` are governed by the join-approval workflow and Role Select respectively, so deliberately not editable here), links to Settings/Language, sign out. **Settings**: 3 local notification toggles (`SharedPreferences`-backed — these are genuinely device-local preferences in most apps, not server data, so no new table), a language shortcut showing the current selection, and a "Preview as" role-switcher section (explains why the dashboard top bar's role chip was already wired to `Paths.profileSettings` since early in the session — this is where that "unfold" affordance actually resolves). **Language**: a real implementation of the `Language` enum/`AppState.setLanguage()` that had existed unused since the very first session (English/Telugu/Hindi, checkmark on the current selection, persists via the existing `SharedPreferences` plumbing). **Services**: a full module directory (grouped by SHG Management / Commerce / Learning & Support / Insights / Admin Tools) for discoverability beyond each dashboard's curated shortcuts, role-gated (Analytics section for crp/clf/admin, Admin Tools section for admin only) reusing the same `is_staff()`-equivalent role sets established elsewhere. Deleted the now-fully-unused `comingSoon()` router helper and `ComingSoonPage` widget entirely, since this closed the last 4 call sites. No new RLS surface (Profile edit reuses `profiles_update_self_or_admin`, already proven; Settings/Language are local device state; Services is pure navigation). `flutter analyze` clean (12 issues, same pre-existing set, 0 new — fixed 2 real lints along the way: a `use_build_context_synchronously` in the profile edit dialog's second `await`, and `Switch`'s deprecated `activeColor` → `activeThumbColor`). Live UI-tested on flutter-web-demo via the semantics accessibility tree: Profile shows real data end-to-end; Settings' notification toggle persisted to `localStorage` correctly, and switching "Preview as" role updated the bottom nav label reactively (`"SHGs"` → `"My SHG"`) confirming the change propagated through the whole app's state, not just the Settings page; Language's Telugu selection persisted to `localStorage` and the Settings page's language shortcut picked it up immediately; Services rendered every section correctly with the Analytics/Admin sections correctly hidden for the member-role demo persona. Hit a genuinely confusing automation artifact partway through (hash-navigation intermittently landed on an unrelated prior route with no click in between) — worked around by using a fully fresh tab for the remainder, not a real app bug (confirmed by the same navigation working correctly and consistently once isolated) |
| Camera QR scanning (Meeting check-in + Payments QR) | ✅ done | Added `mobile_scanner: ^5.2.3` plus the `CAMERA` permission/features in `AndroidManifest.xml` and `NSCameraUsageDescription` in `Info.plist`. New shared `lib/widgets/qr_scanner_sheet.dart` (`showQrScanner()`) — full-screen camera view with a viewfinder overlay, torch toggle, and two independent exits: an always-visible "Manual entry" app-bar button (not gated on any camera event firing) and a 6-second timeout fallback if the camera hasn't initialized. Meeting check-in (`meeting_qr_page.dart`) now offers "Scan QR to Check In" alongside the existing "Check In Without Scanning" fallback button; Payments QR (`payments_qr_page.dart`) replaced its static placeholder box with a tappable scanner entry that parses `upi://pay?pn=...&am=...` URIs (or a bare numeric string as an amount) into the payee/amount fields. `flutter analyze` clean (same pre-existing 12 issues, 0 new), `flutter test` all 12 passing. **Live UI verification could not be completed in this environment**: the sandboxed Browser pane tool actively blocks `getUserMedia()` camera access, and unlike a clean permission-denied rejection, the underlying promise never resolves in a way the page can observe — this by itself is exactly the failure mode the timeout fallback exists to handle. However, attempting it left the Browser pane's screenshot/compositor capability globally wedged for the remainder of the session: confirmed via closing every tab and opening entirely fresh ones, navigating to origins that never touch a camera (`localhost:5000`, a different Flutter app instance entirely), `computer{action:"screenshot"}` timed out (30s) every time afterward, while `read_page`/`tabs_context`/console access kept working structurally. This rules out anything specific to the QR page or a stuck per-tab modal — it's a session-level artifact of the Browser pane tool itself after any camera-permission attempt, the same class of "can't be live-tested here" limitation already documented for phone OTP (no SMS provider configured). Verification therefore rests on static checks (`flutter analyze`, `flutter test`, direct code review of both integration points) rather than an in-browser click-through; a real device/browser with camera access should be used to confirm the actual scan-to-detect flow before shipping. |
| Real i18n (English/Telugu/Hindi) for app chrome | 🟡 partial | The Language picker (`Paths.profileLanguage`) previously only stored a `SharedPreferences` value with **zero effect on displayed text** — a real production-grade gap given the app's whole audience is rural Indian SHG members. Wired genuine Flutter l10n: `flutter_localizations` + `intl` bumped to the SDK-pinned `0.20.2`, `l10n.yaml` + `lib/l10n/app_{en,te,hi}.arb` (~65 keys), generated `lib/l10n/gen/app_localizations.dart`. `main.dart`'s `MaterialApp.router` now takes `locale` from `AppState.language` (wrapped in an `AnimatedBuilder` on the app-state instance so changing language rebuilds immediately, no navigation needed) plus the 4 standard `localizationsDelegates`. Translated and wired: the bottom nav (`app_shell.dart`), and every string on the Login/OTP/Profile-Setup/Role-Select/SHG-Approval-Pending auth flow pages and the Profile/Settings/Language pages themselves. **Deliberately not yet translated** (English-only still): every individual module's own screens (Savings, Loans, Meetings, Marketplace, etc.), and the `RoleInfo.label`/`.description` strings shared across dashboards/Settings' "Preview as" list (translating those ripples into every dashboard and wasn't in scope for this pass) — tracked as follow-up, not silently dropped. `flutter analyze` clean (same 12 pre-existing issues, 0 new). Fixed a real regression this surfaced: `test/pages/shg_join_approval_test.dart` pumped a bare `MaterialApp` with no localization delegates, so `AppLocalizations.of(context)!` null-checked and threw — fixed by adding the delegates to the test harness. Added `test/l10n_test.dart` (3 new tests) that pump `LoginPage` under `Locale('en')`/`Locale('te')`/`Locale('hi')` and assert the actual Telugu/Hindi script renders — this is what caught that the feature genuinely works, since live UI verification in the Browser pane could not be completed (see below). `flutter test` 15/15 passing. **Live UI verification hit the same session-wide Browser-pane wedge already documented for the QR-scanner task** (`computer{action:"screenshot"}` timing out and the DOM never hydrating on a freshly restarted demo server, even after long waits) — a carryover from the earlier camera-permission attempt in this same session, not a new bug; the 3 locale-switching widget tests are the real verification for this feature instead of a browser click-through. |
| Global error handling + friendly error/404 screens | ✅ done | Audited for production crash resilience: there was no `FlutterError.onError`/`runZonedGuarded`/`PlatformDispatcher.onError` anywhere, no custom `ErrorWidget.builder` (a release-mode widget-build error would show Flutter's bare gray box), and `GoRouter` had no `errorBuilder` (an unmatched route fell back to GoRouter's plain default error page). Added a shared `lib/widgets/error_screen.dart` (`AppErrorScreen`) reused by both: `main.dart` now wraps `runApp` in `runZonedGuarded` (uncaught async errors are logged via `debugPrint` instead of vanishing in a detached zone — no crash-reporting service like Sentry/Crashlytics is wired up since that needs an external API key, so this is "log it" not "report it upstream", documented the same way as every other credential-gated gap) and sets `ErrorWidget.builder` to show the friendly screen instead of the default one (still calls `FlutterError.presentError` first so nothing is silently swallowed); `router.dart`'s `GoRouter(...)` now has an `errorBuilder` showing "Page not found" with a button back to the dashboard. `flutter analyze` clean (same 12 pre-existing issues — caught and fixed 2 new unused-import lints from this change along the way, 0 net new). Added `test/router_error_test.dart` confirming an unmatched route renders the friendly screen instead of crashing. `flutter test` 16/16 passing. No live UI verification attempted — the Browser pane's screenshot/hydration capability is still wedged this session (documented above); this is a low-risk, code-reviewable change (error paths only, no change to any golden-path screen) so static verification was judged sufficient rather than forcing another browser attempt. |
| Automated tests | ✅ done | `test/widgets/async_state_test.dart` (6 tests covering `AppAsyncBuilder`'s loading/data/error/retry states plus `reload()`, and `AppEmptyState`), `test/repositories/repository_pattern_test.dart` (4 tests confirming the dual-mode demo-fallback pattern used by every repository this session), `test/app_smoke_test.dart` (1 end-to-end test booting the real `ShgSaathiApp` widget tree in demo mode, splash → "Get Started" → login). 11 tests, all passing (since grown to 15 — see `test/pages/shg_join_approval_test.dart` and `test/l10n_test.dart` added in later iterations). **Found and fixed a real pre-existing bug** while writing these: `AppAsyncBuilderState.reload()` called `setState(() => _future = next)` — an arrow-function callback whose body is an assignment expression evaluates to the assigned value, so the closure returned the `Future` itself, tripping Flutter's "setState() callback argument returned a Future" guard. This has been present since the foundational async widget was built early in the session and is used by every module's refresh/reload action (Announcements' post dialog, Support's send-message, Admin's scheme add/delete, etc.) — it never visibly broke anything because the state mutation already happened before the assertion fired, so it was silently swallowed by Flutter's error reporting during all prior manual UI testing. Fixed by switching to a block-bodied closure (`setState(() { _future = next; });`), which returns `void`. No other code changes were needed elsewhere since every call site already used `reload()` correctly — only its own internal implementation was buggy. |
| Edge Functions | ✅ done | `generate-report-snapshots` is written, **deployed live**, and verified end-to-end (user explicitly authorized the production deploy after the safety classifier correctly paused on it — see session log). It needs no external API key, only the service-role key Supabase auto-injects into every deployed function. Deployed via the Management API's `functions/deploy` endpoint using a `curl.exe` multipart upload (same technique as the migration pushes). Live-tested: created a `__TEST__` SHG fixture with known savings (₹800 across 2 members), an active loan (₹3,000 outstanding), and one completed meeting with 1/2 attendance, invoked the deployed function, and confirmed the resulting `report_snapshots` row's `data` jsonb matched exactly (`member_count: 2, total_savings: 800, total_outstanding: 3000, active_loan_count: 1, avg_attendance_pct: 50`) — this mirrors `ReportRepository`/`AnalyticsRepository`'s client-side aggregation logic, now proven correct server-side too. Fixtures and their resulting snapshot rows were cleaned up and the function re-invoked once more to leave `report_snapshots` holding the real (currently empty-platform) state rather than test data. A nightly Scheduled Trigger now runs it automatically (see `supabase/migrations/0003_scheduled_report_snapshots.sql` — `pg_cron` job `generate-report-snapshots-nightly` at `0 2 * * *` UTC, calling the function via `pg_net`'s `net.http_post`; no auth header needed since `verify_jwt` is false). It can still be invoked manually anytime via `POST https://pccbwfmlhpvieetetrpx.supabase.co/functions/v1/generate-report-snapshots`. `ai-advisor-proxy/index.ts` and `payment-webhook-handler/index.ts` remain deliberately source-only scaffolds (not deployed) since both need a real external secret (`LLM_API_KEY`, `PAYMENT_WEBHOOK_SECRET`) neither of which exists in this environment — each throws immediately if its secret is absent rather than silently no-opping, and each documents exactly what one-file swap activates it once a real key is supplied (mirrors the `MockAiAdvisorService`/`MockPaymentProcessor` client-side pattern). |

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
- **2026-07-18 (cont'd)**: Built the full Reports module (models shaped to
  match the eventual `report_snapshots.data` payload, dual-mode repository
  that always computes client-side from live tables, role-gated hub + 3
  screens). This also wired up the pre-existing dashboard attendance-card
  link at `Paths.reportsMember`, which had been pointing at a `ComingSoon`
  stub since the dashboard was first built. `flutter analyze` clean (same 9
  pre-existing info-level lints, 0 new issues). Live-tested DB/RLS with a
  2-SHG, 3-profile fixture set — hit a **real test-fixture bug** during this
  pass: the first cross-shg-isolation attempt used a savings row with
  `member_id` set to the querying member but `shg_id` set to a *different*
  SHG, which the querying member could see — not an RLS gap, but exactly
  correct behavior per the `member_id = auth.uid() or shg_id = current_shg_id()
  or is_staff()` policy (a member can always read their own rows regardless
  of `shg_id`, and a self-owned row with a mismatched `shg_id` isn't a
  realistic case the policy needs to guard against). Corrected by giving the
  SHG-B row a distinct SHG-B member as its owner, then re-ran: all 6 checks
  passed (real cross-shg isolation for a non-owner, staff can read across
  SHGs, staff can read another SHG's row directly, member cannot read
  another SHG's row directly, staff can insert into `report_snapshots`,
  member insert denied); fixtures cleaned up and verified zero remnants.
  Also hit two check-constraint casing mistakes while building the fixture
  (`savings_entries.frequency` wants `'Weekly'` not `'weekly'`,
  `.mode` wants `'Cash'` not `'cash'` — both enums are capitalized in the
  schema) — worth remembering for any future savings_entries fixture.
  UI-tested on a fresh tab: hub correctly shows only "My Reports" for the
  member role (SHG/Federation cards correctly hidden), and all 3 report
  screens (My Reports, SHG Reports, Federation Reports — the latter two
  reached directly by hash since only the hub gates by role, not the
  routes themselves) render their stat cards with the demo-mode mock data
  correctly. Next: Analytics module.
- **2026-07-18 (cont'd)**: Built the full Analytics module (models, dual-mode
  repository that composes `ReportRepository` for per-SHG figures instead
  of duplicating the savings/loans/attendance aggregation logic, 3 screens).
  This also activated three pre-existing dashboard links (CRP's "SHGs Under
  Monitoring" + "View all", CLF's "Monitor Village Organisations" +
  "Full Analytics Dashboard", Admin's "Analytics" action) that had been
  pointing at `ComingSoon` stubs since those dashboards were first built.
  `flutter analyze` clean (same 9 pre-existing info-level lints, 0 new
  issues). Live-tested DB/RLS for `analytics_kpis` specifically (the other
  queries this module makes — shgs/profiles/savings_entries/loans — reuse
  RLS paths already proven in the Reports iteration, so weren't
  re-tested): staff-write-only (staff insert allowed, member insert
  denied), member reads their own SHG's scoped rows but not global
  (`shg_id is null`) rows, staff reads global rows — 6/6 checks passed;
  fixtures cleaned up and verified zero remnants (this time surfacing the
  actual SQL error immediately instead of piping to `Out-Null`, per the
  standing instruction — no casing mistakes this round). UI-tested on a
  fresh tab: all 3 screens (platform dashboard, SHGs monitoring list,
  per-SHG detail via `/app/analytics/shg/g1`) render correctly with the
  demo-mode mock data. Next: Admin module.
- **2026-07-18 (cont'd)**: Built the full Admin module (model, new
  `AdminRepository` for users/monitoring, `SchemeRepository` extended with
  admin CRUD rather than a duplicate repository since it's the same table
  the member-facing Schemes module reads, 3 screens). This activates the
  last 5 pre-existing dashboard links still pointing at `ComingSoon` stubs
  (Admin's Users/Schemes/Monitoring tiles + its "Review" banner). **Every
  module in the status table is now done.** `flutter analyze` clean (12
  issues total, still all info-level — 3 new `use_null_aware_elements`
  hints in the extended `scheme_repository.dart`, same category already
  accepted everywhere else in the codebase, 0 errors/warnings). Live-tested
  DB/RLS: discovered and confirmed a real, easy-to-miss distinction in the
  schema — `profiles_update_self_or_admin` and `schemes_write_admin` check
  `current_role() = 'admin'` specifically, NOT `is_staff()` (which also
  includes crp/clf) — so a crp/clf user is correctly *denied* role changes
  and scheme catalog writes, unlike every other staff-gated table touched
  so far this session. Verified with a crp fixture explicitly (not just
  member vs admin) since the natural assumption from every prior module
  would be that "staff" is staff; the UI's write-control gating checks
  `role == Role.admin` specifically to match, not the crp/clf/admin set
  used everywhere else. 7/7 RLS checks passed (crp denied role-change +
  scheme insert + scheme delete; admin allowed all three); fixtures
  cleaned up and verified zero remnants. UI-tested on flutter-web-demo: all
  3 screens render with mock data, write controls correctly hidden for the
  demo persona (SHG Member role). Next: Automated tests, then Edge
  Functions — the only two remaining rows in the status table.
- **2026-07-18 (cont'd)**: Added the `test/` directory — 11 tests across 3
  files (`AppAsyncBuilder` state coverage, dual-mode repository fallback
  behavior, and a full app-boot smoke test). Writing these caught a real
  bug: `AppAsyncBuilderState.reload()`'s `setState(() => _future = next)`
  returned the `Future` from the arrow-function callback (an assignment
  expression evaluates to the assigned value), tripping Flutter's
  "setState() callback argument returned a Future" debug-mode assertion.
  This has been in the shared async widget since it was first built and
  runs on every module's refresh path, but never visibly broke anything —
  the state mutation happens before the assertion fires, so Flutter's
  error reporting silently swallowed it through every round of manual live
  UI testing this session. Fixed with a block-bodied closure instead of an
  arrow function. Also hit two harness-only test issues, both fixed in the
  test files (not app bugs): the default 800×600 test surface was too
  short for the splash page's layout, clipping the "Get Started" button
  out of the hit-testable area — fixed by sizing the test surface like a
  real phone (400×900) via `tester.view.physicalSize`; and a loading-state
  test left a `Future.delayed` timer pending past teardown — fixed by
  pumping past the delay before the test ends. `flutter analyze` clean (12
  issues, all pre-existing info-level, 0 new). All 11 tests pass. Next:
  Edge Functions — the last remaining row in the status table.
- **2026-07-18 (cont'd)**: Wrote all 3 candidate Edge Functions under
  `supabase/functions/`. Attempted to deploy `generate-report-snapshots`
  (the one needing no external key — only the service-role key Supabase
  auto-injects) via the Management API's `functions/deploy` endpoint using
  `curl.exe` multipart upload, the same technique the migration pushes
  used successfully all session. The attempt was **blocked by the safety
  classifier**: creating a new Edge Function with service-role database
  access on the live project is a production-deploy action, and the loop's
  standing instruction only generically named "Edge Functions" as a
  remaining category — it didn't specifically authorize deploying one with
  a particular unauthenticated-access configuration. This is a genuine
  stop-and-ask boundary, not a bug to work around. Left all 3 functions as
  reviewed, ready-to-deploy source: `generate-report-snapshots` mirrors
  `ReportRepository`/`AnalyticsRepository`'s aggregation logic server-side
  (delete-then-insert per shg/period/type, since `report_snapshots` has no
  unique constraint to upsert against); `ai-advisor-proxy` and
  `payment-webhook-handler` are scaffolds that throw immediately if their
  required secret (`LLM_API_KEY`, `PAYMENT_WEBHOOK_SECRET`) is absent,
  documenting the exact one-file swap that activates each once a real
  key/gateway is available. Asked the user whether to proceed with
  deploying `generate-report-snapshots` — this is the last open item
  before every row in the status table is fully done.
- **2026-07-18 (cont'd)**: User chose "Deploy it now." Deployed
  `generate-report-snapshots` via the Management API (`curl.exe` multipart
  upload) — succeeded, HTTP 201, function status `ACTIVE`. Invoked it live
  twice: once against the (real, currently empty) platform state
  (`shg_snapshots: 0`), then again after building a `__TEST__` SHG fixture
  with known numbers (2 members, ₹800 total savings, ₹3,000 loan
  outstanding, 1 completed meeting at 1/2 attendance) — the resulting
  `report_snapshots` row's `data` jsonb matched every expected number
  exactly, confirming the function's server-side aggregation logic is
  correct and consistent with the Flutter client's equivalent
  `ReportRepository`/`AnalyticsRepository` computations. Cleaned up the
  fixture and its snapshot rows, then invoked the function once more so
  `report_snapshots` reflects real data, not test residue. **Every row in
  the module status table, including Edge Functions, is now done.** This
  closes out the full development loop that began at the start of this
  session — all 20 modules plus Automated tests and Edge Functions are
  built, live-tested (DB/RLS and UI), documented, and committed.
- **2026-07-18 (cont'd)**: User asked for a nightly Scheduled Trigger on
  `generate-report-snapshots`. Enabled `pg_cron` and `pg_net` (neither was
  installed on the project yet, both were available), then scheduled a
  `cron.schedule` job (`generate-report-snapshots-nightly`, `0 2 * * *`
  UTC) whose command calls the deployed function via `net.http_post` — no
  auth header needed since the function's `verify_jwt` is false. Verified
  the job registered correctly by reading it back from `cron.job`. Recorded
  as `supabase/migrations/0003_scheduled_report_snapshots.sql` for
  repo-tracked infra-as-code, matching how the schema/RLS migrations are
  already tracked.
- **2026-07-18 (cont'd)**: User supplied the original product spec document
  ("Mobile Application for SHGs.docx") and asked to close any remaining
  gaps against it across every role including Admin. Audited the built app
  against the spec section by section and found 4 real gaps (everything
  else — all 5 roles, all 13 tabs, the AI advisor trio, reports/analytics/
  admin as categories — was already built): (1) the spec's "Step 2: SHG
  Mapping — Member → Select SHG → Approval by Leader" workflow didn't
  exist — a new member's `shg_id` was set instantly with no leader
  approval step; (2) the Reports module showed one combined stat-card page
  per role instead of the spec's named sub-reports (Savings/Loan/
  Attendance Statement for members; Financial Summary/Audit/Performance
  for SHGs; Village-wise/Recovery/Growth for federation); (3) the Analytics
  Dashboard had KPIs but none of the spec's 4 trend charts (Savings/Loan/
  Revenue/Attendance Trends), despite `fl_chart` already being a
  dependency; (4) no distinct "AI Voice Assistant" existed — only a
  generic FAQ-style Voice Support under Help & Support, missing the spec's
  Telugu-language awareness, notification read-aloud, and voice form-fill.
  Started a new /loop to close all 4, one per iteration with the same
  full rigor as every module this session (build → flutter analyze → live
  DB/RLS test → live UI test → document → commit).

  **Gap 1 (SHG join-approval) — done.** New `shg_join_requests` table +
  RLS + a `security definer` `approve_shg_join_request(request_id, approve)`
  RPC (a leader can't otherwise update another member's `profiles` row
  under `profiles_update_self_or_admin`, so the RPC checks authorization
  internally and does both writes atomically, rather than opening a
  broader UPDATE policy). New `AppState.needsShgApproval` gates the router
  to a new `ShgApprovalPendingPage` for a member whose join request is
  still pending (scoped to live mode + the `member` role only — the
  role-preview personas this app's self-service Role Select otherwise
  offers aren't part of this workflow). New leader-side
  `ShgJoinRequestsPage` (approve/reject), linked from the Members list via
  a new icon button visible to leaders. **Found and fixed a second real
  bug in the process**: in live mode, `hasProfile` (`_profile != null`)
  flips true the instant `completeProfileSetup()` runs — before
  `context.go(Paths.roleSelect)` even executes — so the router's "fully
  onboarded" branch fired first and Role Select was skippable. This is the
  exact same class of bug already found and fixed for demo mode earlier
  this session, just never triggered for live mode since real phone OTP
  can't complete in this environment. Fixed with a `needsRoleSelection`
  flag mirroring the demo-mode two-flag split. Also caught and fixed a
  subtler routing bug of my own making while implementing this: the
  `needsShgApproval` gate initially redirected away from `profileSetup`
  too, which would have permanently trapped a rejected member (tapping
  "choose a different SHG" → bounced straight back to the pending page,
  looping forever) — fixed by exempting `profileSetup` from that gate.
  Live DB/RLS-tested with a 2-SHG, 5-profile fixture set — all 12 checks
  passed (member submits own request / denied submitting for another
  member, member reads own request, unrelated member denied, the target
  SHG's leader reads it, a different SHG's leader denied, staff reads it,
  wrong-SHG leader's RPC call denied, correct leader's approve RPC sets
  `profiles.shg_id` and flips status to `approved`, a second request's
  reject RPC flips status to `rejected` while leaving `shg_id` null);
  fixtures cleaned up and verified zero remnants. UI-tested two ways:
  (a) since this feature is live-mode-only and demo mode intentionally
  bypasses it, the new pages can't be exercised via the usual
  flutter-web-demo browser technique — added `test/pages/
  shg_join_approval_test.dart` instead (2 widget tests confirming both
  pages render their demo-mode empty-state branch without throwing); (b)
  regression-tested the demo-mode onboarding flow end-to-end on a fresh
  browser tab (cleared `localStorage`, walked Profile Setup → Role Select
  → Dashboard) to confirm the shared `app_state.dart`/`router.dart`
  changes didn't disturb the existing demo flow — Role Select still
  rendered correctly, exactly as before. `flutter analyze` clean (same 12
  pre-existing info-level issues, 0 new); full test suite (12 tests) passes.
  Next: break the Reports module into the spec's named sub-reports.
- **2026-07-18 (cont'd)**: Broke the Reports module's 3 top-level pages
  into hubs linking to the spec's 9 named sub-reports (3 per audience —
  see the updated Reports row above for the full list and which ones
  reuse existing screens vs. are new). Built shared trend-chart
  infrastructure once (`TrendRepository` computing monthly Savings/Loan/
  Revenue/Attendance series, a `TrendChart` wrapper around `fl_chart`'s
  `LineChart`) specifically so the Federation "Savings Growth" report and
  the Analytics dashboard's upcoming 4 trend charts (next task) share one
  implementation instead of duplicating `fl_chart` boilerplate twice.
  Added `MeetingRepository.fetchAttendanceHistory()` and
  `ReportRepository.fetchVillageWiseShgs()` for the two sub-reports that
  needed a genuinely new query shape. `flutter analyze` clean (same 12
  pre-existing info-level issues, 0 new); full test suite (12 tests)
  passes. No new RLS surface was introduced (every sub-report reuses
  tables/policies already proven in earlier iterations), so verification
  focused on confirming the new query shapes execute correctly against a
  fixture with known data (meetings/attendance join, shgs+savings
  grouping) — matched expectations exactly; fixtures cleaned up and
  verified zero remnants. UI-tested all 9 sub-report screens on
  flutter-web-demo — all render correctly with mock data, and the
  `fl_chart` `LineChart` (first use of a line chart anywhere in this app —
  prior charts were all bar charts) renders a real visible curve with data
  points, no console errors beyond the pre-existing unrelated
  `app_shell.dart` 2px overflow. Next: add the Analytics dashboard's 4
  trend charts, reusing this same `TrendRepository`/`TrendChart`
  infrastructure.
- **2026-07-18 (cont'd)**: Added the Analytics dashboard's 4 spec-required
  trend charts (Savings/Loan/Revenue/Attendance Trends), all federation-
  wide, reusing the `TrendRepository`/`TrendChart` infrastructure built for
  the Reports module one iteration ago rather than writing a 5th `fl_chart`
  setup — `revenueTrend()` is the only new method on `TrendRepository`,
  reading `marketplace_orders` (no SHG scoping needed since orders aren't
  tied to a single SHG in the schema and Analytics is a staff-only,
  platform-wide view anyway). Loads the KPIs + all 4 trends in parallel via
  `Future.wait`. No new RLS surface — confirmed `marketplace_orders_select
  _related`'s existing `is_staff()` bypass already covers the new query by
  reading the policy directly rather than re-testing something already
  proven. `flutter analyze` clean (same 12 pre-existing info-level issues,
  0 new); full suite (12 tests) passes. UI-tested on flutter-web-demo:
  used the semantics accessibility tree to positively confirm all 4 charts
  render with real month-labeled data (not just "no crash"), plus a
  screenshot confirming a real visible curve — no console errors beyond
  the pre-existing unrelated `app_shell.dart` overflow. Next: build the
  distinct AI Voice Assistant — the last of the 4 spec gaps.
- **2026-07-18 (cont'd)**: Built the distinct "AI Voice Assistant"
  (`ai_voice_assistant_page.dart`), the 4th and last spec gap. New
  `VoiceRecognitionService`/`MockVoiceRecognitionService` abstraction
  recognizes a small fixed set of intents in Telugu/Hindi/English (the
  Telugu set is the spec's own example phrases verbatim); the page then
  resolves each intent against real repositories (`LoanRepository`/
  `SavingsRepository`/`AnnouncementRepository`) instead of a canned
  response, which is the deliberate distinction from Support's existing
  generic FAQ-style Voice Support. "Fill forms through voice" is honestly
  scoped to voice-triggered navigation into the target form, since real
  dictation into fields isn't feasible without a live STT engine.
  `flutter analyze` clean (same 12 pre-existing info-level issues, 0 new —
  caught and fixed a genuine mistake of my own mid-build: an accidental
  Kotlin-style `.let()` call left over from drafting, which isn't valid
  Dart and would have been a compile error, before it ever reached
  analyze); full suite (12 tests) passes. No new RLS surface — every
  repository this page calls was already proven in earlier iterations.
  UI-tested on flutter-web-demo: confirmed via a screenshot that Telugu
  script renders correctly as real glyphs, not tofu boxes (a real risk
  worth checking given the app's `pubspec.yaml` only bundles Roboto, which
  doesn't cover Telugu — the browser's own font fallback covers it, at
  least on this platform); then cycled through all 4 intents by tapping
  the mic repeatedly and read the semantics tree after each, confirming
  every response was genuinely data-accurate (a real loan's outstanding
  balance pulled from the same mock data seen in the Loan Statement
  report, "₹0 this month across 0 entries" because the mock savings dates
  legitimately aren't in the current month — not a hardcoded string, two
  real announcement titles matching the Announcements module's own mock
  data) and that the 4th intent correctly navigated to `/app/savings/
  entry`.

  **This closes all 4 spec gaps found in the audit at the start of this
  loop.** Every module in the original status table, Automated tests,
  Edge Functions, and now the SHG join-approval workflow, the 9 named
  Reports sub-reports, the 4 Analytics trend charts, and the AI Voice
  Assistant are built, live-tested (DB/RLS and UI wherever technically
  possible), documented here, and committed locally.
- **2026-07-18 (cont'd)**: User asked to keep going and finish the
  remaining pages across every service, explicitly naming Settings,
  Profile, and Admin. Audited `router.dart` for any leftover `comingSoon()`
  stubs — found exactly 4: `Paths.profile`, `profileSettings`,
  `profileLanguage`, `services` (Admin itself was already fully built
  earlier this session). Built all 4 for real (see the new "Profile,
  Settings, Language, Services" status-table row above for the full
  breakdown), then deleted the now-fully-unused `comingSoon()` helper and
  `ComingSoonPage` widget since closing these 4 call sites left them with
  zero references anywhere in the app. `flutter analyze` clean (same 12
  pre-existing info-level issues, 0 new — 2 real lints fixed along the
  way). Full suite (12 tests) passes. No new RLS surface. Live UI-tested
  all 4 pages on flutter-web-demo via the semantics accessibility tree,
  including cross-page state propagation checks (switching role in
  Settings updated the bottom nav label immediately; picking Telugu in
  Language was reflected back on the Settings page's language shortcut).
  Hit a confusing automation artifact along the way — `location.hash`
  assignments intermittently landed on an unrelated prior route with no
  click in between, on a tab that had accumulated a lot of interaction
  history this session — resolved by moving to a fresh tab, after which
  navigation was consistently correct, confirming it was a tooling/session
  artifact and not an app bug. **Every screen in the app is now a real,
  live-tested implementation — there are no remaining `ComingSoon` stubs
  anywhere.**
- **2026-07-18 (cont'd)**: With no `ComingSoon` stubs left, asked the user
  whether to close the one remaining documented placeholder — QR camera
  scanning for Meeting check-in and Payments QR (both previously worked via
  manual entry/tap only, no camera plugin was in `pubspec.yaml`). User chose
  to add it. Added `mobile_scanner` plus native camera permissions for
  Android/iOS, built a shared `showQrScanner()` full-screen scanner sheet,
  and wired it into both features (see the new "Camera QR scanning"
  status-table row above for the full breakdown). While live-testing this
  in the Browser pane, confirmed the sandboxed environment blocks
  `getUserMedia()` outright and — worse — never resolves/rejects the
  promise the way a clean permission-denial would, which is precisely the
  failure mode the scanner's 6-second timeout fallback and always-visible
  "Manual entry" button were built to handle (not merely a workaround for
  this sandbox — unresponsive camera hardware/OS permission systems are a
  real-world failure mode too). The attempt left the Browser pane's
  screenshot/compositor capability wedged for the rest of the session:
  verified this was pane-wide and not specific to the QR page or a stuck
  tab by closing every tab, opening fully fresh ones, and even navigating
  to `localhost:5000` (an entirely different Flutter app instance that
  never touched a camera) — `computer{action:"screenshot"}` still timed
  out every time, while `read_page`/`tabs_context`/console access kept
  working. Concluded further retries would not resolve this and documented
  it as a confirmed environment limitation, the same class as the
  already-established "phone OTP can't be tested live here" limitation.
  Verification rests on `flutter analyze` (clean, same 12 pre-existing
  issues, 0 new), `flutter test` (12/12 passing), and direct code review
  of both integration points, rather than an in-browser click-through —
  flagged that a real device/browser should confirm the actual
  scan-to-detect flow before shipping. This was the last remaining
  documented placeholder; no further gaps are known at this time.
- **2026-07-18 (cont'd)**: User asked to keep the loop going indefinitely —
  not just until every module/stub is built, but until the whole app is
  genuinely production-grade. Surveyed remaining mock/placeholder
  implementations to find the next real gap. Tried real Supabase Storage
  file uploads first (documents, product images — currently metadata-only)
  but the Management API personal access token needed to create storage
  buckets isn't available this session (never persisted, by design, and
  this is a fresh context) — asked the user how to proceed via
  `AskUserQuestion`; they chose to skip it for now and keep looping on
  other gaps, so the `image_picker`/`file_picker` packages added for that
  attempt were cleanly reverted rather than left half-wired. Picked the
  next concrete, credential-free gap instead: the Language picker
  (English/Telugu/Hindi) was 100% cosmetic — it stored a preference and
  did nothing to the actual displayed text, a genuine production gap for
  an app whose whole audience is rural Indian SHG members. Wired real
  Flutter l10n (see the new "Real i18n" status-table row above for the
  full breakdown) covering the app chrome, auth/onboarding flow, and
  Profile/Settings/Language pages, deliberately scoped to leave individual
  module screens and shared role labels as a documented follow-up rather
  than claiming full-app coverage that wasn't actually done. Found and
  fixed a real regression along the way (a pre-existing widget test broke
  because it pumped a bare `MaterialApp` with no localization delegates)
  and added 3 new locale-switching tests as the actual verification for
  this feature, since live UI testing hit the exact same Browser-pane
  screenshot/hydration wedge already documented for the QR-scanner task —
  confirmed once more this is a persistent session-level artifact (still
  present after a full server restart and fresh tab), not something
  specific to this feature. `flutter analyze` clean, `flutter test` 15/15
  passing. Marked task #32 complete; continuing to loop on further
  production-grade gaps (real payment gateway, real LLM-backed AI
  advisors, and real STT are all out of reach without user-supplied paid
  API credentials and will be flagged the same way storage was rather than
  faked, but plenty of credential-free hardening remains — broader
  translation coverage, storage uploads once the token is available,
  accessibility, and general resilience).
- **2026-07-18 (cont'd)**: Continued the production-hardening sweep with
  another credential-free gap: there was no global error handling anywhere
  in the app — no `FlutterError.onError`/`runZonedGuarded`, no custom
  `ErrorWidget.builder` (release mode would show Flutter's bare gray box
  on a widget-build error), and the router had no `errorBuilder` (an
  unmatched route fell back to GoRouter's plain default error page). Added
  a shared `AppErrorScreen` widget and wired it into both `main.dart`
  (`runZonedGuarded` + `ErrorWidget.builder`, logging uncaught errors via
  `debugPrint` since no crash-reporting service is configured) and
  `router.dart` (`errorBuilder` → friendly "Page not found" screen with a
  way back to the dashboard) — see the new status-table row above. Caught
  2 new unused-import lints from the change and fixed them immediately
  (net 0 new issues). Added `test/router_error_test.dart` proving an
  unmatched route renders the friendly screen instead of crashing; also
  had to fix that new test's own viewport-too-short overflow (same fix
  pattern as `app_smoke_test.dart`). `flutter analyze` clean, `flutter
  test` 16/16 passing. Skipped a live browser check for this one — the
  Browser pane's screenshot/hydration capability is still wedged from
  earlier in the session, and this change only touches error paths (no
  golden-path screen was altered), so the static verification was judged
  sufficient. Continuing to loop on further production-grade gaps.
