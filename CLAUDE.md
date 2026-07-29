# CLAUDE.md — working brain for this repo

This file loads automatically every session. It exists so you don't have to be
told the same things twice. Read it before doing anything else in this repo.

**Read these too, in this order, before starting non-trivial work:**
1. [docs/SRS.md](docs/SRS.md) — what the app does, how every module actually
   works (screens, validation, status lifecycles), per role
2. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — technical layering, data model,
   RLS/security design, the atomic RPCs and why each exists
3. [docs/AI_MODULES.md](docs/AI_MODULES.md) — the AI advisors and Voice Assistant in
   full technical depth, including an honest safety/moderation gap accounting
4. [docs/TESTING_STRATEGY.md](docs/TESTING_STRATEGY.md) — how correctness is
   actually verified, and the bug taxonomy that discipline exists to catch
5. [docs/QUALITY_MANAGEMENT.md](docs/QUALITY_MANAGEMENT.md) — quality gates,
   security-audit history, production-readiness checklist
6. [docs/MANIFESTO.md](docs/MANIFESTO.md) — why it's built this way, the quality bar
7. [docs/DEVELOPMENT_PROGRESS.md](docs/DEVELOPMENT_PROGRESS.md) — the running log of
   every round of work, every bug found, and the current module-status table. It is
   long; grep for section headers (`## `) rather than reading it linearly.

If something in this file conflicts with what you observe in the code, trust the
code and flag the conflict — this file can go stale.

---

## What this app is

**SHG Saathi (NavaSakhi)** — Flutter + Supabase app digitizing Self-Help Group
operations for rural Indian women (savings, loans, meetings, livelihoods,
marketplace, schemes, training, payments) plus a federation monitoring stack above
them (CRP → CLF → Admin). Five roles: `member`, `leader`, `crp`, `clf`, `admin`.
Full feature list: [docs/SRS.md](docs/SRS.md) §3.

## Non-negotiable architecture pattern

Every module follows this exact shape — copy it, don't reinvent it:

1. **`lib/models/<domain>.dart`** — plain Dart class + `fromMap(Map<String, dynamic>)`
   factory mirroring the Supabase table row. Joins read from PostgREST's nested map
   (`select('*, profiles(name)')` → `map['profiles']['name']`).
2. **`lib/repositories/<domain>_repository.dart`** — dual-mode, always:
   - `bool get _live => SupabaseService.isConfigured;`
   - Read methods take caller-resolved ids (read from `context.watch<AppState>().profile`,
     not re-fetched inside the repo); branch `if (!_live || id == null) return _mockXxx();`
     else real Supabase query.
   - Writes no-op when `!_live`.
   - **Never delete `lib/data/<domain>.dart` mocks** — they're the permanent
     demo-mode data source, imported `as mock`.
3. **`lib/pages/<domain>/*.dart`** — one file per screen. `AppAsyncBuilder<T>`
   (`lib/widgets/async_state.dart`) for one-shot loads; raw `StreamBuilder` only
   where realtime genuinely matters (e.g. savings ledger), not by default.
4. **`lib/routes/router.dart`** — real `GoRoute`, replacing any `comingSoon(...)` stub.
5. **Navigation is `context.go()` everywhere.** Never `push()`/`pop()` — this app
   replaces the stack, not pushes onto it. `pop()` after a submit action can have
   nothing to pop to and will misbehave.

## Security model — this is the actual boundary, not the UI

- **RLS in Postgres is authorization. Client-side role checks are UX only.** A
  hostile client can call the REST API directly, bypassing every Flutter-side
  check. Every new writable table needs its own RLS policy — don't assume a
  dashboard hiding a button is "secure enough."
- Reuse the existing `security definer` helpers — `current_role()`,
  `current_shg_id()`, `is_staff()`, `is_leader_or_staff()`, `profile_shg_id(uuid)` —
  instead of inlining an equivalent subquery. A self-referencing subquery inside a
  table's own RLS policy causes Postgres `42P17` infinite-recursion, which shipped
  to production once already (broke marketplace order updates for hours,
  undetected because nobody had actually executed the SQL path).
- No identity may escalate itself: a profile's own `role`, a loan's own approval,
  etc. must never be writable by the row's own owner.
- Lock lifecycle columns independently from row-level write access — e.g. "seller
  can update this order's status" must not imply "seller can rewrite this order's
  amount."
- Within an SHG, members share **read** access to savings/loans/meetings/ledger
  (mirrors real in-person SHG transparency). `shgs.bank_account`/`ifsc` are
  sensitive — never expose through a broadly-readable view (`shg_directory` exists
  precisely to expose only the safe subset).
- Staff roles (`crp`/`clf`/`admin`) are never self-assignable in live mode — only
  Admin can grant them. Don't "fix" this by re-enabling self-selection.

## How to actually verify something works (don't skip this)

Compiling, or reasoning that a policy "should" work, is not verification. This
codebase has a real incident where a reviewed, deployed fix silently broke a core
flow for hours because nobody executed the actual query path. Rules going forward:

- **Backend/functionality/data changes must be verified against the real live
  Supabase-backed app — not demo mode.** Demo mode is fine only for pure UI/layout
  checks (overflow, text-scale) where no backend is involved.
- **When testing RLS directly via SQL, check actual affected/visible row counts,
  never HTTP status.** An `UPDATE`/`DELETE` blocked by a `USING`-only policy (no
  `WITH CHECK`) doesn't error — it silently matches 0 rows and still returns
  success. Wrap mutations as `with r as (<stmt> returning 1) select count(*) from r`
  and assert on the count.
- Test all four RLS boundary cases per table: owner-can-write-own-row,
  wrong-role-denied, shared-SHG-read, cross-tenant-isolation (different SHG can't
  see this one's rows).
- If you create test fixtures against the live DB, prefix them unmistakably (e.g.
  `__TEST__`, fixed recognizable UUIDs) and **delete every row afterward, verified
  by re-querying zero rows remain.** Never leave synthetic data in the live project.
- In the Browser pane, **trust the semantics tree over screenshots** —
  `read_page`/`javascript_tool` + `getBoundingClientRect` have been reliable even
  when `computer{screenshot}` visually misrenders text on a correctly-hydrated tab.
  Use screenshots for coarse sanity checks only, not for judging text-wrap/overflow.
- **Root-caused after 15 consecutive false "stuck" rounds (2026-07-29): the
  `flt-glass-pane` children-count check is invalid for this app's build and must
  never be used again.** This build renders with the CanvasKit renderer (WebGL
  canvas), which paints pixels directly and never populates `flt-glass-pane`'s
  DOM children the way the HTML renderer would — `children.length` stays `0`
  forever even on a fully, correctly rendered page. Every prior round that
  concluded "stuck" from this check alone was **wrong** and skipped real UI
  verification that would have worked. **To verify Flutter web actually
  rendered: take a `computer{screenshot}` or check `document.body.innerText`
  for real page content — never `flt-glass-pane.children.length`.**
- The second real cause of stuck-looking tabs: **a backgrounded/non-frontmost
  tab never gets a first paint** — Flutter Web schedules its first frame via
  `requestAnimationFrame`, which Chromium throttles to never-fires for a tab
  with `document.visibilityState !== 'visible'`. `preview_start` opening a tab
  does not guarantee it's the frontmost one. Always `tabs_select` the target
  tab (or confirm `document.hasFocus()`/`visibilityState === 'visible'` via
  `javascript_tool`) **before** judging whether it rendered, and prefer
  navigating/reloading only after the tab is already fronted.
- The third cause: **`.claude/launch.json`'s `flutter-web`/`flutter-web-live`
  configs run `flutter run -d chrome`**, a debug dev-server that spawns and
  waits (sometimes 80s+) for its own separate Chrome instance to connect via a
  debug-service websocket — the Browser pane's tab is a different browser
  context and never completes that handshake, so the app may never truly start
  there even though the server log eventually shows "Supabase init completed"
  (that success is for whatever browser Flutter itself launched, not the
  Browser pane tab). **Use `flutter-web-release` instead** (`npx serve -l 5002
  build/web`, a plain static file server, no debug handshake required) — run
  `flutter build web --release --dart-define-from-file=.env.json` first for a
  live-mode build (bare `flutter build web` with no dart-defines silently
  produces a **demo-mode** build, since `Env.supabaseUrl`/`supabaseAnonKey`
  read via `String.fromEnvironment` are empty without those flags — rebuild
  with the flag any time you need to verify against the real backend, not just
  UI/layout).
- If, after fronting the tab and confirming a `flutter-web-release` build,
  a screenshot genuinely shows a blank page with no console/network errors,
  **then** treat it as actually stuck: don't repeat the same diagnostic loop,
  and fall back to DB-level verification rather than silently giving up on
  verification entirely.
- **After adding a NEW plugin package to `pubspec.yaml` (round: training-video
  upload), a normal `flutter build web` can silently reuse a stale cached
  `.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart` that predates
  the new plugin** — the new package appears in `.flutter-plugins-dependencies`
  and even gets tree-shaken into `main.dart.js`, but its `registerWith()` call
  is never actually wired into `registerPlugins()`, so the plugin's platform
  interface stays the unimplemented default (symptom: a web-only
  `UnimplementedError: <method>() has not been implemented` at the exact call
  the new plugin should have handled — for `video_player_web` specifically,
  this manifested as every attached video failing to load with **zero**
  console output, because the failure happened before any `<video>` element
  or network request was ever created, and was being silently swallowed by
  the feature's own error-handling `catch` block). Confirm the actual root
  cause by checking `.dart_tool/flutter_build/*/web_plugin_registrant.dart`
  for the new plugin's `registerWith` call — if it's missing despite the
  plugin being in `.flutter-plugins-dependencies`, run `flutter clean` before
  rebuilding (a plain rebuild after just adding the dependency is not
  sufficient once this staleness has already occurred once).
- **Browser-pane `navigate` calls that only change the URL's hash fragment
  (e.g. `#/app/a` → `#/app/b`) do not reliably force a real page
  reload/re-fetch of `main.dart.js`** — the SPA may just update client-side
  routing without ever re-requesting the script, so a code change (or the
  stale-plugin-registrant fix above) can silently keep running the OLD
  compiled bundle even after `navigate{force:true}` to the new hash. Verify
  what's actually loaded with `fetch('/main.dart.js', {cache:'no-store'})`
  and check for a marker string; if the running tab is stale, navigate to a
  URL with a **different query string** (e.g. `?v=2#/app/...`), which forces
  a genuine full document reload.

## Quality bar (why this file exists)

The most common failure mode in this project has been claiming something is done
when it wasn't actually exercised. Before saying a task is complete:

- [ ] Does it work in **both** demo mode and live mode?
- [ ] Does every role that should have access have it, and every role that
      shouldn't is actually blocked **at the RLS layer**, not just hidden in UI?
- [ ] Are new user-facing strings added to **all three** `.arb` files
      (`app_en.arb`, `app_hi.arb`, `app_te.arb`), not just English?
- [ ] Does the layout survive a large text-scale setting (1.3x–2x) without
      clipping/overflow?
- [ ] Was the actual change exercised — a real UI click-through or a real query
      against real RLS — not just read and reasoned about?
- [ ] If it's an intentional placeholder (scheme eligibility heuristic, generic
      course quiz, admin monitoring metrics), is that documented as a placeholder,
      not presented as authoritative?

If you cannot verify one of these (e.g. no live preview available this session),
say so explicitly rather than reporting success. See
[docs/MANIFESTO.md](docs/MANIFESTO.md) for the reasoning behind this bar.

## Other conventions

- Third-party API integrations get an interface in `lib/services/` with a `Mock*`
  fallback (see `ai_advisor_service.dart`) — swapping the real provider later
  should be a one-file change.
- Avoid N+1 queries — use PostgREST embedded selects (`select('*, profiles(name)')`),
  not a query-per-row loop.
- After a meaningful round of work (a module built, a bug class found and fixed,
  an audit completed), add a dated entry to
  [docs/DEVELOPMENT_PROGRESS.md](docs/DEVELOPMENT_PROGRESS.md) — that log is what
  lets the next session pick up context instead of re-discovering it.
- Update [docs/SRS.md](docs/SRS.md) when a feature's actual scope changes (a
  placeholder becomes real, a role's access changes, a new module ships) — it
  should describe the app as it actually is, not as it was at v1.0.
- The doc suite cross-references instead of duplicating: RLS/schema/RPC detail
  lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), AI implementation
  detail in [docs/AI_MODULES.md](docs/AI_MODULES.md), test methodology in
  [docs/TESTING_STRATEGY.md](docs/TESTING_STRATEGY.md), and release/quality
  gates in [docs/QUALITY_MANAGEMENT.md](docs/QUALITY_MANAGEMENT.md). When you
  fix a bug or close a gap that one of these documents calls out as a known
  placeholder or limitation, update that document in the same change — a doc
  that still says "not implemented" after the feature ships is actively
  misleading, worse than no doc at all.
