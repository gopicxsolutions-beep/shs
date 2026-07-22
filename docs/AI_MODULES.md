# AI Modules — Technical Deep Dive

SHG Saathi ships four AI-branded features: three LLM chat advisors (Financial,
Scheme, Market) sharing one screen, and a Voice Assistant. This document
describes exactly how each works, what's real versus mocked, and — because
these are the app's highest-risk surface (giving financial/scheme/market
guidance to a user base with limited digital literacy) — an honest account of
what safety controls exist and which don't.

For where this fits in the overall architecture, see
[ARCHITECTURE.md](ARCHITECTURE.md). For the SRS-level feature requirements,
see [SRS.md](SRS.md) §3.14.

---

## 1. Architecture overview

```
Flutter client (AiAdvisorChatPage)
   → AiAdvisorRepository.ask()
      → AiAdvisorService.ask()                    [interface]
         ├─ EdgeFunctionAiAdvisorService            live mode
         │     supabase.functions.invoke('ai-advisor-proxy', {advisor_type, query})
         │     → Edge Function (Deno)
         │         → checks/increments ai_advisor_rate_limits (Postgres RPC)
         │         → POST https://api.groq.com/openai/v1/chat/completions
         │         ← { choices[0].message.content }
         │     ← { ok: true, response } or { ok: false, error }
         └─ MockAiAdvisorService                    demo mode
   → AiAdvisorRepository writes {member_id, advisor_type, query, response}
     to ai_advisor_logs (best-effort, RLS-protected; skipped in demo mode)
```

**Mode selection**: `AiAdvisorRepository`'s constructor picks
`EdgeFunctionAiAdvisorService()` if `SupabaseService.isConfigured`, else
`MockAiAdvisorService()`. The chat UI is byte-for-byte identical either way —
only the answer source and whether a log row gets written differ. This is the
same live/demo pattern used everywhere else in the app (see
[ARCHITECTURE.md](ARCHITECTURE.md) §1), applied to a third-party LLM instead
of Supabase's own tables.

**Why the LLM key never reaches the client**: the Groq API key
(`LLM_API_KEY`, a `gsk_`-prefixed secret) is set via `supabase secrets set` and
read only inside the Edge Function with `Deno.env.get('LLM_API_KEY')`. It is
never bundled into the Flutter client and never crosses the wire to the app.
The function throws a 500 immediately if the secret is absent, rather than
silently degrading to a canned response — a missing key is a deployment
error, not a state the app should paper over.

**Auth boundary**: `verify_jwt` is enforced at the Supabase Edge Function
gateway (validates JWT signature/expiry before the handler runs at all).
Inside the function, the JWT's `sub` claim is decoded (not re-verified — that
already happened at the gateway) purely to identify which member to
rate-limit. The function itself is otherwise stateless; it never persists
anything — logging happens entirely client-side, after the response comes
back.

---

## 2. The three chat advisors

Financial Advisor, Scheme Recommender, and Market Advisor are **one shared
screen**, `AiAdvisorChatPage(advisorType, title, hint)`, parameterized across
three routes (`/app/ai/financial-advisor`, `/app/ai/scheme-recommender`,
`/app/ai/market-advisor`) plus a hub page (`/app/ai`) and the separate Voice
Assistant (`/app/ai/voice-assistant`, §3).

### 2.1 System prompts (exact text, from `ai-advisor-proxy/index.ts`)

```ts
const SYSTEM_PROMPTS: Record<string, string> = {
  financial: 'You are a financial advisor for an Indian Self-Help Group (SHG) member. Give short, practical guidance on savings, loans, and budgeting. Keep replies under 80 words.',
  scheme:    'You help an Indian SHG member find relevant government welfare schemes (DAY-NRLM, MUDRA, PMEGP, etc). Keep replies under 80 words.',
  market:    'You advise an Indian SHG member on pricing and selling handmade/farm products. Keep replies under 80 words.',
};
```

Each request to Groq is a single `[system, user]` message pair:

```json
{ "model": "llama-3.3-70b-versatile", "messages": [ {"role":"system","content": <one of the above>}, {"role":"user","content": <query>} ], "max_tokens": 150 }
```

No `temperature` is set (provider default applies). `max_tokens: 150` caps the
completion; a client-side `MAX_QUERY_LENGTH = 2000` characters caps the input.

**No conversation memory is sent to the model.** The chat history visible in
the UI is a client-side replay of the member's own past `ai_advisor_logs` rows
for that `advisor_type`, loaded once on page open — it is not fed back into
later requests. Each question is answered by the model with zero awareness of
anything the member asked earlier in the same session, let alone earlier
sessions. There is also no per-member profile/SHG context (savings balance,
loan status, village) injected into the prompt — the advisor answers from the
question text alone.

### 2.2 Conversation flow (client-side)

1. On open, load history for `(memberId, advisorType)`, render each row as a
   pair of chat bubbles (question, then answer).
2. On send: trim input, ignore if empty or a send is already in flight,
   optimistically show the question bubble, clear the field, call the
   repository.
3. **No streaming** — the Edge Function returns the full completion in one
   response. A spinner replaces the send icon while waiting; the whole answer
   appears at once.
4. Auto-scroll to the newest bubble is deferred one frame
   (`addPostFrameCallback`) so the just-appended bubble's real height is
   accounted for before computing the scroll extent.
5. **Error handling collapses server detail into two generic messages**: a
   genuine network failure shows a localized "check your internet connection"
   string; *everything else* — a 429 rate-limit, a 502 upstream failure, a 500
   misconfiguration — shows the same generic "Something went wrong. Please try
   again." **A rate-limited member cannot tell from the UI that the fix is
   simply to wait a minute** — she sees an identical message to any other
   failure. This is a deliberate simplification in the existing error-handling
   pattern (network vs. not), not a bug, but it's worth flagging as a real UX
   gap for a rate-limit specifically.
6. No suggested prompts, no quick-reply chips — free-text input only, with an
   advisor-specific placeholder hint shown while the chat is empty.
7. Each bubble is wrapped in `Semantics(label: '<You|Advisor>: <text>')` so a
   screen reader announces one clean node per message.

### 2.3 What a member cannot get from this feature

- No memory of prior turns or sessions (§2.1).
- No personalization from her actual savings/loan/SHG data.
- No indication, in the UI, of *which* specific failure occurred (§2.2 point 5).
- No content moderation or prompt-injection defense (§6) — a persistent disclaimer is shown, but the model's answers themselves aren't filtered or checked.

---

## 3. Voice Assistant

**There is no real speech-to-text or text-to-speech anywhere in this
codebase.** Both `VoiceRecognitionService` (used by the AI Voice Assistant
page) and `VoiceSupportService` (used by the separate, generic Support
module's Voice Support feature) are entirely mock implementations, and say so
in their own doc comments: *"No real STT provider is wired yet — a production
key would swap `MockVoiceRecognitionService` for a real implementation of this
same interface without touching any call site."*

### 3.1 What the mock actually does

`MockVoiceRecognitionService.listen(Language)`: after a simulated ~700ms
delay, round-robins through a **fixed list of 4 canned commands per language**
(Telugu/Hindi/English), each pre-mapped to a `VoiceIntent`
(`loanDetails`, `savingsThisMonth`, `readAnnouncements`, `addSavings`,
`unknown`). It does not access a device microphone, does not call any
platform speech API, and does not perform language detection — "language" is
simply which canned list the mock cycles through, chosen by the user via a
`ChoiceChip` on the page itself. There is **no text-to-speech/audio playback
at all** — `VoiceSupportService.answer()`'s own doc comment even notes "a real
implementation would also synthesize and play back audio for it," confirming
today's version returns text only, shown in a card.

**What is genuinely real**: once an intent is recognized, the page resolves it
against the member's **actual live data** via the real `LoanRepository`,
`SavingsRepository`, and `AnnouncementRepository` — so the answer's *content*
(loan purpose/amount/outstanding, this month's savings total, real
announcement titles) is genuine, not canned text. The "add savings" intent
navigates to the real Savings Entry form after a short delay — this is
"voice-triggered navigation to a form," explicitly scoped down from full voice
dictation into form fields, since real dictation isn't feasible without a
live STT engine.

**Native permissions confirm this**: neither `AndroidManifest.xml` nor
`Info.plist` declares a microphone permission (`RECORD_AUDIO` /
`NSMicrophoneUsageDescription`), and no speech-recognition package appears in
`pubspec.yaml`. The mic icon on the Voice Assistant page is a static UI
element, not a live input device.

### 3.2 Language handling

The Voice Assistant page has its **own language selector**, independent of the
app's system-wide display language (`AppState.language`) — a member can "ask"
in a different language than her UI language, the same way a real voice
assistant lets you speak in one language regardless of your phone's UI
language. Answers are resolved via an explicit-locale lookup
(`lookupAppLocalizations(_localeFor(_language))`), **not** the ambient
`AppLocalizations.of(context)` — this distinction is the exact axis two real,
historical bugs broke on (§3.3).

### 3.3 Historical bug: "Voice Assistant always defaulting to Telugu" (fixed, commit `16243e9`)

**Bug**: the page's language field was a hardcoded initializer
(`Language _language = Language.te;`), so every member — regardless of their
actual app-wide language preference — opened the Voice Assistant pre-selected
to Telugu, every time.

**Fix**: seed `_language` from `AppState.language` in `initState()` instead of
hardcoding it. Discovered and live-verified with a QA account set to English —
the page now opens pre-selected to English.

**Related follow-on regression, caught live**: after localizing the answer
templates, live-testing found that selecting Hindi via the page's *own*
language chip and asking a Hindi question **still produced a Telugu answer**
— because the answer-resolution code used the ambient `.of(context)` accessor
(system locale) rather than the page-local `_language` selection, so it
ignored the override entirely and read whatever the system happened to be set
to. Fixed by switching to the explicit-locale lookup described in §3.2. This
is a good illustration of why "which locale accessor" is not a stylistic
choice in this codebase — the two accessors answer genuinely different
questions (system-wide vs. page-local intent), and this page needs the latter.

---

## 4. Logging and audit

**Schema** (`ai_advisor_logs`):

```sql
create table public.ai_advisor_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles (id) on delete cascade,
  advisor_type text not null check (advisor_type in ('financial', 'scheme', 'market')),
  query text not null,
  response text,
  created_at timestamptz not null default now()
);
```

Note the CHECK constraint only permits `financial`/`scheme`/`market` —
`'voice'` is not a valid value. **The Voice Assistant does not write to this
table at all**; no audit/log table exists anywhere for voice interactions.

**RLS**:
- SELECT: the member herself, or any staff role (`is_staff()`).
- INSERT: only your own `member_id`.
- **No UPDATE policy and no DELETE policy exist** — logged Q&A pairs are
  immutable and permanent from the client's perspective.
- **No retention/TTL/archival mechanism** — logs accumulate indefinitely by
  default (unlike the separate rate-limit table, which self-prunes after an
  hour — see §5). There is no admin-facing purge tool.

---

## 5. Rate limiting (exact mechanism)

Implemented as a Postgres-side atomic counter, called from the Edge Function
before it spends a paid Groq call.

- **Limit**: 10 requests per 60-second window, **per member** (keyed by
  `member_id` from the caller's own JWT — not per-IP).
- **Fixed window**, table `ai_advisor_rate_limits (member_id, window_start,
  request_count, primary key(member_id, window_start))`.
- **Atomicity**: `INSERT ... ON CONFLICT (member_id, window_start) DO UPDATE
  SET request_count = request_count + 1 RETURNING request_count`, inside a
  `security definer` function — this serializes concurrent requests for the
  same member through Postgres row-locking *even across different Edge
  Function isolates*, which is why it isn't a naive in-process counter:
  Supabase Edge Functions are independent, horizontally-scaled Deno isolates
  with no shared memory, so an in-isolate counter is trivially bypassed by two
  concurrent requests landing on different isolates.
- **Self-cleaning**: every call opportunistically deletes rows older than an
  hour — no separate cron needed.
- **Locked down**: `EXECUTE` on the check-and-increment function is revoked
  from `PUBLIC`, granted only to `service_role` — a client cannot call it
  directly to inspect or reset its own counter.
- **Fails closed**: if the caller's identity can't be resolved → HTTP 401. If
  the rate-limit check itself errors (e.g. the migration isn't deployed) →
  HTTP 500, rejecting the request rather than silently letting it through
  unmetered.
- **On exceeding the limit**: the Edge Function throws
  `HttpError(429, 'Too many requests. Please wait a minute before asking
  again.')` — collapsed by the client into the generic error message per §2.2.
- **This closed a real, long-standing gap**: the migration's own header
  comment states the no-rate-limiting issue was "re-confirmed, un-fixed,
  across at least 3 prior audit rounds" before this fix landed — i.e. the app
  ran for multiple development rounds with **no limit at all** on real, paid
  Groq calls before this was closed.

---

## 6. Safety and moderation — honest accounting

**What exists:**
- Server-side API key custody (never shipped to the client).
- Input cap: 2,000 characters. Output cap: 150 tokens.
- Per-member rate limiting, 10/minute (§5).
- `advisor_type` validated against a fixed whitelist before selecting a system
  prompt.
- Distinct HTTP status codes server-side (400/401/429/500/502) for different
  failure classes, even though the client currently flattens most of them
  (§2.2).
- Upstream provider error bodies are logged server-side but never echoed back
  to the caller verbatim.
- **A disclaimer is shown on every AI-branded screen**: `AiDisclaimerBanner`
  (`lib/widgets/ai_disclaimer_banner.dart`) renders a persistent, non-
  dismissible banner — "AI-generated guidance — may be inaccurate. Not
  professional financial, legal, or medical advice; confirm important
  decisions with your SHG leader or a qualified advisor." — on the AI hub,
  the shared chat page (all 3 advisors), and the Voice Assistant
  independently, localized in all three languages (`aiDisclaimer` key).

**What is explicitly absent — confirmed not present in code, not merely
unverified:**
- **No prompt-injection mitigation.** The raw user query is passed directly as
  the `user` message with no escaping, no instruction-hardening wrapper, no
  delimiter strategy, and no check for an attempt to override the system
  prompt. Nothing distinguishes "the member's question" from "an instruction
  to the model" beyond ordinary chat-role separation.
- **No content moderation on input** — no profanity filter, no PII
  detection/redaction, no jailbreak/abuse classifier before a query reaches
  Groq or gets written to `ai_advisor_logs`.
- **No content moderation on output** — the completion is returned and stored
  verbatim; there is no safety classifier pass, no check that the answer
  actually stayed within the advisor's intended scope.
- **No cross-turn abuse detection** — since each request is single-turn with
  no memory (§2.1), there's also no mechanism to notice a multi-message
  manipulation attempt building up across turns.
- **No anomaly/abuse monitoring on the logs** — `ai_advisor_logs` is written
  and retained, and staff can read it via RLS, but nothing in the codebase
  queries it for abuse patterns or flags anything for review.

This is a deliberately lightweight LLM integration from a safety-engineering
standpoint: it leans entirely on (a) a short, narrowly-scoped system prompt per
advisor, (b) the upstream provider's own model-level safety behavior, and (c)
cost/abuse controls (length cap + rate limit), now paired with (d) an
in-UI disclaimer on every AI-branded screen — but still **no application-
layer content moderation**. Any production launch that scales real usage of
the advisors' financial/scheme guidance should treat prompt-injection/content-
moderation as the remaining highest-priority gap in this section — unlike
the disclaimer (a one-screen UI change, now shipped), moderation needs a real
design decision about where to draw the line and what provider/approach to
use.

---

## 7. Known limitations and placeholders (self-disclosed in code/docs)

- **STT/TTS is entirely unimplemented** — the whole "External API abstraction
  plan" convention (interface + `Mock*`, see [ARCHITECTURE.md](ARCHITECTURE.md)
  §1) exists precisely so a real provider can be wired later without touching
  any call site; as of today, none is.
- **Voice Assistant recognizes only 5 fixed intents** (4 canned commands per
  language + `unknown`), not open-ended speech.
- **Chat advisors have no cross-turn memory** sent to the model (§2.1).
- **Client error handling flattens specific server errors** into two generic
  messages, so a member can't distinguish "you're asking too fast" from "the
  service is down" (§2.2, §5).
- **`ai_advisor_logs` has no retention policy** — indefinite accumulation, no
  purge tool (§4).
- **No application-layer content moderation or prompt-injection defense**
  (§6) — the remaining highest-priority item in this list before scaling
  real usage of the advisors' financial/scheme guidance. (The disclaimer gap
  that used to be listed here is fixed — see §6.)
