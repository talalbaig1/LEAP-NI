-- 019_lni_normalize_domain
-- Public-suffix table + eTLD+1 function. Not a Code node.
-- Required: jccs.com.sa stays intact; sa.qatarairways.com -> qatarairways.com.

create table if not exists public.lni_public_suffixes (
  suffix text primary key
);

alter table public.lni_public_suffixes enable row level security;

drop policy if exists lni_public_suffixes_select on public.lni_public_suffixes;
create policy lni_public_suffixes_select on public.lni_public_suffixes
  for select to authenticated
  using (true);

insert into public.lni_public_suffixes (suffix) values
  ('com'),
  ('net'),
  ('org'),
  ('io'),
  ('ai'),
  ('co'),
  ('com.sa'),
  ('net.sa'),
  ('org.sa'),
  ('gov.sa'),
  ('edu.sa'),
  ('com.qa'),
  ('com.ae'),
  ('co.uk')
on conflict (suffix) do nothing;

create or replace function public.lni_normalize_domain(raw text)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  host text;
  labels text[];
  n integer;
  i integer;
  candidate text;
  matched_len integer := 0;
  suffix_labels integer;
begin
  if raw is null then
    return null;
  end if;

  host := lower(btrim(raw));
  host := regexp_replace(host, '^[a-z][a-z0-9+.-]*://', '');
  host := regexp_replace(host, '^[^/@]+@', '');
  host := regexp_replace(host, '[/?#].*$', '');
  host := regexp_replace(host, ':[0-9]+$', '');
  host := regexp_replace(host, '\.+$', '');
  host := regexp_replace(host, '^\.+', '');
  host := btrim(host);

  if host = '' then
    return null;
  end if;

  labels := string_to_array(host, '.');
  n := coalesce(array_length(labels, 1), 0);
  if n = 0 then
    return null;
  end if;

  for i in 1..n loop
    candidate := array_to_string(labels[i:n], '.');
    if exists (
      select 1 from public.lni_public_suffixes s where s.suffix = candidate
    ) then
      if (n - i + 1) > matched_len then
        matched_len := n - i + 1;
      end if;
    end if;
  end loop;

  if matched_len = 0 then
    return host;
  end if;

  suffix_labels := matched_len;
  if n <= suffix_labels then
    return host;
  end if;

  return array_to_string(labels[(n - suffix_labels):n], '.');
end;
$$;
