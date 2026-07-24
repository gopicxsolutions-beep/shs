# SHG Saathi — Product Manifesto

This is the "why and how," not the "what." For the full feature spec, see
[SRS.md](SRS.md); for technical architecture, [ARCHITECTURE.md](ARCHITECTURE.md);
for the AI modules specifically, [AI_MODULES.md](AI_MODULES.md); for how
correctness is verified, [TESTING_STRATEGY.md](TESTING_STRATEGY.md); for
release/quality gates, [QUALITY_MANAGEMENT.md](QUALITY_MANAGEMENT.md). For
agent working rules, see [CLAUDE.md](../CLAUDE.md).

## Who we serve

A rural SHG member is often the least digitally-literate, most risk-averse user of
any product we could design for. She is trusting this app with her group's actual
savings and her own creditworthiness. Above her sits a chain of real
responsibility — leader, CRP, CLF, admin — each of whom is accountable for money and
decisions that affect other people's livelihoods, not abstractions.

**Every design and engineering decision is judged against: does this make the app
more trustworthy and usable for her, first — and only then more useful for the
hierarchy above her.**

## What we believe

**1. Transparency is the product, not a feature.**
Real SHGs already run on shared visibility — the ledger is read out at meetings, the
loan book is common knowledge within the group. The app's read-access model (every
member can see their SHG's savings/loans/ledger) isn't a permissions default we
picked for convenience; it's a direct translation of how SHGs already work. When a
new feature needs an access decision, ask what the group would already do in
person, not what's easiest to implement.

**2. Security is not a layer you add later — it's the actual authorization
boundary.**
Client-side role checks are UX sugar. Row-Level Security in Postgres is the real
gate, because a client can always call the API directly. We have shipped, found,
and fixed real privilege-escalation bugs in this codebase — a member escalating
themselves to Admin, a borrower approving their own loan. Every new writable table
gets an RLS policy that assumes the client is hostile, not merely that it's honest
software following the rules.

**3. It must work with nothing behind it.**
Demo/offline mode is a first-class product requirement, not a fallback. A field
demo, a low-connectivity village, or a reviewer with no Supabase project should see
the exact same app, fully navigable, with realistic mock data. If a feature only
works when a backend is configured, it isn't done.

**4. Claims of "it works" must be earned, not assumed.**
Code that compiles is not code that works. A migration that applies without error
is not a policy that behaves correctly under a real hostile or real legitimate
request. This project's history includes a security fix that shipped, passed
review, and was live-broken for hours before anyone actually executed the SQL path
against a real request. We test the real thing — a real UI click-through, a real
REST call with a real JWT — before calling something fixed or done. See
[CLAUDE.md](../CLAUDE.md) for the concrete verification discipline this implies.

**5. Placeholders must say they're placeholders.**
The admin monitoring panel's system-uptime figure, the mocked payment gateway — some
things are intentionally not-yet-real, usually because the real version needs an
external credential or vendor account this codebase can't provision for itself. That's
fine. What's not fine is presenting a heuristic as authoritative or a mock metric as
live infrastructure data. Every placeholder is documented as one, in the code and in
the SRS, so nobody — user, teammate, or future agent — mistakes a stand-in for a
finished feature.

**6. Language and literacy are not an afterthought.**
English-only is a shipped bug for this user base, not a v2 nice-to-have. Every
user-facing string ships in English, Hindi, and Telugu together. The voice
assistant exists because typing is a barrier for some of our actual users, not
because voice is a trendy feature.

**7. Small, correct, and consistent beats clever.**
This codebase has one way to fetch data (repository, dual-mode), one way to
navigate (`context.go()`), one way to model a table (plain class + `fromMap`). New
code follows the existing shape even when a developer could imagine a nicer one.
Consistency is what lets a fresh session — human or agent — trust the pattern
instead of re-deriving it.

## What we will not do

- We will not add a feature that only works for the digitally fluent and silently
  degrades for everyone else.
- We will not ship an access-control decision that relies on the UI hiding a
  button.
- We will not claim a fix is deployed until it has been observed working against
  the real system it's meant to protect.
- We will not let a mock/demo data path go stale or get deleted just because a real
  backend now exists — offline mode is permanent, not transitional.
- We will not silently narrow scope (skip a role, skip a language, skip an edge
  case) to make a task look finished faster.

## Definition of done

A feature is done when: it works in both demo and live mode; every role that
should see it can, and no role that shouldn't can (verified via RLS, not just UI);
strings exist in all three languages; it survives a large text-scale setting; and
someone has actually exercised it end-to-end against the real system, not just read
the code and reasoned that it should work.
