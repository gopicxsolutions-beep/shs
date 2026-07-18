// Server-side counterpart to lib/services/payment_processor.dart's
// MockPaymentProcessor — receives an async status callback from a real UPI
// / card payment gateway and reconciles it against public.payments. NOT
// DEPLOYED: no payment gateway is configured in this environment, and a
// webhook handler cannot be meaningfully tested without one (there is no
// mock caller for an inbound webhook the way there is for an outbound
// client call). Swap MockPaymentProcessor for a real gateway SDK client
// once one is configured, point that gateway's webhook config at this
// function's URL, and set the gateway's webhook signing secret via
// `supabase secrets set PAYMENT_WEBHOOK_SECRET=...` before deploying (see
// docs/DEVELOPMENT_PROGRESS.md's "External API abstraction plan").
//
// Expects the gateway's own payload shape — the fields read here
// (reference, status, signature) are illustrative placeholders; the real
// shape depends on which gateway is chosen and must be adjusted together
// with the signature-verification step below.
//
// Signature verification: implements the HMAC-SHA256-over-raw-body scheme
// most gateways use (Razorpay, Cashfree, Stripe-style). The signature
// header name (`x-webhook-signature`) and encoding (hex) are the common
// default but gateway-specific — adjust both to match whichever real
// gateway is wired in. Comparison is constant-time to avoid a timing side
// channel on the secret.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

async function verifySignature(rawBody: string, signatureHex: string, secret: string): Promise<boolean> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody));
  const expectedHex = Array.from(new Uint8Array(mac)).map((b) => b.toString(16).padStart(2, '0')).join('');
  if (expectedHex.length !== signatureHex.length) return false;
  // Constant-time compare — avoid short-circuiting on the first mismatched byte.
  let diff = 0;
  for (let i = 0; i < expectedHex.length; i++) diff |= expectedHex.charCodeAt(i) ^ signatureHex.charCodeAt(i);
  return diff === 0;
}

serve(async (req) => {
  try {
    const webhookSecret = Deno.env.get('PAYMENT_WEBHOOK_SECRET');
    if (!webhookSecret) {
      throw new Error('PAYMENT_WEBHOOK_SECRET is not configured — run `supabase secrets set PAYMENT_WEBHOOK_SECRET=...` before deploying this function for real use.');
    }

    const signature = req.headers.get('x-webhook-signature');
    if (!signature) throw new Error('missing webhook signature');

    const rawBody = await req.text();
    const validSignature = await verifySignature(rawBody, signature, webhookSecret);
    if (!validSignature) throw new Error('invalid webhook signature');

    const payload = JSON.parse(rawBody);
    const { reference, status } = payload as { reference?: string; status?: string };
    if (!reference || !status) throw new Error('reference and status are required in the webhook payload');

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const mappedStatus = status === 'SUCCESS' ? 'success' : status === 'FAILED' ? 'failed' : 'pending';
    const { error } = await supabase.from('payments').update({ status: mappedStatus }).eq('reference', reference);
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 400, headers: { 'Content-Type': 'application/json' } });
  }
});
