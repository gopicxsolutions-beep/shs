-- support_tickets: no rate limit on creation, and no server-side length
-- cap on subject/description.
--
-- `support_tickets_insert_self` (0027) locks `member_id`/`status`/
-- `created_at` but never bounded how MANY tickets a member can create, nor
-- how long `subject`/`description` can be — `support_ticket_form_page.dart`'s
-- `maxLength: 150`/`1000` are client-side only, trivially bypassed via a
-- direct REST insert. A member (or a compromised/scripted account) could
-- spam-create unbounded tickets, or post an arbitrarily large description.
--
-- Fix: cap subject/description length at the DB layer (matching the
-- client's own limits), and gate the insert policy on the caller not
-- already having 10+ tickets in the last hour — generous for genuine use
-- (a member filing one complaint at a time), but closes the unbounded-spam
-- gap. Mirrors this schema's established rate-limit shape
-- (`check_and_increment_ai_advisor_rate_limit`, `quiz_attempt_counters`) at
-- the RLS layer instead of a separate counter table, since a straight count
-- of existing tickets is cheap and doesn't need a bespoke helper table.

alter table public.support_tickets add constraint support_tickets_subject_length_check check (char_length(subject) <= 150);
alter table public.support_tickets add constraint support_tickets_description_length_check check (description is null or char_length(description) <= 1000);

drop policy if exists "support_tickets_insert_self" on public.support_tickets;

create policy "support_tickets_insert_self" on public.support_tickets
  for insert with check (
    member_id = auth.uid()
    and status = 'open'
    and created_at = now()
    and (select count(*) from public.support_tickets t where t.member_id = auth.uid() and t.created_at > now() - interval '1 hour') < 10
  );
