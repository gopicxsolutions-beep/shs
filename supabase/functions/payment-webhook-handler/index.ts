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
//
// Replay protection: the signature alone authenticates *that* the payload
// came from someone holding the secret, but not *when* — without a
// timestamp bound into the signed content, a single captured valid
// (payload, signature) pair (from a proxy log, a browser network panel, a
// misconfigured logging integration, etc.) could be replayed at any point
// in the future to re-apply a stale status (e.g. resending an old
// 'PENDING'/'FAILED' webhook after the payment has since legitimately
// reached 'success', silently reverting it — this handler has no
// state-transition check, so any validly-signed status blindly overwrites
// the current one). Real gateways using this exact scheme guard against
// this the same way: Stripe's `Stripe-Signature: t=<ts>,v1=<sig>` signs
// `${timestamp}.${payload}`, not the payload alone, and rejects timestamps
// outside a tolerance window. Mirrored here via `x-webhook-timestamp` +
// `MAX_WEBHOOK_AGE_SECONDS` — adjust the header name to match whichever
// real gateway is wired in, same as the signature header above.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Tolerance window for webhook freshness — generous enough to absorb
// realistic network/queueing delay and modest clock skew between this
// function and the gateway, tight enough that a captured request is only
// replayable for a few minutes rather than indefinitely.
const MAX_WEBHOOK_AGE_SECONDS = 5 * 60;

// Distinguishes "the caller did something wrong" (4xx — don't retry blindly,
// or retry only after fixing the request) from "we failed on our end" (5xx —
// real payment gateways generally only auto-retry a webhook on 5xx, so a
// transient DB failure reported as 400 would previously have been treated
// as "permanently malformed" and never retried, silently dropping the
// status update).
class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

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
      // Our own deployment is misconfigured — not the gateway's fault.
      throw new HttpError(500, 'PAYMENT_WEBHOOK_SECRET is not configured — run `supabase secrets set PAYMENT_WEBHOOK_SECRET=...` before deploying this function for real use.');
    }

    const signature = req.headers.get('x-webhook-signature');
    if (!signature) throw new HttpError(401, 'missing webhook signature');

    // Required and checked *before* signature verification so a missing/
    // stale timestamp fails fast with its own clear reason rather than
    // silently falling through to a generic "invalid signature" — but the
    // timestamp itself is only trustworthy once it's proven to be part of
    // what the gateway actually signed (below), not on its own, since an
    // attacker replaying a captured request could otherwise just swap in a
    // fresh timestamp header without the secret to slip past a freshness
    // check that ignored the signature.
    const timestampHeader = req.headers.get('x-webhook-timestamp');
    if (!timestampHeader || !/^\d+$/.test(timestampHeader)) throw new HttpError(401, 'missing or invalid webhook timestamp');
    const ageSeconds = Math.abs(Date.now() / 1000 - Number(timestampHeader));
    if (ageSeconds > MAX_WEBHOOK_AGE_SECONDS) throw new HttpError(401, 'webhook timestamp is outside the allowed freshness window');

    const rawBody = await req.text();
    // Bind the timestamp into the signed content itself (Stripe-style) —
    // this is what actually prevents replay, not the freshness check alone:
    // without this, an attacker holding one captured (payload, signature)
    // pair could pair the original signature with a freshly-forged
    // timestamp header and sail through the age check above with no
    // knowledge of the secret at all.
    const validSignature = await verifySignature(`${timestampHeader}.${rawBody}`, signature, webhookSecret);
    if (!validSignature) throw new HttpError(401, 'invalid webhook signature');

    const payload = JSON.parse(rawBody);
    const { reference, status } = payload as { reference?: string; status?: string };
    if (!reference || !status) throw new HttpError(400, 'reference and status are required in the webhook payload');

    // An unrecognized status used to be silently coerced to 'pending',
    // overwriting whatever the payment's real prior state was and masking
    // terminal states (e.g. a gateway's 'REFUNDED'/'CANCELLED') this
    // function doesn't know how to interpret. Reject instead so a
    // genuinely new/unexpected gateway status is surfaced, not swallowed.
    const statusMap: Record<string, string> = { SUCCESS: 'success', FAILED: 'failed', PENDING: 'pending' };
    const mappedStatus = statusMap[status];
    if (!mappedStatus) throw new HttpError(400, `unrecognized payment status: ${status}`);

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { error } = await supabase.from('payments').update({ status: mappedStatus }).eq('reference', reference);
    if (error) {
      // Same info-leakage class already fixed in generate-report-snapshots
      // and ai-advisor-proxy (raw Postgres/Supabase error text — table/
      // column/constraint names — reaching an external caller's response
      // body) but missed here: a valid HMAC signature makes the caller
      // *authenticated* as the gateway, not a reason to hand it internal
      // schema detail. Log the real detail server-side, return generic text.
      console.error('payment-webhook-handler: DB update failed:', error);
      throw new HttpError(500, 'Internal error');
    }

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    if (err instanceof HttpError) {
      return new Response(JSON.stringify({ ok: false, error: err.message }), { status: err.status, headers: { 'Content-Type': 'application/json' } });
    }
    // Anything not explicitly classified above (a malformed JSON body, an
    // unexpected exception) is treated as a server-side failure rather than
    // assumed to be the caller's fault.
    console.error('payment-webhook-handler unhandled error:', err);
    return new Response(JSON.stringify({ ok: false, error: 'Internal error' }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
