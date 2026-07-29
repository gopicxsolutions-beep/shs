-- Adds real video content to the Training module. Before this, `training_
-- courses.format` was just a descriptive label ('Video' | 'PDF' | 'Audio')
-- with no actual content ever attached to a course — `course_detail_page.dart`
-- had no player of any kind. This adds a `video_url` column plus a public
-- `training-videos` storage bucket (mirrors `product-images`' public-read,
-- staff-write pattern from `0005_storage_buckets.sql`/
-- `0028_storage_bucket_size_and_type_limits.sql`) so crp/clf/admin can upload
-- a real video file and members can stream it back via a stable public URL —
-- no signed-URL refresh needed mid-playback, unlike the private
-- `shg-documents` bucket.

alter table public.training_courses add column if not exists video_url text;

insert into storage.buckets (id, name, public)
values ('training-videos', 'training-videos', true)
on conflict (id) do nothing;

-- 200 MiB cap (videos are far larger than the 5-10 MiB image/document caps
-- elsewhere) and a narrow, broadly web-playable MIME allow-list.
update storage.buckets
set file_size_limit = 209715200,
    allowed_mime_types = array['video/mp4', 'video/webm', 'video/quicktime']
where id = 'training-videos';

-- Public bucket: anyone (including anon) can read, matching
-- `product_images_storage_select`'s own "to public" role.
create policy "training_videos_storage_select" on storage.objects
  for select to public
  using (bucket_id = 'training-videos');

-- Writes restricted to staff (crp/clf/admin) — matches
-- `training_courses_write_staff`'s own scope (0002_rls_policies.sql), so the
-- storage-write boundary agrees with the table-write boundary for the same
-- content.
create policy "training_videos_storage_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'training-videos' and public.is_staff());

create policy "training_videos_storage_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'training-videos' and public.is_staff())
  with check (bucket_id = 'training-videos' and public.is_staff());

create policy "training_videos_storage_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'training-videos' and public.is_staff());
