// Cross-turn conversation memory for ai-advisor-proxy/index.ts.
//
// Until this file existed, every request to Groq was a single, stateless
// [system, user] pair (see docs/AI_MODULES.md §2.1's disclosed gap) — an
// advisor could never reference anything the member asked earlier in the
// same chat session, even though the chat UI visually shows a running list
// of Q&A pairs. lib/repositories/ai_advisor_repository.dart now keeps a
// small in-memory list of the current chat session's prior turns (reset
// whenever the member leaves and reopens the page — never persisted to a
// database) and sends the most recent slice of it alongside each new query
// as `{ history: [{ query, response }, ...] }`. This module turns that
// client-supplied slice into real prior user/assistant messages for the
// Groq chat-completions request — actual conversational turns, not text
// folded into the system prompt.
//
// Deliberately has NO Deno-specific imports (no `Deno.*`, no remote URL
// imports) so it's unit-testable with a plain `deno test`, matching
// moderation.ts's own no-remote-imports design. It does import from
// ./moderation.ts (itself dependency-free) to reuse the same
// prompt-injection-hardening delimiter wrapper for every user-authored turn,
// past or present.

import { buildUserMessage, checkQueryForDisallowedContent } from './moderation.ts';

export type HistoryExchange = { query: string; response: string };
export type ChatMessage = { role: 'system' | 'user' | 'assistant'; content: string };

// Hard cap on how many prior turns are ever forwarded to the model,
// regardless of how many the caller sends. Independent of index.ts's
// `MAX_QUERY_LENGTH`, which only bounds the size of the *new* query — this
// bounds the *history*, which is what actually grows as a chat session goes
// on.
export const MAX_HISTORY_EXCHANGES = 6;

// Combined character budget across every forwarded history query+response.
// A long-running chat session must never make a single outgoing request
// grow without bound just because the conversation has gone on for a
// while: once this budget is exceeded, boundHistory() below drops the
// oldest turns first, keeping only the most recent (most relevant)
// context.
export const MAX_HISTORY_TOTAL_CHARS = 6000;

// Defensive per-field cap for anyone calling this Edge Function directly
// (bypassing the Flutter app and its own bookkeeping entirely) with a
// single oversized entry — without this, one huge entry could occupy the
// whole MAX_HISTORY_TOTAL_CHARS budget on its own while still passing a
// naive "is this an array of strings" shape check.
export const MAX_HISTORY_FIELD_CHARS = 2000;

/// Thrown by [validateHistoryShape] for a malformed `history` field —
/// index.ts catches this and turns it into a 400, the same posture it
/// already takes with a malformed `advisor_type`/`query`.
export class InvalidHistoryError extends Error {}

/// Validates the shape of a client-supplied `history` field. Returns `[]`
/// for `undefined`/`null` (history is optional — the very first message in
/// a session has none). Throws [InvalidHistoryError] for anything that
/// isn't an array of `{ query: string, response: string }` objects with
/// non-empty, bounded-length fields.
// A generous ceiling on the RAW entry count, checked before mapping/
// validating a single one — independent of MAX_HISTORY_EXCHANGES (which
// only bounds what's ultimately *forwarded*). Without this, a client could
// send an arbitrarily large array and make this function do proportionally
// more validation work per request before boundHistory() ever gets a chance
// to trim it down to size.
export const MAX_HISTORY_RAW_ENTRIES = 20;

export function validateHistoryShape(raw: unknown): HistoryExchange[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) throw new InvalidHistoryError('history must be an array');
  if (raw.length > MAX_HISTORY_RAW_ENTRIES) {
    throw new InvalidHistoryError(`history may contain at most ${MAX_HISTORY_RAW_ENTRIES} entries`);
  }
  return raw.map((entry) => {
    if (
      !entry ||
      typeof entry !== 'object' ||
      typeof (entry as Record<string, unknown>).query !== 'string' ||
      typeof (entry as Record<string, unknown>).response !== 'string'
    ) {
      throw new InvalidHistoryError('each history entry must have string "query" and "response" fields');
    }
    const query = ((entry as Record<string, unknown>).query as string).trim();
    const response = ((entry as Record<string, unknown>).response as string).trim();
    if (!query || !response) throw new InvalidHistoryError('history entries must not be empty');
    if (query.length > MAX_HISTORY_FIELD_CHARS || response.length > MAX_HISTORY_FIELD_CHARS) {
      throw new InvalidHistoryError(`each history field must be at most ${MAX_HISTORY_FIELD_CHARS} characters`);
    }
    return { query, response };
  });
}

/// Applies both bounds: keeps only the most recent [MAX_HISTORY_EXCHANGES]
/// turns, then drops the oldest of those (one at a time) until the combined
/// content fits within [MAX_HISTORY_TOTAL_CHARS] — so a request can never
/// grow past that budget no matter how long the session has run or how
/// large the (already per-field-capped) individual entries are.
export function boundHistory(history: HistoryExchange[]): HistoryExchange[] {
  let bounded = history.length > MAX_HISTORY_EXCHANGES ? history.slice(history.length - MAX_HISTORY_EXCHANGES) : history;
  const totalChars = (list: HistoryExchange[]) => list.reduce((sum, h) => sum + h.query.length + h.response.length, 0);
  while (bounded.length > 0 && totalChars(bounded) > MAX_HISTORY_TOTAL_CHARS) {
    bounded = bounded.slice(1);
  }
  return bounded;
}

/// Return shape for [checkHistoryForDisallowedContent] — a superset of
/// [PreFilterResult] that additionally carries the actual offending text
/// when blocked. Without this, index.ts's blocked-request logging (migration
/// 0044) had no way to record anything but the *live* query for a
/// history-triggered block — a real gap an adversarial review found: a
/// staff member reviewing a history-triggered "self-harm"/"jailbreak" block
/// would see an innocuous current question with no visible connection to
/// why it was actually blocked, since the real offending text could be
/// buried in a spoofed prior `response` (see this function's own doc
/// comment on why `response` needs scrutiny too).
export type HistoryFilterResult = { blocked: true; reason: string; matchedText: string } | { blocked: false };

/// Runs the content pre-filter (see ./moderation.ts) over BOTH fields of
/// every history entry — `query` and `response` alike — and returns the
/// first block found (including the actual matched text, for logging), or
/// `{ blocked: false }` if none.
///
/// Checking `response` too (not just `query`) closes a real bypass an
/// adversarial review found: the legitimate Flutter client always
/// populates `response` from its own prior `ask()` return (see
/// lib/repositories/ai_advisor_repository.dart), so it's tempting to trust
/// it as "the model's own prior output, not member-controlled text" — but
/// nothing server-side actually enforces that assumption. Anyone calling
/// this Edge Function directly can put arbitrary text in `response`,
/// including a fabricated "assistant" turn designed to prime the live model
/// with a jailbreak/persona-shift immediately before an otherwise-innocent
/// question. There's no way to cryptographically verify a client-supplied
/// `response` is genuinely prior model output, so it gets the same
/// scrutiny as member-authored text.
export function checkHistoryForDisallowedContent(history: HistoryExchange[]): HistoryFilterResult {
  for (const turn of history) {
    const queryResult = checkQueryForDisallowedContent(turn.query);
    if (queryResult.blocked) return { ...queryResult, matchedText: turn.query };
    const responseResult = checkQueryForDisallowedContent(turn.response);
    if (responseResult.blocked) return { ...responseResult, matchedText: turn.response };
  }
  return { blocked: false };
}

/// Builds the full Groq chat-completions `messages` array: the (already
/// injection-hardened) system prompt, each prior turn as a real
/// `user`/`assistant` message pair in chronological order, then the new
/// query — real conversational memory, not text folded into the system
/// prompt. Every user-authored turn (past or present) goes through the same
/// [buildUserMessage] delimiter wrapper so past turns get the same
/// prompt-injection hardening as the live query; assistant turns are passed
/// through as-is since they're the model's own prior output, not
/// member-controlled text.
export function buildMessagesWithHistory(hardenedSystemPrompt: string, history: HistoryExchange[], query: string): ChatMessage[] {
  const messages: ChatMessage[] = [{ role: 'system', content: hardenedSystemPrompt }];
  for (const turn of history) {
    messages.push({ role: 'user', content: buildUserMessage(turn.query) });
    messages.push({ role: 'assistant', content: turn.response });
  }
  messages.push({ role: 'user', content: buildUserMessage(query) });
  return messages;
}
