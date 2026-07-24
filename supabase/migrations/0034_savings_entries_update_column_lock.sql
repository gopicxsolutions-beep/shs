-- Dedicated deep-dive on the savings-entry VERIFICATION flow (a leader
-- confirming a member's self-reported deposit actually happened) — this
-- table's UPDATE policy had never been re-derived against EVERY column the
-- way rounds 46-48 (0023/0024) already did for `loans`/`marketplace_orders`/
-- `announcements`. In fact `savings_entries` was the ORIGINAL source of the
-- "missing/buggy `with check`" bug class those rounds went hunting for
-- elsewhere (round 12 first flagged it here), yet the follow-up full
-- column-by-column re-derivation somehow never circled back to it.
--
-- `savings_update_leader_or_staff` (0002_rls_policies.sql):
--   for update using (
--     (shg_id = current_shg_id() and current_role() = 'leader') or is_staff()
--   )
-- — no separate `with check`. Postgres defaults an absent `with check` to
-- the same expression as `using`, so the only real constraint on the
-- POST-image is `shg_id = current_shg_id()` (already effectively implied,
-- since the row had to satisfy that to be matched in the first place, and
-- the caller's own `shg_id` can't be spoofed via the security-definer
-- `current_shg_id()` helper). Every OTHER column — `amount`, `member_id`,
-- `mode`, `frequency`, `entry_date`, `created_at` — is completely
-- unconstrained.
--
-- `SavingsRepository.verifyEntry()` (lib/repositories/savings_repository.dart)
-- is the ONLY call site anywhere in `lib/` that ever updates this table
-- (grepped every repository referencing `savings_entries`; `admin_repository
-- .dart`/`trend_repository.dart`/`report_repository.dart`/
-- `analytics_repository.dart` only ever `.select()`), and it always sends
-- exactly `{'status': 'verified'}` — never any other column. So a leader
-- tapping "Verify" on `savings_ledger_page.dart`'s ledger for a fellow
-- member's pending deposit can, via a direct REST `PATCH
-- .../savings_entries?id=eq.<id>` in place of the app's own call, ALSO
-- silently rewrite that same entry's `amount` — inflating or deflating
-- what the member actually reported depositing, under cover of an
-- ordinary-looking verification action and with no independent review of
-- the actual figure being confirmed. This directly corrupts the SHG's
-- group savings total: every total-savings query already correctly filters
-- to `status = 'verified'` (round 41/44's fix), so a tampered amount
-- becomes instantly-"confirmed" group funds the moment the same PATCH also
-- flips `status`. The same open door lets `member_id` be reassigned
-- (misattributing whose deposit this is) or `entry_date` backdated into a
-- different reporting month (the same compliance-figure manipulation
-- vector 0027's INSERT-side fix already closed one step earlier, now open
-- again one step later via UPDATE). Fix: lock every non-workflow column to
-- its already-stored value, using the same security-definer
-- read-gated-locked-fields pattern already established for `loans`/
-- `marketplace_orders`/`announcements` (avoids the self-referencing-
-- subquery recursion 0018/0019 first ran into).
--
-- `status` is deliberately left OUT of the lock, matching the loans/
-- marketplace_orders precedent (the workflow column stays free — it's the
-- entire point of this policy's one legitimate write). Leaving it free also
-- preserves round 68's "genuinely idempotent, not a real double-effect"
-- verdict for concurrent verification, re-traced fresh here rather than
-- trusted: two leaders tapping "Verify" on the same pending entry around
-- the same time both just re-assert `status = 'verified'` against whatever
-- row image they each read — `verifyEntry()` is a flat assignment, not a
-- read-modify-write increment, so there is no lost-update window for two
-- concurrent writers to race inside, and adding a "previous status must
-- have been 'pending'" lock here would actually make this WORSE (the loser
-- of the race would get a hard RLS-violation error instead of a harmless
-- silent no-op) — deliberately not added.
--
-- Also re-traced fresh and confirmed unchanged from round 12's own verdict:
--   - Cross-SHG verification is NOT possible — `using` scopes to `shg_id =
--     current_shg_id()`, a security-definer read of the CALLER's own stored
--     `shg_id` (0009), which cannot be made to equal a different SHG's id
--     no matter what's cached client-side or sent via direct REST.
--   - Self-verification (a leader marking her OWN submitted entry
--     `verified`) is still reachable, both via RLS (the leader branch never
--     excludes `member_id = auth.uid()`) AND via the UI —
--     `savings_ledger_page.dart`'s ledger has no filter hiding a leader's
--     own entries from the list, so the "Verify" button renders on her own
--     pending deposits exactly like anyone else's. This is round 12's own
--     explicitly-disclosed, deliberately-NOT-fixed judgment call ("moves no
--     money OUT of the SHG", mirrors real-world practice where the
--     treasurer's own contribution is tallied alongside everyone else's at
--     the same witnessed meeting) — left unchanged here, still the team's
--     own call to make, not unilaterally decided by this migration.
--   - Un-verification (reverting `status` back to `'pending'` after the
--     fact) has no in-app affordance (the ledger's verified rows render a
--     static badge with no revert control) and, even via direct REST, can't
--     produce a stale-total artifact: every total-savings figure in this
--     codebase is computed live by filtering `status = 'verified'` at query
--     time (round 41/44), never cached/materialized, so a reverted entry is
--     simply excluded from the very next read — nothing to reconcile.

create or replace function public.savings_entries_locked_fields(p_id uuid)
returns table (amount numeric, member_id uuid, mode text, frequency text, entry_date date, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select s.amount, s.member_id, s.mode, s.frequency, s.entry_date, s.created_at
  from public.savings_entries s
  where s.id = p_id
    and (s.member_id = auth.uid() or s.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.savings_entries_locked_fields(uuid) from public;
grant execute on function public.savings_entries_locked_fields(uuid) to authenticated;

drop policy if exists "savings_update_leader_or_staff" on public.savings_entries;

create policy "savings_update_leader_or_staff" on public.savings_entries
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  )
  with check (
    public.is_staff()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and amount = (select f.amount from public.savings_entries_locked_fields(savings_entries.id) f)
      and member_id = (select f.member_id from public.savings_entries_locked_fields(savings_entries.id) f)
      and mode = (select f.mode from public.savings_entries_locked_fields(savings_entries.id) f)
      and frequency = (select f.frequency from public.savings_entries_locked_fields(savings_entries.id) f)
      and entry_date = (select f.entry_date from public.savings_entries_locked_fields(savings_entries.id) f)
      and created_at = (select f.created_at from public.savings_entries_locked_fields(savings_entries.id) f)
    )
  );
