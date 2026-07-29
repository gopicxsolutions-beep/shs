-- HOTFIX, caught by this same session's own live verification of round
-- 188's migration (0093) before committing: `support_messages_insert_
-- related`'s new rate-limit clause — a bare `select count(*) from
-- public.support_messages m where m.sender_id = auth.uid() and
-- m.created_at > now() - interval '10 minutes'` embedded directly in the
-- policy's WITH CHECK — raised `42P17: infinite recursion detected in
-- policy for relation "support_messages"` on every actual INSERT attempt
-- as an authenticated member. Reproduced and isolated live: a plain SELECT
-- count against the table works fine outside a policy, and the identical
-- "self-referential COUNT subquery inside a table's own INSERT policy"
-- shape already works for `support_tickets_insert_self` (unchanged,
-- confirmed still working) — the difference here is `support_messages`'s
-- own SELECT policy (`support_messages_select_related`) has a *correlated*
-- EXISTS subquery referencing `support_messages.ticket_id`, and Postgres's
-- RLS planner appears to genuinely recurse when that correlated select-
-- policy needs re-evaluating for the rows the rate-limit COUNT is trying
-- to read, while a WITH CHECK for a brand-new row on the same table is
-- also being evaluated.
--
-- Fix: the standard, already-pervasive pattern in this schema for exactly
-- this shape (see `profile_shg_id`, `loans_locked_fields`, etc.) — wrap
-- the self-referential read in a `security definer stable` function.
-- SECURITY DEFINER bypasses RLS entirely for its own internal query (runs
-- as the function owner/table owner), so the correlated select-policy
-- recursion this triggered never gets a chance to occur.

create or replace function public.support_messages_recent_count(p_sender_id uuid, p_since timestamptz)
returns int
language sql
security definer
stable
set search_path = public
as $$
  select count(*)::int from public.support_messages m
  where m.sender_id = p_sender_id and m.created_at > p_since;
$$;

revoke all on function public.support_messages_recent_count(uuid, timestamptz) from public;
grant execute on function public.support_messages_recent_count(uuid, timestamptz) to authenticated;

drop policy if exists "support_messages_insert_related" on public.support_messages;

create policy "support_messages_insert_related" on public.support_messages
  for insert with check (
    sender_id = auth.uid()
    and public.profile_is_active(sender_id)
    and created_at = now()
    and exists (
      select 1 from public.support_tickets t
      where t.id = support_messages.ticket_id and (t.member_id = auth.uid() or public.is_staff())
    )
    and public.support_messages_recent_count(auth.uid(), now() - interval '10 minutes') < 20
  );
