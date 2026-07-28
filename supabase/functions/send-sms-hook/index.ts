// Supabase Auth "Send SMS" hook — replaces the built-in Twilio phone
// provider with Fast2SMS (an Indian SMS gateway) as the actual OTP
// delivery mechanism. `lib/services/auth_service.dart`'s
// `signInWithOtp`/`verifyOTP` calls are UNCHANGED by this: Supabase Auth
// still owns OTP generation, storage, and verification end-to-end. This
// hook only intercepts the one "now send this code by SMS" step —
// Supabase invokes this function instead of its built-in Twilio
// integration, we relay the already-generated code to Fast2SMS, and
// verification later still goes through Supabase's own `verifyOTP`. No
// Flutter-side changes are needed for this swap.
//
// NOT DEPLOYED by default — this is dormant until wired up. To activate:
//   1. `supabase secrets set FAST2SMS_API_KEY=...` (from the Fast2SMS
//      dashboard), `FAST2SMS_OTP_TEMPLATE_ID=...` (the numeric DLT-approved
//      message/template id shown in the Fast2SMS DLT section — required by
//      TRAI regardless of gateway; see docs/DEVELOPMENT_PROGRESS.md's DLT
//      note), and `FAST2SMS_SENDER_ID=...` (the DLT-approved 6-char sender
//      id, e.g. "SSENEE" — must be the sender id that template was actually
//      registered under, or Fast2SMS/DLT will reject the send).
//   2. `supabase functions deploy send-sms-hook --no-verify-jwt` — the
//      `--no-verify-jwt` is required, not optional: this hook fires during
//      signInWithOtp(), before any Supabase JWT exists, and the hook
//      caller only sends the webhook-* signature headers (see the
//      signature-verification note below), never an Authorization: Bearer
//      token. Without this flag the platform gateway 401s every call
//      before it reaches this function's own code at all — a failure mode
//      that looks identical to a bad SEND_SMS_HOOK_SECRET from the
//      outside, so don't skip it on a redeploy.
//   3. Supabase Dashboard → Authentication → Hooks → "Send SMS hook" →
//      enable it, HTTPS type, point at this function's URL. The dashboard
//      generates a signing secret (`v1,whsec_...`) at that point — copy it
//      and `supabase secrets set SEND_SMS_HOOK_SECRET='v1,whsec_...'`
//      (must match exactly what the dashboard shows, or every signature
//      verification below will fail closed and OTP delivery will silently
//      stop).
// Until step 3 is done in the dashboard, Supabase keeps using whichever
// provider (Twilio) is configured under Authentication → Providers →
// Phone — this hook has no effect merely by being deployed.
//
// Payload/response contract is Supabase's, not ours to redesign: Supabase
// POSTs `{ user: { phone, ... }, sms: { otp: "123456" } }` and expects a
// bare 200 on success, or a non-2xx with
// `{ error: { http_code, message } }` on failure (the shape it surfaces
// back to the client's signInWithOtp() call).
//
// Signature verification uses the `standardwebhooks` library rather than
// hand-rolled HMAC (contrast supabase/functions/payment-webhook-handler,
// which hand-rolls verification because no gateway-provided library exists
// for that integration) — this is the exact library Supabase's own docs
// use for Auth Hooks, and it already handles timestamp-tolerance replay
// protection internally, so there's no separate freshness check to get
// wrong here.
//
// Uses Fast2SMS's DLT route (`POST /dev/bulkV2` with `route: "dlt"`), not
// the separate /dev/otp/send endpoint — this account's approved OTP
// template is a DLT template message id (`FAST2SMS_OTP_TEMPLATE_ID`, e.g.
// "177598") sent via `message`, with the actual OTP substituted into the
// template's `{#var#}` placeholder via `variables_values` (pipe-separated,
// e.g. "123456|" for a single-variable template). Fast2SMS returns HTTP 200
// with `{ return: false, ... }` in the body on failure (bad sender id,
// unapproved template, insufficient balance, etc.), not a non-2xx status —
// both are checked. If real sends succeed but this still reports failure,
// or vice versa, check the logged raw response body first.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0';

const FAST2SMS_URL = 'https://www.fast2sms.com/dev/bulkV2';

class HttpError extends Error {
  httpCode: number;
  constructor(httpCode: number, message: string) {
    super(message);
    this.httpCode = httpCode;
  }
}

// GoTrue's `user.phone` field is E.164 digits WITHOUT a leading "+" (e.g.
// "919876543210", not "+919876543210") — this is a well-known Supabase Auth
// quirk, unlike the "+91..." shape used elsewhere (client-side signInWithOtp
// calls, display strings). Accept an optional leading "+" so this works
// against both the real hook payload and any manually-prefixed test input.
// Fast2SMS's `numbers` field expects a bare 10-digit Indian number — reject
// anything else rather than silently mis-sending, since a truncated/garbled
// number would fail at the carrier with no useful error back to us.
function toFast2SmsMobile(e164Phone: string): string {
  const match = /^\+?91([6-9]\d{9})$/.exec(e164Phone);
  if (!match) {
    throw new HttpError(
      400,
      `Fast2SMS OTP route only supports Indian (+91) numbers; got "${e164Phone}"`,
    );
  }
  return match[1];
}

serve(async (req) => {
  try {
    const hookSecret = Deno.env.get('SEND_SMS_HOOK_SECRET');
    if (!hookSecret) {
      throw new HttpError(
        500,
        'SEND_SMS_HOOK_SECRET is not configured — set it to the secret shown when enabling the Send SMS hook in the Supabase dashboard before deploying this function for real use.',
      );
    }
    const apiKey = Deno.env.get('FAST2SMS_API_KEY');
    const otpTemplateId = Deno.env.get('FAST2SMS_OTP_TEMPLATE_ID');
    const senderId = Deno.env.get('FAST2SMS_SENDER_ID');
    if (!apiKey || !otpTemplateId || !senderId) {
      throw new HttpError(
        500,
        'FAST2SMS_API_KEY / FAST2SMS_OTP_TEMPLATE_ID / FAST2SMS_SENDER_ID are not configured — run `supabase secrets set` for all three before deploying this function for real use.',
      );
    }

    const rawBody = await req.text();
    const headers = Object.fromEntries(req.headers);

    let payload: { user?: { phone?: string }; sms?: { otp?: string } };
    try {
      // wh.verify both checks the signature and parses the JSON body —
      // a request that fails verification never reaches the parsed value.
      const wh = new Webhook(hookSecret.replace('v1,whsec_', ''));
      payload = wh.verify(rawBody, headers) as typeof payload;
    } catch (err) {
      console.error('send-sms-hook: signature verification failed:', err);
      throw new HttpError(401, 'invalid webhook signature');
    }

    const phone = payload.user?.phone;
    const otp = payload.sms?.otp;
    if (!phone || !otp) {
      throw new HttpError(400, 'payload missing user.phone or sms.otp');
    }

    const mobile = toFast2SmsMobile(phone);

    const fast2SmsResponse = await fetch(FAST2SMS_URL, {
      method: 'POST',
      headers: {
        authorization: apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        route: 'dlt',
        sender_id: senderId,
        message: otpTemplateId,
        variables_values: `${otp}|`,
        numbers: mobile,
      }),
    });

    const responseText = await fast2SmsResponse.text();
    let responseBody: { return?: boolean } | undefined;
    try {
      responseBody = JSON.parse(responseText);
    } catch {
      // Non-JSON response — fall through to the status-code check below.
    }

    if (!fast2SmsResponse.ok || responseBody?.return === false) {
      // Logged server-side only — never echo the API key, and Fast2SMS's
      // raw error text stays out of the response Supabase relays toward
      // the client.
      console.error(
        `send-sms-hook: Fast2SMS send failed (status ${fast2SmsResponse.status}):`,
        responseText,
      );
      throw new HttpError(500, 'Failed to send OTP SMS via Fast2SMS');
    }

    return new Response('{}', { status: 200, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    if (err instanceof HttpError) {
      return new Response(
        JSON.stringify({ error: { http_code: err.httpCode, message: err.message } }),
        { status: err.httpCode, headers: { 'Content-Type': 'application/json' } },
      );
    }
    console.error('send-sms-hook unhandled error:', err);
    return new Response(
      JSON.stringify({ error: { http_code: 500, message: 'Internal error' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
