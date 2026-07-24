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
- If the Browser pane's Flutter web tab gets stuck (`flt-glass-pane` never gains
  children — check `document.querySelector('flt-glass-pane').children.length`),
  don't repeat the same diagnostic loop. Try: `preview_start` a server, then
  immediately open a **fresh** tab and navigate it to that server's URL exactly
  once, without touching the `preview_start`-opened tab. If still stuck, say so and
  fall back to DB-level verification rather than silently giving up on
  verification entirely.

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
