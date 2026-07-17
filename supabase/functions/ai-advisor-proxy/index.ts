// Server-side counterpart to lib/services/ai_advisor_service.dart's
// MockAiAdvisorService — proxies a question to a real LLM provider and
// logs the interaction to public.ai_advisor_logs, keeping the provider API
// key server-side (never shipped in the Flutter client). NOT DEPLOYED: no
// LLM provider key is available in this environment. Swap
// MockAiAdvisorService for a client that POSTs here once one is
// configured — the Flutter-side interface (`AiAdvisorService.ask`) is
// already shaped to match this function's request/response contract, so
// that swap is a one-file change (see docs/DEVELOPMENT_PROGRESS.md's
// "External API abstraction plan").
//
// Expects: { advisor_type: 'financial'|'scheme'|'market', query: string,
// member_id: string }. Requires a real LLM provider secret set via
// `supabase secrets set LLM_API_KEY=...` before deploying — this function
// throws immediately if that secret is absent, rather than silently
// falling back to a canned response (that fallback already exists
// client-side in MockAiAdvisorService; this function's only job is the
// real integration).

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

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('LLM_API_KEY');
    if (!apiKey) {
      throw new Error('LLM_API_KEY secret is not configured — run `supabase secrets set LLM_API_KEY=...` before deploying this function for real use.');
    }

    const { advisor_type, query, member_id } = await req.json();
    if (!advisor_type || !query || !member_id) throw new Error('advisor_type, query, and member_id are required');
    const systemPrompt = SYSTEM_PROMPTS[advisor_type];
    if (!systemPrompt) throw new Error(`unknown advisor_type: ${advisor_type}`);

    // TODO: replace with the real provider call once LLM_API_KEY is set —
    // this is intentionally left as a stub shape (provider, model, and
    // request/response format all depend on which LLM is chosen).
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: query },
        ],
        max_tokens: 150,
      }),
    });
    if (!response.ok) throw new Error(`LLM provider returned ${response.status}`);
    const completion = await response.json();
    const answer: string = completion.choices?.[0]?.message?.content ?? 'Sorry, I could not find an answer.';

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { error: logError } = await supabase.from('ai_advisor_logs').insert({ member_id, advisor_type, query, response: answer });
    if (logError) throw logError;

    return new Response(JSON.stringify({ ok: true, response: answer }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
