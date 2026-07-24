-- 0005_storage_buckets.sql created shg-documents/product-images with RLS but
-- left file_size_limit/allowed_mime_types unset (Storage defaults to
-- unlimited size, any mime type). No Flutter upload UI exists yet (no
-- image_picker/file_picker dependency, no .upload() call site anywhere in
-- lib/ as of this audit — the "Add document"/"Add Product" pages are
-- metadata-only), but the buckets themselves are live in production with
-- RLS policies letting any authenticated leader/staff (shg-documents) or any
-- authenticated user (product-images) INSERT into their own folder — reachable
-- directly via the Storage REST API independent of what the Flutter client
-- wires up, same threat model already used elsewhere in this migration series
-- (RLS gaps tested via raw API/SQL, not just through the app UI). Without a
-- cap, that's an unbounded storage-cost / DoS surface: one authenticated user
-- could push an arbitrarily large blob, or a non-PDF/image file that the
-- planned document-type icons (_typeIcons in shg_documents_page.dart: PDF/IMG
-- only) can't represent. Setting sane server-side caps now costs nothing
-- (no existing feature relies on the unlimited default) and closes the gap
-- before the upload UI is ever built.

update storage.buckets
set file_size_limit = 10485760, -- 10 MiB
    allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
where id = 'shg-documents';

update storage.buckets
set file_size_limit = 5242880, -- 5 MiB
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'product-images';
