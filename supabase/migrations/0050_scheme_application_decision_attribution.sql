-- ─────────────────────────────────────────────────────────────────────────
-- scheme_applications: record who decided an application and lock every
-- other column on that decision
--
-- Unlike `shg_join_requests` (which has carried `decided_by` since
-- `0004_shg_join_requests.sql`), a decided scheme application recorded
-- nothing about which staff account approved or rejected it — a real
-- audit-trail gap for a government-scheme approval record, the same
-- completeness bar round 94 already applied to the Financial Records
-- Audit Trail's `created_by`. Adds `decided_by`/`decided_at`, has
-- `decide_scheme_application()` set them (still the only way this table is
-- ever updated in the app), and locks `scheme_id`/`member_id`/`applied_on`
-- so a staff decision can't also silently rewrite which application or
-- applicant it was for — the same "column-lock independent of row access"
-- shape already applied to loans/savings/livelihood.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.scheme_applications add column if not exists decided_by uuid references public.profiles (id);
alter table public.scheme_applications add column if not exists decided_at timestamptz;

create or replace function public.scheme_applications_locked_fields(p_application_id uuid)
returns table (scheme_id uuid, member_id uuid, applied_on date)
language sql
security definer
stable
set search_path = public
as $$
  select a.scheme_id, a.member_id, a.applied_on
  from public.scheme_applications a
  where a.id = p_application_id
    and (a.member_id = auth.uid() or public.is_staff());
$$;

revoke all on function public.scheme_applications_locked_fields(uuid) from public;
grant execute on function public.scheme_applications_locked_fields(uuid) to authenticated;

drop policy if exists "scheme_applications_update_staff" on public.scheme_applications;

create policy "scheme_applications_update_staff" on public.scheme_applications
  for update using (
    is_staff() and member_id <> auth.uid()
  ) with check (
    is_staff()
    and member_id <> auth.uid()
    and decided_by = auth.uid()
    and decided_at = now()
    and scheme_id = (select f.scheme_id from public.scheme_applications_locked_fields(scheme_applications.id) f)
    and member_id = (select f.member_id from public.scheme_applications_locked_fields(scheme_applications.id) f)
    and applied_on = (select f.applied_on from public.scheme_applications_locked_fields(scheme_applications.id) f)
  );

create or replace function public.decide_scheme_application(p_application_id uuid, p_approve boolean)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status from public.scheme_applications where id = p_application_id for update;

  if v_status is null then
    raise exception 'application not found';
  end if;
  if v_status not in ('applied', 'under_review') then
    raise exception 'application already decided (current status: %)', v_status;
  end if;

  update public.scheme_applications
    set status = case when p_approve then 'approved' else 'rejected' end,
        decided_by = auth.uid(),
        decided_at = now()
    where id = p_application_id;

  -- security invoker: still subject to scheme_applications_update_staff
  -- (now also self-decision-blocked, see above). FOUND guards the same
  -- silent-0-row-RLS-filter case as the two loan functions above.
  if not found then
    raise exception 'not authorized to decide this application, or application not found';
  end if;
end;
$$;

revoke all on function public.decide_scheme_application(uuid, boolean) from public;
grant execute on function public.decide_scheme_application(uuid, boolean) to authenticated;
