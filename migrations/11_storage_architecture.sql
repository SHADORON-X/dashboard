-- 1. Créer le bucket 'product-images'
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- 2. Autoriser lecture publique
drop policy if exists "Public read product images" on storage.objects;
create policy "Public read product images"
on storage.objects for select
using (bucket_id = 'product-images');

-- 3. Autoriser upload (auth users)
drop policy if exists "Authenticated upload product images" on storage.objects;
create policy "Authenticated upload product images"
on storage.objects for insert
with check (
  bucket_id = 'product-images'
  and auth.role() = 'authenticated'
);

-- 4. Autoriser suppression (auth users)
drop policy if exists "Authenticated delete product images" on storage.objects;
create policy "Authenticated delete product images"
on storage.objects for delete
using (
  bucket_id = 'product-images'
  and auth.role() = 'authenticated'
);

-- 5. Ajouter la colonne image_path à la table products
alter table products 
add column if not exists image_path text;
