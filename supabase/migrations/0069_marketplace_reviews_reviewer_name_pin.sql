-- marketplace_reviews.reviewer_name: never actually pinned to the caller's
-- real identity.
--
-- 0061 (marketplace_reviews_null_bypass_and_delivery_gate.sql) correctly
-- locked down WHO can post a review (must be `reviewer_id = auth.uid()`,
-- must have a delivered order for the product, no self-reviewing your own
-- product) — re-verified sound this round. But `reviewer_name` itself
-- (`text not null`, 0001_init_schema.sql) was never constrained at all.
-- `MarketplaceRepository.addReview()` inserts whatever string the caller
-- passes; the only reason it currently always matches the real poster is
-- that the sole UI call site (`product_detail_page.dart`) happens to pass
-- `appState.user.name`. A direct authenticated REST call — with a real,
-- valid `reviewer_id` and a real delivered order, passing every RLS check
-- 0061 enforces — can still set `reviewer_name` to any string: impersonate
-- a different real member, fabricate a fake "official" endorsement, or
-- post anonymously-but-misleadingly. Exactly the "client-side value isn't
-- server-enforced" gap this schema's own CLAUDE.md warns against.
--
-- Fix: stamp `reviewer_name` server-side from the reviewer's own `profiles`
-- row on INSERT, the same "trigger overwrites whatever the client sent"
-- shape `support_tickets_stamp_resolved_at` (0053) already established —
-- a `with check` can't do this (there's no column-vs-column comparison
-- that would catch an already-correct-looking client value), only a
-- trigger that ignores the client's submission and looks up the real name
-- itself.

create or replace function public.marketplace_reviews_pin_reviewer_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select p.name into new.reviewer_name from public.profiles p where p.id = new.reviewer_id;
  return new;
end;
$$;

drop trigger if exists marketplace_reviews_pin_reviewer_name_trigger on public.marketplace_reviews;
create trigger marketplace_reviews_pin_reviewer_name_trigger
  before insert on public.marketplace_reviews
  for each row
  execute function public.marketplace_reviews_pin_reviewer_name();
