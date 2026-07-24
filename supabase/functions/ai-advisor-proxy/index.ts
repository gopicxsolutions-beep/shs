// Server-side counterpart to lib/services/ai_advisor_service.dart's
// EdgeFunctionAiAdvisorService — proxies a question to a real LLM provider,
// keeping the provider API key server-side (never shipped in the Flutter
// client). Stateless by design: it only returns the answer text. Logging
// to public.ai_advisor_logs stays client-side in AiAdvisorRepository.ask()
// (already RLS-proven: self-insert allowed, insert-for-another-member
// denied) so both the mock and real advisor paths share one logging path
// instead of this function duplicating it.
//
// DEPLOYED, using Groq's OpenAI-compatible chat completions API
// (https://api.groq.com/openai/v1) with `llama-3.3-70b-versatile`. Note:
// the `LLM_API_KEY` secret is a Groq API key (prefix `gsk_`), not xAI's
// "Grok" (a different, unrelated provider despite the similar name) — Groq
// doesn't serve the Grok model. Swap the URL/model below for a different
// OpenAI-compatible provider (OpenAI, xAI, etc.) if ever needed; the
// request/response shape used here is the now-common OpenAI-style
// chat-completions contract most providers implement.
//
// Expects: { advisor_type: 'financial'|'scheme'|'market', query: string,
// history?: { query: string, response: string }[] }. `history` is optional
// cross-turn conversation memory — a bounded, most-recent slice of the
// current chat session's prior turns (see ./history.ts for the shape
// validation, size bounds, and how it's turned into real prior
// user/assistant messages for the Groq request; docs/AI_MODULES.md §2.1
// previously disclosed this as a gap — no prior turn was ever sent back to
// the model).
// Requires `LLM_API_KEY` set via `supabase secrets set LLM_API_KEY=...`
// before deploying — this function throws immediately if that secret is
// absent, rather than silently falling back to a canned response (that
// fallback already exists client-side in MockAiAdvisorService; this
// function's only job is the real integration).
//
// Content moderation and prompt-injection hardening (see ./moderation.ts for
// the full honest-scope writeup, and docs/AI_MODULES.md §6 for how this
// changes that section's "explicitly absent" list): a cheap keyword/pattern
// pre-filter rejects the most obvious self-harm/hate-speech/jailbreak
// attempts with a 400 *before* the Groq call below is ever made; a second,
// real ML classifier (Groq's Llama Guard 3 model) then checks both the live
// query and the model's own completion against a broader safety taxonomy —
// genuine defense-in-depth, not just more regex; the system+user messages
// are built through a delimiter + instruction-reinforcement wrapper so the
// member's raw text is unambiguously framed as "a question to answer", not
// "instructions to follow"; and the completion also gets a cheap check for
// looking like an echoed system-prompt-extraction attempt. Every
// content-moderation rejection (regex or ML) is logged to
// `ai_advisor_logs` (`blocked`/`block_reason` columns, migration 0044) for
// staff abuse review — a rejected attempt used to leave no trace anywhere.
// Still not enterprise-grade, vendor-operated moderation, but a real
// two-layer defense using only the already-provisioned Groq key (no new
// moderation vendor).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  buildSystemPrompt,
  checkQueryForDisallowedContent,
  LLAMA_GUARD_MAX_TOKENS,
  LLAMA_GUARD_MODEL,
  looksLikeSystemPromptLeak,
  parseLlamaGuardVerdict,
  reasonForLlamaGuardVerdict,
  SAFE_FALLBACK_ON_SUSPECTED_LEAK,
  SAFE_FALLBACK_ON_UNSAFE_OUTPUT,
} from './moderation.ts';
import {
  boundHistory,
  buildMessagesWithHistory,
  checkHistoryForDisallowedContent,
  InvalidHistoryError,
  validateHistoryShape,
} from './history.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SYSTEM_PROMPTS: Record<string, string> = {
  financial: 'You are a financial advisor for an Indian Self-Help Group (SHG) member. Give short, practical guidance on savings, loans, and budgeting. Keep replies under 80 words.',
  scheme: 'You help an Indian SHG member find relevant government welfare schemes (DAY-NRLM, MUDRA, PMEGP, etc). Keep replies under 80 words.',
  market: 'You advise an Indian SHG member on pricing and selling handmade/farm products. Keep replies under 80 words.',
};

// A member could otherwise send an arbitrarily large `query` in a single
// authenticated call, running up Groq API token costs (max_tokens below
// only caps the *completion*, not the input) with nothing stopping it.
const MAX_QUERY_LENGTH = 2000;

// Call-frequency cap: `MAX_QUERY_LENGTH` above only bounds cost *per call*,
// not *call frequency* — verify_jwt only proves the caller is SOME
// authenticated user, not that they're calling at a reasonable rate. Every
// prior audit round correctly declined to "fix" this with a same-isolate
// in-memory counter (Supabase Edge Functions are independent,
// horizontally-scaled Deno isolates with no shared memory, so a per-isolate
// counter is trivially bypassed by concurrent requests landing on different
// isolates — it would look like protection without actually being any) and
// left it as a documented gap pending a durable, atomic, race-safe store.
// That store now exists: `public.check_and_increment_ai_advisor_rate_limit`
// (supabase/migrations/0031_ai_advisor_rate_limit.sql), a single
// insert-on-conflict-returning statement per call, so concurrent requests
// for the same member — even landing on different isolates — serialize
// correctly through Postgres's own row locking instead of racing.
const RATE_LIMIT_MAX_PER_WINDOW = 10;
const RATE_LIMIT_WINDOW_SECONDS = 60;

// This function is otherwise deliberately stateless (see file header) and
// never decodes the caller's JWT — the rate limit is the one thing that
// needs to know WHICH member is calling. `verify_jwt: true` at the Supabase
// Edge Function gateway already validates the JWT's signature and
// expiry before this handler ever runs, so it's safe to trust the `sub`
// claim from the (already-verified) token without re-verifying it here —
// this only ever reads a claim out of a token the platform has already
// authenticated, it doesn't perform authentication itself.
function memberIdFromAuthHeader(req: Request): string | null {
  const auth = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!auth?.startsWith('Bearer ')) return null;
  const token = auth.slice('Bearer '.length);
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    return typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

// Real ML-based classification via Groq's Llama Guard 3 model — see
// ./moderation.ts section 4 for the full design rationale. Deliberately
// fails open (returns unflagged) on any transport/parse failure rather than
// throwing: this is a defense-in-depth layer on top of the regex pre-filter
// + rate limit + injection hardening already in place, not the sole
// safety mechanism, so an outage here should degrade to "no extra ML
// check this call" rather than take down the whole advisor feature.
async function classifyContentSafety(apiKey: string, text: string): Promise<import('./moderation.ts').LlamaGuardVerdict> {
  try {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: LLAMA_GUARD_MODEL,
        messages: [{ role: 'user', content: text }],
        max_tokens: LLAMA_GUARD_MAX_TOKENS,
      }),
    });
    if (!res.ok) {
      console.warn(`ai-advisor-proxy: Llama Guard classification call returned ${res.status}; failing open (treating as unflagged).`);
      return { flagged: false, categories: [] };
    }
    const body = await res.json();
    const raw: string = body.choices?.[0]?.message?.content ?? '';
    return parseLlamaGuardVerdict(raw);
  } catch (e) {
    console.warn(`ai-advisor-proxy: Llama Guard classification call threw (${e}); failing open (treating as unflagged).`);
    return { flagged: false, categories: [] };
  }
}

// Distinguishes "the caller sent something we can't process" (4xx — their
// mistake, don't alarm on it) from "something failed on our/the upstream
// provider's end" (5xx/502) — both used to collapse into one 500, which
// would make monitoring fire on ordinary bad requests and could make a
// naive client retry a request that can never succeed.
class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('LLM_API_KEY');
    if (!apiKey) {
      // Our own deployment is misconfigured — not the caller's fault.
      throw new HttpError(500, 'LLM_API_KEY secret is not configured — run `supabase secrets set LLM_API_KEY=...` before deploying this function for real use.');
    }

    const { advisor_type, query, history: rawHistory } = await req.json();
    if (!advisor_type || !query || typeof query !== 'string') throw new HttpError(400, 'advisor_type and a string query are required');
    if (query.length > MAX_QUERY_LENGTH) throw new HttpError(400, `query is too long (max ${MAX_QUERY_LENGTH} characters)`);
    const systemPrompt = SYSTEM_PROMPTS[advisor_type];
    // Defense-in-depth length cap on the echoed value: advisor_type is
    // expected to be one of 3 short known strings, but the client-supplied
    // raw value is otherwise unbounded before this point — cap what's
    // echoed back so a client can't get an arbitrarily large payload
    // reflected into this 400's error field (the chat page currently shows
    // every 400 reason verbatim, see ai_advisor_chat_page.dart).
    if (!systemPrompt) {
      const shown = typeof advisor_type === 'string' ? advisor_type.slice(0, 40) : String(advisor_type).slice(0, 40);
      throw new HttpError(400, `unknown advisor_type: ${shown}`);
    }

    // Identify the caller and enforce the rate limit BEFORE any of the
    // (potentially more expensive, and now more elaborate) history
    // validation/moderation checks below. This intentionally runs ahead of
    // those checks — an adversarial review found that a caller could
    // otherwise send unlimited requests per minute for free by crafting
    // each one to be rejected by validation/moderation (which returned
    // before ever reaching this RPC), completely undermining the
    // 10-requests/60s budget this exists to enforce. Every request now
    // counts against the budget regardless of whether it's ultimately
    // accepted or rejected for some other reason.
    const memberId = memberIdFromAuthHeader(req);
    if (!memberId) throw new HttpError(401, 'Could not identify the authenticated caller.');

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: withinLimit, error: rateLimitError } = await supabase.rpc('check_and_increment_ai_advisor_rate_limit', {
      p_member_id: memberId,
      p_max_per_window: RATE_LIMIT_MAX_PER_WINDOW,
      p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
    });
    if (rateLimitError) {
      console.error(`ai-advisor-proxy: rate limit check failed: ${rateLimitError.message}`);
      throw new HttpError(500, 'Internal error');
    }
    if (!withinLimit) throw new HttpError(429, 'Too many requests. Please wait a minute before asking again.');

    // Cross-turn memory: validate the optional, client-supplied bounded
    // slice of this session's prior turns (shape only here — MAX_QUERY_LENGTH
    // above only bounds the *new* query, not accumulated history), then
    // independently re-enforce our own count/size bounds regardless of what
    // the caller sent (see ./history.ts). validateHistoryShape itself caps
    // the number of raw entries it will iterate before this point, so a
    // client cannot inflate validation cost by sending an enormous array.
    let history;
    try {
      history = boundHistory(validateHistoryShape(rawHistory));
    } catch (e) {
      if (e instanceof InvalidHistoryError) throw new HttpError(400, e.message);
      throw e;
    }

    // Records a rejected attempt to public.ai_advisor_logs -- deliberately
    // scoped to CONTENT-moderation rejections only (regex pre-filter,
    // history-content bypass, ML classifier below), not shape-validation
    // 400s or the 429 rate limit above (see migration 0044's header for why
    // those are excluded). Uses the same service-role `supabase` client
    // already created for the rate-limit RPC -- bypasses RLS the same way
    // that call does, so no new client-facing insert path is opened.
    // Best-effort: a logging failure must never block the 400 the caller is
    // about to receive, so any insert error is only logged server-side, not
    // thrown. `loggedText` defaults to the live query, but a history-
    // triggered block passes the actual offending history entry text
    // instead (see the historyFilter call site below) — without this
    // override, a history-triggered block would log the current, entirely
    // innocuous live query with no visible connection to why the request
    // was actually rejected, defeating the point of logging it at all.
    const logBlockedRequest = async (reason: string, loggedText: string = query): Promise<void> => {
      const { error } = await supabase
        .from('ai_advisor_logs')
        .insert({ member_id: memberId, advisor_type, query: loggedText, blocked: true, block_reason: reason });
      if (error) console.error(`ai-advisor-proxy: failed to log blocked request: ${error.message}`);
    };

    // Basic content pre-filter — cheap keyword/pattern matching only (see
    // ./moderation.ts for the full honest-scope note). Applied to every
    // history entry (both `query` and `response` — see
    // checkHistoryForDisallowedContent's doc comment for why `response`
    // needs this too) as well as the live query.
    const historyFilter = checkHistoryForDisallowedContent(history);
    if (historyFilter.blocked) {
      await logBlockedRequest(historyFilter.reason, historyFilter.matchedText);
      throw new HttpError(400, historyFilter.reason);
    }
    const preFilter = checkQueryForDisallowedContent(query);
    if (preFilter.blocked) {
      await logBlockedRequest(preFilter.reason);
      throw new HttpError(400, preFilter.reason);
    }

    // ML-based classification (Groq Llama Guard) — a real second-pass safety
    // classifier layered on top of the regex pre-filter above, closing the
    // "no ML-based classifier" gap docs/AI_MODULES.md §6/§7 named as the
    // single highest-priority remaining item (see ./moderation.ts's own
    // section-4 writeup for the full design rationale). Runs only on the
    // live query, not every history entry — history was already filtered as
    // a live query in an earlier request through this same pipeline, and
    // classifying up to 12 history fields per request (6 exchanges × 2
    // fields) on every call would multiply Groq cost for little marginal
    // safety benefit over the regex history check already in place.
    //
    // Deliberately FAILS OPEN if the Llama Guard call itself errors
    // (network failure, non-200, malformed reply): this is a defense-in-depth
    // layer added on top of an already-functioning regex filter + rate limit
    // + injection hardening, not the sole safety mechanism — letting an
    // outage in this supplementary classifier take down the entire advisor
    // feature would trade a moderation improvement for a new denial-of-
    // service vector. Every fail-open path logs server-side for ops
    // visibility.
    const queryVerdict = await classifyContentSafety(apiKey, query);
    if (queryVerdict.flagged) {
      const reason = reasonForLlamaGuardVerdict(queryVerdict);
      await logBlockedRequest(reason);
      throw new HttpError(400, reason);
    }

    // Prompt-injection hardening: the member's raw query (and every history
    // query) is wrapped in clear delimiters and framed as "a question to
    // answer", and the system prompt gets an explicit instruction not to
    // follow anything embedded in that delimited text (see ./moderation.ts
    // and ./history.ts). Standard, well-known mitigation — not foolproof,
    // but a real improvement over passing raw text straight through with no
    // framing at all. Prior turns (if any) are included as real
    // user/assistant messages, not folded into the system prompt — genuine
    // cross-turn memory rather than a text summary of it.
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: buildMessagesWithHistory(buildSystemPrompt(systemPrompt), history, query),
        max_tokens: 150,
      }),
    });
    if (!response.ok) {
      // Log the real upstream detail server-side; don't hand a caller the
      // raw provider response body (could include request/account detail).
      console.error(`ai-advisor-proxy: LLM provider returned ${response.status}: ${await response.text()}`);
      throw new HttpError(502, 'The advisor service is temporarily unavailable. Please try again.');
    }
    const completion = await response.json();
    let answer: string = completion.choices?.[0]?.message?.content ?? 'Sorry, I could not find an answer.';

    // Output-side sanity check: a cheap heuristic, not a real classifier
    // (see ./moderation.ts) — if the completion looks like it echoed back a
    // meaningful chunk of the (undecorated) base system prompt verbatim,
    // that's the clearest cheap signal of a successful prompt-extraction
    // attempt, so swap in a safe generic answer instead of returning it.
    if (looksLikeSystemPromptLeak(answer, systemPrompt)) {
      console.warn(`ai-advisor-proxy: completion for advisor_type=${advisor_type} looked like a system-prompt echo; substituting safe fallback.`);
      answer = SAFE_FALLBACK_ON_SUSPECTED_LEAK;
    } else {
      // Real ML classification of the model's own OUTPUT too, not just the
      // input — closes docs/AI_MODULES.md §6's other disclosed gap ("No
      // content moderation on output beyond the system-prompt-leak
      // heuristic"). `else`-gated on the leak check above only to avoid a
      // redundant extra Groq call when the answer was already replaced.
      const answerVerdict = await classifyContentSafety(apiKey, answer);
      if (answerVerdict.flagged) {
        console.warn(`ai-advisor-proxy: completion for advisor_type=${advisor_type} flagged unsafe by Llama Guard (${answerVerdict.categories.join(',')}); substituting safe fallback.`);
        answer = SAFE_FALLBACK_ON_UNSAFE_OUTPUT;
      }
    }

    return new Response(JSON.stringify({ ok: true, response: answer }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (err) {
    if (err instanceof HttpError) {
      return new Response(JSON.stringify({ ok: false, error: err.message }), { status: err.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    console.error('ai-advisor-proxy unhandled error:', err);
    return new Response(JSON.stringify({ ok: false, error: 'Internal error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
