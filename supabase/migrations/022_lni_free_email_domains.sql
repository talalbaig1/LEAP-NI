-- 022_lni_free_email_domains.sql
-- Packet 4.2. A free-mail domain is never treated as a company domain.
-- Stored as a table (not a Code node array) for the same reason the suffix
-- list is a table: live updates without a workflow edit.
-- A person on a free-mail domain is still person-enriched by email.
-- Only the company-derivation step is skipped.

CREATE TABLE public.lni_free_email_domains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  domain text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (owner_id, domain)
);

ALTER TABLE public.lni_free_email_domains ENABLE ROW LEVEL SECURITY;

CREATE POLICY lni_free_email_domains_owner_all
  ON public.lni_free_email_domains
  FOR ALL
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

INSERT INTO public.lni_free_email_domains (owner_id, domain)
SELECT e.owner_id, d.domain
FROM public.events e
CROSS JOIN (
  VALUES
    ('gmail.com'),
    ('googlemail.com'),
    ('hotmail.com'),
    ('outlook.com'),
    ('live.com'),
    ('yahoo.com'),
    ('icloud.com'),
    ('me.com'),
    ('aol.com'),
    ('proton.me'),
    ('protonmail.com'),
    ('qq.com'),
    ('163.com'),
    ('mail.ru'),
    ('yandex.ru')
) AS d(domain)
WHERE e.name = 'LEAP 2026'
ON CONFLICT (owner_id, domain) DO NOTHING;

COMMENT ON TABLE public.lni_free_email_domains IS
  'Free-mail domains that must never be treated as a company domain. Person enrichment by email still runs; company derivation from the same Apollo response is skipped.';
