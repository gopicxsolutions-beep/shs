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

Each request to Groq now carries **real cross-turn conversation memory**:
`[system, ...prior user/assistant turns, user]`, built by
`ai-advisor-proxy/history.ts`'s `buildMessagesWithHistory()`:

```json
{ "model": "llama-3.3-70b-versatile", "messages": [ {"role":"system","content": <hardened system prompt>}, {"role":"user","content": <prior query 1>}, {"role":"assistant","content": <prior answer 1>}, "...", {"role":"user","content": <new query>} ], "max_tokens": 150 }
```

`AiAdvisorRepository` keeps a small in-memory list of the current chat
session's prior `(query, response)` exchanges and forwards the most recent
slice with every new `ask()` call — since one `AiAdvisorRepository` instance
is created fresh per open `AiAdvisorChatPage` (a plain `GoRoute`, no
state-preserving shell), this naturally resets on leaving/reopening the page
or restarting the app, which is all real session-scoped memory needs; nothing
persists to a database beyond the existing `ai_advisor_logs` audit trail.
Bounded independently on both ends so a long-running chat can't make the
request grow unbounded: capped at the 6 most recent exchanges
(`MAX_HISTORY_EXCHANGES`), then further trimmed (oldest first) if their
combined length exceeds 6,000 characters (`MAX_HISTORY_TOTAL_CHARS`) — this
is in addition to, not instead of, `MAX_QUERY_LENGTH = 2000` characters on
the *new* query alone, and a hard cap of 20 raw entries
(`MAX_HISTORY_RAW_ENTRIES`) checked before any per-entry validation runs, so
an oversized client-supplied array can't inflate validation cost per
request. The content pre-filter (§6) runs over every forwarded history
entry's **both** fields — `query` *and* `response` — not just the live
query, via `checkHistoryForDisallowedContent()`: otherwise a caller could
bypass it either by hiding disallowed content in a history query, or (the
sharper bypass) by fabricating a disallowed `response` field — nothing
server-side can verify a client-supplied `response` is genuinely prior model
output rather than an attacker-planted fake "assistant" turn designed to
prime the live model with a jailbreak immediately before an innocent-looking
question.

No `temperature` is set (provider default applies). `max_tokens: 150` still
caps only the completion. There is still no per-member profile/SHG context
(savings balance, loan status, village) injected into the prompt — the
advisor answers from the conversation text alone, no live data lookup.

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
5. **Error handling now surfaces the server's real, specific reason** instead
   of collapsing everything into two generic messages. The root cause of the
   old flattening was deeper than a UI simplification: `supabase_flutter`'s
   `FunctionsClient.invoke()` throws a `FunctionException(status, details,
   reasonPhrase)` for any non-2xx response, so the old client-side `data['ok']
   != true` check never actually ran for a real server rejection — every
   failure surfaced as an untyped `Exception` indistinguishable from a
   dropped connection. Fixed via `mapFunctionExceptionToAdvisorException()`
   (`ai_advisor_service.dart`), which now branches: a 400 (the content
   pre-filter or a validation rejection, §6) or 429 (rate limit) shows the
   server's own reason text **verbatim** — this is what makes the pre-filter's
   supportive self-harm-resources message and the rate-limit's "wait a
   minute" message actually reach the member; 401/500/502 map to one shared,
   honest "advisor service temporarily unavailable" message (their raw
   reasons, e.g. "Internal error", aren't written for an end user to read);
   anything else still falls through to the pre-existing network/generic
   fallback, unchanged. A rate-limited member can now tell from the UI that
   the fix is simply to wait a minute.
6. No suggested prompts, no quick-reply chips — free-text input only, with an
   advisor-specific placeholder hint shown while the chat is empty.
7. Each bubble is wrapped in `Semantics(label: '<You|Advisor>: <text>')` so a
   screen reader announces one clean node per message.

### 2.3 What a member cannot get from this feature

- Memory resets between sessions — real memory now exists *within* one open
  chat session (§2.1), but nothing persists across reopening the page, app
  restart, or a different device.
- No personalization from her actual savings/loan/SHG data.
- A persistent disclaimer is shown, plus a basic keyword-based moderation/prompt-injection layer server-side (§6) — the specific rejection reason now *is* surfaced to her (§2.2 point 5), but it's still not enterprise-grade moderation.

---

## 3. Voice Assistant

**Real, on-device speech-to-text and text-to-speech are wired in live mode.**
Both `VoiceRecognitionService` (used by the AI Voice Assistant page) and
`VoiceSupportService` (used by the separate, generic Support module's Voice
Support feature) follow this app's standard interface-plus-`Mock*` pattern:
`DeviceVoiceRecognitionService`/`DeviceVoiceSupportService`
(`lib/services/device_voice_*.dart`) are the live-mode implementations,
selected whenever `SupabaseService.isConfigured`; `MockVoiceRecognitionService`/
`MockVoiceSupportService` remain in demo mode so the app stays fully explorable
with no microphone. No vendor API key or account is needed for either
direction — both Android (`SpeechRecognizer`) and iOS (`SFSpeechRecognizer`)
ship a built-in on-device speech engine, which the `speech_to_text` package
talks to directly; `flutter_tts` likewise drives each platform's built-in
speech synthesizer.

### 3.1 What the real implementation does

`DeviceVoiceRecognitionService.listen(Language)`: initializes `speech_to_text`
(prompting the OS microphone/speech-recognition permission on first use),
resolves a device-installed locale by language-code prefix (preferring an
`*-IN` region variant, e.g. `te-IN`/`hi-IN`/`en-IN`, falling back to the
engine's own default if the device has no exact match), then listens for up
to 10 seconds (or 3 seconds of trailing silence) and returns the final
transcript. The transcript is then classified into a `VoiceIntent`
(`loanDetails`, `savingsThisMonth`, `readAnnouncements`, `addSavings`,
`unknown`) by `VoiceIntentClassifier` — a small per-language keyword matcher
(`lib/services/voice_intent_classifier.dart`), since a real STT engine returns
arbitrary free text rather than one of a fixed canned set. An empty/silent
transcript or a device with no available recognizer throws, which the page
surfaces as a friendly retry message rather than crashing.
`DeviceVoiceSupportService` follows the same listen-and-transcribe shape for
Support's free-form question, then matches the question against the same FAQ
content shown on the (text) FAQ page by keyword overlap — not a separate
canned answer bank — and speaks the matched answer back via `flutter_tts`.

Text-to-speech (`AiVoiceAssistantPage._speak`) checks
`FlutterTts.isLanguageAvailable` before speaking and silently no-ops if the
device has no installed voice for the selected language — playback is a bonus
on top of the answer, which is always shown as text regardless, since not
every device ships a TTS voice for every language.

**What is genuinely real** (unchanged by this move from mock to device STT):
once an intent is recognized, the page resolves it against the member's
**actual live data** via the real `LoanRepository`, `SavingsRepository`, and
`AnnouncementRepository` — so the answer's *content* (loan purpose/amount/
outstanding, this month's savings total, real announcement titles) is
genuine, not canned text. The "add savings" intent navigates to the real
Savings Entry form after a short delay — this is "voice-triggered navigation
to a form," explicitly scoped down from full voice dictation into form
fields, since dictating directly into arbitrary form fields is a materially
larger feature than recognizing a bounded command set.

**Native permissions**: `AndroidManifest.xml` declares `RECORD_AUDIO` (plus an
optional `android.hardware.microphone` feature) and `Info.plist` declares
`NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` —
genuinely required and used, not vestigial.

**Not live-tested with a real human voice in this environment**: the sandboxed
Browser pane tool cannot supply real microphone input, and (per the
already-documented camera-permission finding in
[DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md)) triggering a live
microphone-permission prompt risks the same session-wide Browser-pane wedge
already seen for camera access. Verification for this feature therefore rests
on `flutter analyze` (clean), `flutter test` (all passing, including new
`VoiceIntentClassifier` coverage), and code review — a real device/browser
with microphone access should be used to confirm actual recognition accuracy
before shipping.

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
- **No UPDATE policy and no DELETE policy exist for clients** — logged Q&A
  pairs remain immutable and permanent from the client's perspective; this is
  unchanged.
- **Retention is now real, but server-side/privileged only**:
  `public.purge_old_ai_advisor_logs()` (migration `0043`, `SECURITY DEFINER`)
  deletes rows older than 180 days, scheduled nightly via `pg_cron` (mirrors
  `ai_advisor_rate_limits`' own self-pruning pattern, and
  `generate-report-snapshots`' pg_cron scheduling pattern — the simpler of
  the two, since no HTTP hop to an Edge Function is needed for a plain
  in-database delete). `EXECUTE` is revoked from `PUBLIC` and granted only to
  `service_role`, so it is not reachable as a client-callable PostgREST RPC —
  no new client-facing DELETE path was opened to achieve this. 180 days is a
  stated operational default (this table is a staff-readable audit trail,
  not a transient cache), not a compliance-mandated figure, and is
  explicitly revisitable. **Not yet deployed or executed against a live
  database this session** — written correctly per this repo's established
  migration conventions, needs live deployment and the verification steps
  documented in the migration's own header before being considered done.

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
- **Ordering matters and was itself a bug**: the member-identification +
  rate-limit check now runs immediately after the basic `advisor_type`/`query`
  shape check, *before* history-shape validation or content moderation. An
  earlier version ran validation/moderation first — so a caller could send
  unlimited requests per minute for free simply by ensuring every request was
  rejected by validation or the moderation pre-filter before it ever reached
  the rate-limited RPC. Fixed by moving the identity + rate-limit check
  earlier in `index.ts`'s request-handling sequence.

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

**A basic first line of defense now exists** (`supabase/functions/ai-advisor-proxy/moderation.ts`),
using only the already-provisioned Groq key — no new paid moderation vendor:
- **Prompt-injection hardening**: the user's raw query is wrapped in matching
  `<<<BEGIN_USER_QUESTION>>>`/`<<<END_USER_QUESTION>>>` delimiters
  (`buildUserMessage()`), and each advisor's system prompt gets an appended
  instruction to treat delimited text strictly as a question to answer, never
  as instructions — even if it claims developer/system/admin authority or
  asks the model to ignore/reveal/override its instructions
  (`buildSystemPrompt()`). This is the well-known "sandwich defense" pattern —
  a real, honest improvement over zero mitigation, not a guarantee against a
  determined, creatively-worded attacker.
- **A server-side content pre-filter** (`checkQueryForDisallowedContent()`)
  rejects obvious self-harm, hate-speech, and jailbreak/prompt-extraction
  attempts with a 400 *before* a paid Groq call or rate-limit consumption is
  spent — narrowly-scoped regex/keyword matching, deliberately chosen to
  avoid colliding with legitimate advisor vocabulary (life insurance, pest
  control, "what are the instructions for...").
  - The jailbreak patterns (ignore/disregard/forget "...previous
    instructions") originally allowed only a single fixed qualifier
    (all/any/the) directly before previous/prior/above/earlier, missing the
    equally common possessive-pronoun phrasing — "ignore **your** previous
    instructions", "disregard **our** previous instructions" slipped through
    unblocked. Fixed by expanding each pattern to allow two optional
    qualifier groups covering all/any/the/your/my/our.
  - This same pre-filter is now also applied to every forwarded history
    entry's `response` field, not just `query` (§2.1) — closing a **critical**
    bypass an adversarial review found: a caller invoking the Edge Function
    directly (bypassing the Flutter client, which always populates `response`
    from its own prior `ask()` return) could plant a fabricated "assistant"
    turn containing an unfiltered jailbreak/persona-shift, priming the model
    immediately before an innocent-looking live query. There is no way to
    verify a client-supplied `response` is genuinely prior model output, so
    it now gets the same scrutiny as member-authored text.
- **An output-side heuristic** (`looksLikeSystemPromptLeak()`) swaps in a
  safe fallback if a completion echoes a long run of the base system prompt
  verbatim (a system-prompt-extraction tell).
- Covered by 20 Deno unit tests across `moderation.test.ts` and
  `history.test.ts` (including a dedicated regression test asserting a
  disallowed history *response* — not just query — is blocked), independent
  of the Edge Function runtime.

**What is still explicitly absent — confirmed not present in code, not
merely unverified:**
- **No ML-based classifier** — the pre-filter above is explicitly a basic
  keyword/pattern first line of defense, not exhaustive slur/self-harm
  coverage and not immune to creative rephrasing. Code comments and
  `moderation.ts`'s own file header say this explicitly.
- **No content moderation on output beyond the system-prompt-leak heuristic**
  — there is still no general safety classifier pass, no check that the
  answer actually stayed within the advisor's intended scope.
- **No *gradual* cross-turn abuse detection** — real conversation memory now
  exists (§2.1), and the pre-filter now scans every individual forwarded
  history entry (both `query` and `response`), so a single disallowed turn
  anywhere in history is caught. What's still absent is any mechanism to
  notice a manipulation attempt that builds up gradually across several
  individually-innocuous turns — pattern-matching per turn, not across the
  conversation as a whole.
- **No anomaly/abuse monitoring on the logs** — `ai_advisor_logs` is written
  and retained, and staff can read it via RLS, but nothing in the codebase
  queries it for abuse patterns or flags anything for review.
- **The client still flattens the pre-filter's specific rejection reason**
  (e.g. the supportive self-harm-resources message) into one of two generic
  error messages via `isNetworkError`'s branching (§2.2) — a real, honest gap
  between what the server now returns and what the member actually sees; not
  closed by this round's server-side work.

This remains a deliberately lightweight LLM integration from a
safety-engineering standpoint: a short, narrowly-scoped system prompt per
advisor, the upstream provider's own model-level safety behavior, cost/abuse
controls (length cap + rate limit), an in-UI disclaimer on every AI-branded
screen, and now a basic keyword-based moderation/prompt-injection layer — but
still **no enterprise-grade content moderation**. Any production launch that
scales real usage of the advisors' financial/scheme guidance should still
treat a real ML-based moderation service as a design decision worth making
before scaling further, and should surface the pre-filter's specific
rejection reason to the member instead of a generic error.

---

## 7. Known limitations and placeholders (self-disclosed in code/docs)

- **STT/TTS is real on-device recognition/synthesis** (§3), not a vendor cloud
  API — no server-side moderation or logging is possible for voice input the
  way it is for the AI Advisors' text chat (§4), since the transcript never
  leaves the device before being classified/matched locally.
- **Voice Assistant still recognizes only 5 fixed intents** (`loanDetails`,
  `savingsThisMonth`, `readAnnouncements`, `addSavings`, `unknown`) via
  keyword matching against the real transcript — open-ended free-form speech
  is understood at the *transcription* level now (real STT), but still
  resolved down to this bounded intent set rather than a general NLU model.
- **Chat advisors now have real, session-scoped cross-turn memory** (§2.1) —
  bounded to the 6 most recent exchanges / 6,000 characters, reset on
  reopening the page or restarting the app; nothing persists longer than
  that.
- **Client error handling now surfaces the server's real, specific reason**
  (§2.2, §5) instead of flattening into two generic messages — a member can
  now tell "you're asking too fast" from "the service is down" from "that
  question was flagged" (with the pre-filter's own supportive message).
- **`ai_advisor_logs` now has a real retention policy** — a nightly
  `pg_cron` job purges rows older than 180 days via a `SECURITY DEFINER`
  function grantable only to `service_role` (§4, migration `0043`) — not yet
  deployed/executed against a live database this session.
- **Only a basic keyword-based moderation/prompt-injection layer exists, not
  enterprise-grade content moderation** (§6) — a real ML-based moderation
  service is still the remaining highest-priority item in this list before
  scaling real usage of the advisors' financial/scheme guidance. (The
  disclaimer gap that used to be listed here is fixed — see §6.)
