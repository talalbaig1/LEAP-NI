-- 029_people_source_type_contact
-- Telegram shared contact + .vcf provenance. No backfill.
-- Phase 6 embeddings was never applied (027/028 used for follow_ups).
-- Embeddings moves to 030.

ALTER TABLE public.people
  DROP CONSTRAINT IF EXISTS people_source_type_check;

ALTER TABLE public.people
  ADD CONSTRAINT people_source_type_check
  CHECK (
    source_type IS NULL
    OR source_type = ANY (ARRAY[
      'card'::text,
      'voice_note'::text,
      'typed_note'::text,
      'photo'::text,
      'enrichment'::text,
      'shared_contact'::text,
      'vcard'::text
    ])
  );

ALTER TABLE public.assets
  DROP CONSTRAINT IF EXISTS assets_kind_check;

ALTER TABLE public.assets
  ADD CONSTRAINT assets_kind_check
  CHECK (
    kind = ANY (ARRAY[
      'business_card'::text,
      'audio'::text,
      'photo'::text,
      'selfie'::text,
      'document'::text,
      'vcard'::text
    ])
  );
