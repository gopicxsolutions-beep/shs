-- SHG join-approval workflow (spec: "Step 2: SHG Mapping — Member → Select
-- SHG → Approval by Leader"). A new member's profile.shg_id stays null
-- until their SHG's leader (or staff) approves the request — see
-- lib/pages/auth/shg_approval_pending_page.dart and
-- lib/pages/shg/shg_join_requests_page.dart.

create table public.shg_join_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles (id) on delete cascade,
  shg_id uuid not null references public.shgs (id) on delete cascade,
  status text not null check (status in ('pending', 'approved', 'rejected')) default 'pending',
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references public.profiles (id)
);

-- A member can only have one outstanding request at a time.
create unique index shg_join_requests_one_pending_per_member on public.shg_join_requests (member_id) where status = 'pending';

alter table public.shg_join_requests enable row level security;

create policy "shg_join_requests_select_self_leader_or_staff" on public.shg_join_requests
  for select using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  );

create policy "shg_join_requests_insert_self" on public.shg_join_requests
  for insert with check (member_id = auth.uid());

-- No update/delete policy on the table itself — decisions go through
-- approve_shg_join_request() below, which checks authorization internally
-- and needs to touch `profiles` too (a leader cannot otherwise update
-- another member's profile row per `profiles_update_self_or_admin`).
create or replace function public.approve_shg_join_request(p_request_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request record;
begin
  select * into v_request from public.shg_join_requests where id = p_request_id;
  if v_request is null then
    raise exception 'join request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'join request already decided';
  end if;

  if not (
    (public.current_role() = 'leader' and public.current_shg_id() = v_request.shg_id)
    or public.is_staff()
  ) then
    raise exception 'not authorized to decide this request';
  end if;

  if p_approve then
    update public.profiles set shg_id = v_request.shg_id where id = v_request.member_id;
    update public.shg_join_requests set status = 'approved', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  else
    update public.shg_join_requests set status = 'rejected', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  end if;
end;
$$;

grant execute on function public.approve_shg_join_request(uuid, boolean) to authenticated;
