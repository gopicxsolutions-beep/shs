-- announcement_reads_self_or_staff: split the single `FOR ALL` policy so
-- staff can still read every member's read receipts (useful for
-- engagement visibility), but can no longer WRITE one on another
-- member's behalf.
--
-- Found during a broad gap-hunting audit. This exact policy was reviewed
-- twice before (0038, 0039) and both times judged safe/low-stakes — but
-- both reviews only reasoned about the `member_id = auth.uid()` SELF
-- branch (a member deleting/inserting her own read receipt: reversible,
-- personal, no one else's data touched). Neither review examined what the
-- `or is_staff()` branch actually permits: `for all ... using (member_id =
-- auth.uid() or is_staff()) with check (member_id = auth.uid() or
-- is_staff())` lets ANY crp/clf/admin account write a row with an
-- ARBITRARY `member_id` — not just their own. `AnnouncementRepository.
-- markRead()` (lib/repositories/announcement_repository.dart) only ever
-- calls this with the caller's own id, so there is no legitimate feature
-- relying on staff writing on another member's behalf; the escalation
-- surface is pure latent risk.
--
-- Concrete exploit this closes: a staff account could
-- `POST /rest/v1/announcement_reads {announcement_id, member_id: <any
-- other member>}` to silently clear that member's unread badge for an
-- announcement she never opened, or `DELETE` her genuine read row to make
-- an actually-read announcement look unread again — tampering with the
-- one per-member audit table in this schema whose whole purpose is an
-- honest personal record.

drop policy if exists "announcement_reads_self_or_staff" on public.announcement_reads;

create policy "announcement_reads_select_self_or_staff" on public.announcement_reads
  for select using (member_id = auth.uid() or public.is_staff());

create policy "announcement_reads_write_self" on public.announcement_reads
  for insert with check (member_id = auth.uid());

create policy "announcement_reads_update_self" on public.announcement_reads
  for update using (member_id = auth.uid()) with check (member_id = auth.uid());

create policy "announcement_reads_delete_self" on public.announcement_reads
  for delete using (member_id = auth.uid());
