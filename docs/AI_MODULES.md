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
- A persistent disclaimer is shown, plus a two-layer moderation/prompt-injection defense server-side — regex pre-filter and a real Llama Guard ML classifier on both input and output (§6) — the specific rejection reason now *is* surfaced to her (§2.2 point 5), but it's still not a dedicated, vendor-operated trust & safety platform.

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
resolves a locale by language-code prefix against `stt.locales()` (preferring
an `*-IN` region variant, e.g. `te-IN`/`hi-IN`/`en-IN`), then listens for up
to 10 seconds (or 3 seconds of trailing silence) and returns the final
transcript. The transcript is then classified into a `VoiceIntent`
(`loanDetails`, `savingsThisMonth`, `readAnnouncements`, `addSavings`,
`unknown`) by `VoiceIntentClassifier` — a small per-language keyword matcher
(`lib/services/voice_intent_classifier.dart`), since a real STT engine returns
arbitrary free text rather than one of a fixed canned set. An empty/silent transcript throws `VoiceRecognitionEmptyResultException`
and a device with no available recognizer (permission denied, no engine
installed, no mic hardware) throws `VoiceRecognitionUnavailableException` —
two distinct types (gap-hunt round 181) so `AiVoiceAssistantPage`/
`SupportVoicePage` show a different, actionable message for each instead of
one generic retry prompt that couldn't tell a member how to actually fix a
denied mic permission. As of §3.4, the empty-result path is also reached
when a mid-listen `onError` fires a permission/hardware-class error, not
only from the recognizer genuinely hearing nothing.
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

### 3.4 Real bug: Flutter Web silently ignored the member's language selection (found and fixed this round)

**Symptom reported**: "the AI Voice Assistant is not working." Given this
project has been tested almost exclusively via the Flutter Web build
throughout its history, the most probable root cause was web-specific, not a
generic logic bug — confirmed below.

**Root cause**: `speech_to_text`'s web implementation
(`speech_to_text_web.dart`) implements `locales()` by reading back whatever
`.lang` a *prior* `listen()` call already set on the browser's
`SpeechRecognition` object — `.lang` is never set anywhere else. Before the
very first `listen()` of a session ever runs, that's unset, so `locales()`
returns `[]` on Web, on literally every call, forever — a chicken-and-egg gap
that doesn't exist on Android/iOS (both genuinely enumerate installed OS
recognizer locales independent of any prior `listen()` call). This app's own
`_resolveLocaleId()` called `_stt.locales()` *before* the first `listen()`,
so on Web it always matched nothing and fell back to `localeId: null` —
which leaves the browser's `SpeechRecognition.lang` at whatever it already
defaulted to (commonly English), **completely ignoring the member's Telugu/
Hindi/English selection** in the page's own language chips. A Telugu speaker
selecting "తెలుగు" and speaking Telugu had her speech run through an
English-default recognizer — a highly plausible, deterministic explanation
for "doesn't work," since it silently misfires for any member who isn't
speaking the browser's default language.

**Fix**: `_resolveLocaleId()` (now backed by the pure, independently-testable
`resolveVoiceLocaleId(Language, List<String>)` function in the same file)
falls back to a direct hardcoded BCP-47 region code (`te-IN`/`hi-IN`/`en-IN`)
when `locales()` comes back empty, instead of `null`. An empty list is itself
the reliable signal that this platform's `locales()` isn't meaningful — a
real Android/iOS device always reports at least its own system default, so
seeing `[]` there would be anomalous rather than expected.

**Secondary gap fixed in the same change**: the shared `onError` callback
used to complete every recognizer error identically (mic permission denied,
no mic hardware, or a genuine no-speech outcome all landed on the same
"Sorry, I couldn't hear anything. Please try again."). A denied browser mic
permission fires `'not-allowed'` on every subsequent attempt until the member
manually re-grants it outside the app — retrying inside the app can never
fix it, but the message never said so. Added `isUnavailableVoiceError()` (a
small classifier over the standard Web Speech API error codes plus this
package's own two synthetic web-only ones) so a permission/hardware-class
error now throws `VoiceRecognitionUnavailableException` instead of
`VoiceRecognitionEmptyResultException`, surfacing the actionable message.

**Verification**: `resolveVoiceLocaleId`/`isUnavailableVoiceError` are pure
functions with new unit coverage
(`test/services/device_voice_recognition_service_test.dart`) covering the
empty-list web fallback, Indian-region preference, case-insensitive
matching, the no-match case, and every error classification — this closes
the "zero existing tests for this file" gap without needing a mock harness
for the real `speech_to_text` plugin (none exists in this repo). `flutter
analyze`/`flutter test` pass. Genuine spoken-voice, end-to-end verification
was not possible in this environment — the sandboxed Browser pane blocks
real microphone access — so, consistent with §3.1's existing testing
caveat, a real device/browser should confirm the recognizer actually now
listens in the selected language before this is treated as fully verified.

### 3.5 Two more real bugs found dogfooding §3.4's own fix (gap-hunt iteration 28)

The very next gap-hunt loop iteration deliberately re-audited this fix's own
code rather than assuming it was settled once shipped — and found two more
genuine bugs in it:

**Bug 1 (HIGH) — subtag-boundary false positive**: `resolveVoiceLocaleId`'s
matching used a bare `id.startsWith(code)` on the 2-letter language code,
with no check that `code` is actually the locale's whole primary subtag. A
device reporting `tet-TL` (Tetum) or `hil-PH` (Hiligaynon) — real BCP-47
locale ids that merely happen to start with "te"/"hi" — would silently
match against Telugu/Hindi respectively, with no error at all. This is
worse than the empty-list case §3.4 fixed: that one at least fails in a
handled, expected way, while this one silently listens in the wrong
language and looks like it worked. Fixed by splitting each candidate locale
id on the BCP-47 subtag delimiter (`-`/`_`) and comparing only the primary
subtag for equality, instead of a prefix check.

**Bug 2 (MEDIUM) — stale-attempt hijack via the shared `onError` callback**:
`onError` is registered once for the service instance's whole lifetime, not
per-`listen()` call, and the `speech_to_text` plugin gives it no id
correlating an error back to which attempt raised it — it just resolves
whatever `_pendingCompleter` currently is when it fires. If a superseded
attempt's native session were to emit a delayed error after a newer
`listen()` call has already started (e.g. web's `SpeechRecognition.onerror`
firing asynchronously just after `stop()` was already issued for the old
session), it would resolve the NEW attempt's completer instead, silently
discarding whatever real transcript that attempt was about to produce. The
page's own busy-disabled mic button should normally prevent two overlapping
`listen()` calls from existing at once, but `listen()` now also forces any
stray still-pending completer to a clean `stop()` before starting a new
attempt, closing the overlap window at the service layer too rather than
relying solely on the caller never double-invoking it.

Both fixed in the same file, with 3 additional regression tests for the
subtag-boundary case. See `docs/DEVELOPMENT_PROGRESS.md`'s "Gap-hunting loop
iteration 28" entry for the full write-up.

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
  created_at timestamptz not null default now(),
  -- migration 0044:
  blocked boolean not null default false,
  block_reason text
  -- check (blocked = (block_reason is not null))
);
```

Note the CHECK constraint only permits `financial`/`scheme`/`market` —
`'voice'` is not a valid value. **The Voice Assistant does not write to this
table at all**; no audit/log table exists anywhere for voice interactions.

**`blocked`/`block_reason` (migration `0044`)**: previously, a request
rejected by content moderation left zero trace anywhere in this table — only
successful Q&A ever got a row, inserted client-side by
`AiAdvisorRepository.ask()` *after* a successful response came back. A
rejected attempt now gets a row too, inserted **server-side** by
`ai-advisor-proxy/index.ts` itself (using the service-role client it already
holds for the rate-limit RPC — no new client-facing insert path opened) for
every content-moderation rejection: the regex pre-filter, the history-content
check, or the new Llama Guard ML classifier (§6). Deliberately *not* logged
this way: ordinary shape-validation 400s (malformed JSON, missing fields —
not an abuse signal) or 429 rate-limit rejections (already tracked in
`ai_advisor_rate_limits`). See §6 for the staff-visible Admin Monitoring
stat this now backs.

**RLS**:
- SELECT: the member herself, or any staff role (`is_staff()`).
- INSERT: only your own `member_id`.
- **No UPDATE policy and no DELETE policy exist for clients** — logged Q&A
  pairs remain immutable and permanent from the client's perspective; this is
  unchanged.
- **Retention is now real, server-side/privileged only, and confirmed live
  (verified 2026-07-24)**: `public.purge_old_ai_advisor_logs()` (migration
  `0043`, `SECURITY DEFINER`) deletes rows older than 180 days, scheduled
  nightly via `pg_cron` (mirrors `ai_advisor_rate_limits`' own self-pruning
  pattern, and `generate-report-snapshots`' pg_cron scheduling pattern — the
  simpler of the two, since no HTTP hop to an Edge Function is needed for a
  plain in-database delete). `EXECUTE` is revoked from `PUBLIC` and granted
  only to `service_role`, so it is not reachable as a client-callable
  PostgREST RPC — no new client-facing DELETE path was opened to achieve
  this. 180 days is a stated operational default (this table is a
  staff-readable audit trail, not a transient cache), not a
  compliance-mandated figure, and is explicitly revisitable. Confirmed
  against the live database directly, not assumed: the function exists
  (`pg_proc`), the `purge-ai-advisor-logs-nightly` job is active in
  `cron.job` (`0 3 * * *`), and manually invoking the function once
  succeeded cleanly (0 rows deleted — correct, since the live table's oldest
  row is only days old, nowhere near the 180-day threshold). The cron
  schedule itself had not yet fired naturally as of this check
  (`cron.job_run_details` empty for this job) — expected given how recently
  it was deployed relative to its own nightly cadence, not a defect.

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
- **Locked down — real gap found and fixed live (2026-07-24)**: the
  function's own migration (0031) correctly wrote `revoke all ... from
  public; grant execute ... to service_role`, but this project's Postgres
  setup grants `anon`/`authenticated` roles `EXECUTE` on newly created
  functions directly (independent of the `PUBLIC` pseudo-role), so
  `revoke ... from public` alone never actually removed it — confirmed via
  `has_function_privilege('authenticated', ..., 'execute')` returning
  `true` against the live database, not assumed from the migration text.
  This was concretely exploitable: with no ownership check on the
  caller-supplied `p_member_id` inside the function itself, any
  authenticated (or, per the same gap, anonymous) caller could invoke
  `check_and_increment_ai_advisor_rate_limit` directly via PostgREST with
  an arbitrary victim's member id and the real limit/window values,
  pre-inflating that member's counter and causing their next genuine
  request through the real Edge Function to be wrongly rejected with 429
  — a targeted denial-of-service reachable by any signed-in user. Live-
  confirmed the exploit succeeding (a real row written for an arbitrary
  test id) before the fix. The same gap affected two other service-role-
  only functions in this schema (`purge_old_ai_advisor_logs`,
  `record_system_heartbeat` — lower severity, no targeted-DoS shape, but
  same violated intent). Fixed together in
  `supabase/migrations/0055_service_role_only_functions_anon_authenticated_revoke.sql`
  — an explicit `revoke execute ... from anon, authenticated` for all
  three, re-verified live (now correctly denied for `authenticated`,
  still permitted for `service_role`; every intentionally client-callable
  RPC in the schema — `approve_loan`, `record_loan_payment`,
  `place_marketplace_order`, `approve_shg_join_request`,
  `submit_quiz_attempt` — independently re-confirmed unaffected).
- **Fails closed**: if the caller's identity can't be resolved → HTTP 401. If
  the rate-limit check itself errors (e.g. the migration isn't deployed) →
  HTTP 500, rejecting the request rather than silently letting it through
  unmetered.
- **On exceeding the limit**: the Edge Function throws
  `HttpError(429, 'Too many requests. Please wait a minute before asking
  again.')` — shown to the member verbatim by the client (§2.2 point 5).
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
  independently, localized in all three languages (`aiDisclaimer` key). On
  the Voice Assistant specifically (round 187), it's also **spoken**, after
  the answer, in the member's selected voice language — previously only the
  answer was passed to TTS, so the one safety caveat that exists was only
  ever available as small (11px) printed text, unreachable in an
  otherwise-voice-only interaction.

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
  - Round 187: `buildSystemPrompt(baseSystemPrompt, language)` also appends a
    language directive ("respond only in Hindi, Devanagari script" /
    "...Telugu script") for `hi`/`te`, kept as a *third*, separately-appended
    piece (base prompt + injection-hardening suffix + language directive) so
    the `looksLikeSystemPromptLeak()` word-overlap check — which still
    compares only against the raw, undecorated base prompt — is unaffected.
    Before this, `language` was threaded end-to-end from the client but only
    ever selected which localized *rejection* string came back; the actual
    advisor answer was English-only regardless of the member's app language,
    despite the surrounding chat UI being fully localized.
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
- Covered by 51 Deno unit tests across `moderation.test.ts` (32) and
  `history.test.ts` (19) (including a dedicated regression test asserting a
  disallowed history *response* — not just query — is blocked), independent
  of the Edge Function runtime.

**A real ML-based classifier now exists on top of the regex layer above** —
Groq's **Llama Guard 3** model (`llama-guard-3-8b`), served by the same
already-provisioned Groq account (no new vendor/contract/secret):
- Runs on the live query *after* the regex pre-filter passes (avoiding a
  redundant call on requests the cheap filter already caught) and *before*
  the main advisor completion call — a genuine second-pass safety classifier
  against Llama Guard's fixed policy taxonomy (violent crime, self-harm,
  hate, sexual content, weapons, privacy, election misinformation, etc.),
  not another regex list.
- **Also runs on the model's own completion output**, not just the input —
  closing the "no content moderation on output beyond the system-prompt-leak
  heuristic" gap a prior version of this document listed here. Gated behind
  the existing leak-heuristic check (only runs if the completion wasn't
  already replaced by the leak fallback) to avoid a redundant call.
- A flagged self-harm category (`S11`) gets the same supportive,
  resource-pointing message the regex self-harm filter already gives —
  `reasonForLlamaGuardVerdict()` maps category → reason, not a cold generic
  rejection for the one category where the wording genuinely matters for the
  member's safety.
- **Fails open only at the transport layer** — if the Llama Guard *call
  itself* errors (network failure, non-200 status): this is a defense-in-
  depth layer on top of an already-functioning regex filter + rate limit +
  injection hardening, not the sole safety mechanism — an outage in this
  supplementary classifier degrades to "no extra ML check this call" rather
  than taking down the whole advisor feature, a deliberate availability/
  safety trade-off worth being explicit about. Every fail-open path logs
  server-side. **Does NOT fail open on a successful-but-unparseable reply**:
  `parseLlamaGuardVerdict()` only treats an exact, trimmed `"safe"` first
  line as safe — anything else (garbled/truncated text, unexpected
  preamble, anything not matching Llama Guard's fixed reply format) is
  treated as flagged. An earlier version of this parser treated any
  non-"unsafe" first line as safe, silently failing open on genuinely
  unrecognized replies — found by adversarial review and fixed to match
  this file's own stated intent of never guessing "probably fine" on a
  moderation-purpose model's output.
- Covered by 10 Deno unit tests (verdict parsing — including the
  fail-open-vs-fail-flagged distinction above — and category→reason
  mapping) in `moderation.test.ts` — the live HTTP call to Groq itself is
  not unit-testable offline and lives in `index.ts`.

**Every content-moderation rejection is now logged, not just successful
Q&A** — `ai_advisor_logs` gained `blocked`/`block_reason` columns (migration
`0044`); the Edge Function inserts a row (via the service-role client it
already holds for the rate-limit RPC — no new client-facing insert path)
whenever the regex filter, the history-content check, or the new ML
classifier rejects a request, before returning the 400. Deliberately scoped
to *content*-moderation rejections only, not ordinary shape-validation 400s
or 429 rate-limit rejections (already tracked in `ai_advisor_rate_limits`) —
narrows the column's meaning to genuinely useful abuse-review signal rather
than diluting it with routine client mistakes. For a history-triggered
block, the logged `query` is the actual offending history entry text (which
field/turn matched, via `checkHistoryForDisallowedContent`'s returned
`matchedText`), not the live query — an earlier version logged the live
query for this path, which is almost always entirely innocuous and gives a
staff reviewer no visible connection to why the row was actually flagged;
found by adversarial review and fixed.

**A staff-visible abuse-review surface now exists**: the Admin Monitoring
page (`admin_monitoring_page.dart`) shows a real "AI Advisor Blocks (7d)"
stat — a live count of blocked rows and distinct flagged members from
`ai_advisor_logs`, computed by `AdminRepository.fetchAiAdvisorModerationStats()`.
This is intentionally a passive, staff-must-look dashboard figure, not
proactive alerting/escalation/per-member lockout — see the still-absent list
below for what that would still require.

**What is still explicitly absent — confirmed not present in code, not
merely unverified:**
- **No *gradual* cross-turn abuse detection** — real conversation memory
  exists (§2.1), and every individual forwarded history entry (both `query`
  and `response`) is checked by both the regex filter and, for the live
  query, the ML classifier, so a single disallowed turn anywhere is caught.
  What's still absent is any mechanism to notice a manipulation attempt that
  builds up gradually across several individually-innocuous turns —
  per-turn classification, not whole-conversation pattern analysis.
- **No proactive alerting or automated escalation on repeated blocks** — the
  new Admin Monitoring stat is a real count, but it is passive: nothing
  pages/notifies staff when one member racks up many blocked attempts, and
  there is no automated response (temporary lockout, required review) tied
  to a threshold. A staff member must actively look at the dashboard.
- **Llama Guard is not applied to bounded chat history entries**, only the
  live query and the live completion — applying it to all 6 possible
  history exchanges × 2 fields per request would multiply Groq cost for
  each call with limited marginal benefit over the regex history check
  already in place (history entries were themselves live queries that
  already passed through this same pipeline in an earlier request).

(A prior version of this document listed the client flattening the
pre-filter's specific rejection reason into a generic error message as a
remaining gap here. That has since been closed —
`mapFunctionExceptionToAdvisorException()` and `_errorMessageFor()` now
surface the server's verbatim 400/429 reason text to the member; see §2.2
point 5.)

This is still a lightweight LLM integration relative to a dedicated,
vendor-operated trust & safety platform: a short, narrowly-scoped system
prompt per advisor, the upstream provider's own model-level safety behavior,
cost/abuse controls (length cap + rate limit), an in-UI disclaimer on every
AI-branded screen, and now a genuine two-layer defense (regex + Llama Guard
ML classifier) on both input and output, with rejected attempts logged and
staff-visible — but still not a dedicated, vendor-operated trust & safety
platform with proactive alerting. Any production launch scaling real usage
of the advisors' financial/scheme guidance should still consider proactive
abuse alerting (not just a passive dashboard count) as the next design
decision worth making.

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
  function grantable only to `service_role` (§4, migration `0043`) —
  confirmed deployed and functioning against the live database (function,
  active cron job, and a successful manual invocation all directly verified;
  see §4 for details).
- **A real ML-based classifier (Groq Llama Guard 3) now runs alongside the
  regex pre-filter, on both input and output** (§6) — closes what used to be
  this list's top item. Blocked attempts are now logged
  (`ai_advisor_logs.blocked`, migration `0044`) and surfaced to staff via a
  real Admin Monitoring stat, not just silently rejected with no trace. What
  remains: no proactive alerting/escalation on repeated blocks (a passive
  dashboard count only), and no gradual/whole-conversation abuse detection —
  see §6's still-absent list for the precise remaining scope. This is still
  not a dedicated, vendor-operated trust & safety platform.
