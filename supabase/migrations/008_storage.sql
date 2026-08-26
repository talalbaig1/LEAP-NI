-- 008_storage
-- Private bucket. Path first segment is owner_id (architecture.md §5).

insert into storage.buckets (id, name, public)
values ('lni-assets', 'lni-assets', false)
on conflict (id) do update set
  public = excluded.public,
  name = excluded.name;

drop policy if exists lni_assets_owner_all on storage.objects;
create policy lni_assets_owner_all
  on storage.objects
  for all
  to authenticated
  using (
    bucket_id = 'lni-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'lni-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
