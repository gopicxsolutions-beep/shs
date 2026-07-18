-- Storage buckets for real file uploads (previously metadata-only):
--   shg-documents   private — shg_documents.storage_path points here, path convention {shg_id}/{filename}
--   product-images  public read — marketplace_products.image_url points here, path convention {seller_id}/{filename}
-- Reuses the existing current_shg_id()/is_leader_or_staff()/is_staff() helper
-- functions from 0002_rls_policies.sql rather than duplicating that logic.

insert into storage.buckets (id, name, public)
values ('shg-documents', 'shg-documents', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- shg-documents: members of the shg (folder = shg_id) can read; leader/staff can write.
create policy "shg_documents_storage_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'shg-documents' and (storage.foldername(name))[1] = public.current_shg_id()::text or public.is_staff());

create policy "shg_documents_storage_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'shg-documents'
    and (
      (public.is_leader_or_staff() and (storage.foldername(name))[1] = public.current_shg_id()::text)
      or public.is_staff()
    )
  );

create policy "shg_documents_storage_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'shg-documents'
    and (
      (public.is_leader_or_staff() and (storage.foldername(name))[1] = public.current_shg_id()::text)
      or public.is_staff()
    )
  );

-- product-images: public read (bucket itself is public, but explicit policy
-- covers the authenticated/anon select path too); sellers write only their
-- own folder (their own profile id).
create policy "product_images_storage_select" on storage.objects
  for select to public
  using (bucket_id = 'product-images');

create policy "product_images_storage_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "product_images_storage_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);
