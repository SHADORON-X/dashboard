-- ================================================================
-- MIGRATION: Create daily-reports bucket
-- Date: 2026-01-04
-- Description: Bucket pour stocker les rapports PDF/Images journaliers
-- ================================================================

insert into storage.buckets (id, name, public)
values ('daily-reports', 'daily-reports', true)
on conflict (id) do nothing;

-- Policies
create policy "Public read daily reports"
on storage.objects for select
using (bucket_id = 'daily-reports');

create policy "Authenticated upload daily reports"
on storage.objects for insert
with check (
  bucket_id = 'daily-reports'
  and auth.role() = 'authenticated'
);

create policy "Authenticated delete daily reports"
on storage.objects for delete
using (
  bucket_id = 'daily-reports'
  and auth.role() = 'authenticated'
);
