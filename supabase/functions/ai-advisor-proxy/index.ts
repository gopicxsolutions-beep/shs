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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SYSTEM_PROMPTS: Record<string, string> = {
  financial: 'You are a financial advisor for an Indian Self-Help Group (SHG) member. Give short, practical guidance on savings, loans, and budgeting. Keep replies under 80 words.',
  scheme: 'You help an Indian SHG member find relevant government welfare schemes (DAY-NRLM, MUDRA, PMEGP, etc). Keep replies under 80 words.',
  market: 'You advise an Indian SHG member on pricing and selling handmade/farm products. Keep replies under 80 words.',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('LLM_API_KEY');
    if (!apiKey) {
      throw new Error('LLM_API_KEY secret is not configured — run `supabase secrets set LLM_API_KEY=...` before deploying this function for real use.');
    }

    const { advisor_type, query } = await req.json();
    if (!advisor_type || !query) throw new Error('advisor_type and query are required');
    const systemPrompt = SYSTEM_PROMPTS[advisor_type];
    if (!systemPrompt) throw new Error(`unknown advisor_type: ${advisor_type}`);

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
    if (!response.ok) throw new Error(`LLM provider returned ${response.status}: ${await response.text()}`);
    const completion = await response.json();
    const answer: string = completion.choices?.[0]?.message?.content ?? 'Sorry, I could not find an answer.';

    return new Response(JSON.stringify({ ok: true, response: answer }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
