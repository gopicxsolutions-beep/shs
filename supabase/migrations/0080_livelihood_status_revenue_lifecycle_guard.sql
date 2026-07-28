-- livelihood_activities: revenue/status were completely unbounded once
-- past the INSERT-time lock (0038 required a fresh insert to start at
-- status='planned', revenue=0 -- this is the UPDATE-side gap that lock
-- never covered).
--
-- livelihood_update_self_leader_or_staff (0036) locks shg_id/member_id/
-- activity_type/description/investment/created_at but leaves revenue/
-- status fully open for both the owning member and the SHG's leader:
-- either can jump straight to status='completed' with any revenue in one
-- call (skipping 'active' entirely), move status backwards while revenue
-- stays at its inflated value, or keep re-editing revenue indefinitely
-- after the activity is already marked completed. These numbers feed
-- straight into SHG-wide (and platform-wide, for staff) dashboard totals
-- (livelihood_home_page.dart), so this isn't inert.
--
-- Fix: for non-staff, require status to move forward by at most one step
-- along ['planned','active','completed'] per call (same shape as
-- advance_marketplace_order_status, 0068), and once the activity is
-- already 'completed', revenue is frozen -- matches the real-world shape
-- (revenue is a running tally while the activity is planned/active; once
-- completed, the final figure shouldn't keep moving). Staff keep their
-- existing unconditional correction bypass.
--
-- The policy using the old function signature must be dropped before the
-- function itself (Postgres refuses to drop a function that a live policy
-- still depends on).

drop policy if exists "livelihood_update_self_leader_or_staff" on public.livelihood_activities;

drop function if exists public.livelihood_activities_locked_fields(uuid);

create or replace function public.livelihood_activities_locked_fields(p_id uuid)
returns table (shg_id uuid, member_id uuid, activity_type text, description text, investment numeric, created_at timestamptz, status text, revenue numeric)
language sql
security definer
stable
set search_path = public
as $$
  select l.shg_id, l.member_id, l.activity_type, l.description, l.investment, l.created_at, l.status, l.revenue
  from public.livelihood_activities l
  where l.id = p_id
    and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.livelihood_activities_locked_fields(uuid) from public;
grant execute on function public.livelihood_activities_locked_fields(uuid) to authenticated;

create policy "livelihood_update_self_leader_or_staff" on public.livelihood_activities
  for update using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  ) with check (
    public.is_staff()
    or (
      (member_id = auth.uid() or (shg_id = public.current_shg_id() and public.current_role() = 'leader'))
      and shg_id = (select f.shg_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and member_id = (select f.member_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and activity_type = (select f.activity_type from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and description is not distinct from (select f.description from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and investment is not distinct from (select f.investment from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and created_at = (select f.created_at from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and abs(
        array_position(array['planned', 'active', 'completed'], status)
        - array_position(array['planned', 'active', 'completed'], (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f))
      ) <= 1
      and (
        (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f) <> 'completed'
        or revenue = (select f.revenue from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      )
    )
  );
