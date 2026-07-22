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
// Expects: { advisor_type: 'financial'|'scheme'|'market', query: string }.
// Requires `LLM_API_KEY` set via `supabase secrets set LLM_API_KEY=...`
// before deploying — this function throws immediately if that secret is
// absent, rather than silently falling back to a canned response (that
// fallback already exists client-side in MockAiAdvisorService; this
// function's only job is the real integration).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

    const { advisor_type, query } = await req.json();
    if (!advisor_type || !query || typeof query !== 'string') throw new HttpError(400, 'advisor_type and a string query are required');
    if (query.length > MAX_QUERY_LENGTH) throw new HttpError(400, `query is too long (max ${MAX_QUERY_LENGTH} characters)`);
    const systemPrompt = SYSTEM_PROMPTS[advisor_type];
    if (!systemPrompt) throw new HttpError(400, `unknown advisor_type: ${advisor_type}`);

    // Fail closed, not open: this check exists specifically to bound real
    // provider spend, so a caller we can't identify or a rate-limit-store
    // failure must not silently fall through to an unmetered call to a paid
    // API. (Requires migration 0031_ai_advisor_rate_limit.sql to be
    // deployed — without it this RPC call errors and every request is
    // correctly rejected rather than silently unlimited.)
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

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: query },
        ],
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
    const answer: string = completion.choices?.[0]?.message?.content ?? 'Sorry, I could not find an answer.';

    return new Response(JSON.stringify({ ok: true, response: answer }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (err) {
    if (err instanceof HttpError) {
      return new Response(JSON.stringify({ ok: false, error: err.message }), { status: err.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    console.error('ai-advisor-proxy unhandled error:', err);
    return new Response(JSON.stringify({ ok: false, error: 'Internal error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
