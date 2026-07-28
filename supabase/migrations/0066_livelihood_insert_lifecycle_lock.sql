-- livelihood_insert_self_leader_or_staff: lock `status`/`revenue` at
-- creation time, matching every other lifecycle-locked INSERT policy in
-- this schema (loans, scheme_applications, etc.).
--
-- Found during a broad gap-hunting audit. `0036`'s own dedicated
-- `livelihood_activities` deep-dive explicitly scoped itself to the UPDATE
-- policy only ("did not re-verify every INSERT/DELETE policy's column
-- scope from scratch... out of this migration's stated focus"), and
-- `0027`'s original INSERT review reasoned "no other party's interests are
-- at stake in what stage SHE calls her own livelihood activity" — a
-- reasonable call in isolation, but `0039`'s LATER, more specific finding
-- for this exact table's DELETE policy established the opposite: a
-- livelihood activity's numbers ARE a stake other parties care about,
-- since they feed the SHG-wide/platform-wide livelihoods totals CRP/CLF
-- and (per 0039's own words) "a CLF/bank review" may treat as authoritative.
-- That later finding was never connected back to this INSERT policy.
--
-- `LivelihoodRepository.create()` (lib/repositories/livelihood_repository.dart)
-- always sends exactly `revenue: 0, status: 'planned'` — a brand-new
-- activity is never created already revenue-generating or already
-- completed; `updateProgress()` is the only intended path to move either
-- value forward. Without this lock, a direct
-- `POST /rest/v1/livelihood_activities` can set `status: 'completed'` and
-- an arbitrary `revenue` in the very same call that creates the row,
-- fabricating a fully-realized, highly profitable activity with no
-- staging step — the mirror image of the "erase a bad activity" gaming
-- risk 0039 already closed on the delete side.

drop policy if exists "livelihood_insert_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_insert_self_leader_or_staff" on public.livelihood_activities
  for insert with check (
    (
      (member_id = auth.uid() and shg_id = public.current_shg_id())
      or (
        shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and public.profile_shg_id(member_id) = shg_id
      )
      or public.is_staff()
    )
    and status = 'planned'
    and revenue = 0
  );
