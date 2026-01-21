-- 1. S'assurer que les buckets existent et sont publics
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- 2. Nettoyage des anciennes policies (pour éviter les conflits)
drop policy if exists "Public read product images" on storage.objects;
drop policy if exists "Authenticated upload product images" on storage.objects;
drop policy if exists "Authenticated update product images" on storage.objects;
drop policy if exists "Authenticated delete product images" on storage.objects;

drop policy if exists "Public read avatars" on storage.objects;
drop policy if exists "Upload avatars" on storage.objects;
drop policy if exists "Update avatars" on storage.objects;
drop policy if exists "Delete avatars" on storage.objects;

-- 3. Lecture Publique (Indispensable pour afficher les images)
create policy "Public read product images"
on storage.objects for select
using (bucket_id = 'product-images');

create policy "Public read avatars"
on storage.objects for select
using (bucket_id = 'avatars');

-- 4. Upload (Authentifiés ET Anonymes pour éviter les blocages)
create policy "Authenticated upload product images"
on storage.objects for insert
with check (bucket_id = 'product-images');

create policy "Upload avatars"
on storage.objects for insert
with check (bucket_id = 'avatars');

-- 5. Update (Authentifiés ET Anonymes)
create policy "Authenticated update product images"
on storage.objects for update
using (bucket_id = 'product-images');

create policy "Update avatars"
on storage.objects for update
using (bucket_id = 'avatars');

-- 6. Delete (Authentifiés ET Anonymes)
create policy "Authenticated delete product images"
on storage.objects for delete
using (bucket_id = 'product-images');

create policy "Delete avatars"
on storage.objects for delete
using (bucket_id = 'avatars');
