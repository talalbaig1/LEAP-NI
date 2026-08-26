CREATE UNIQUE INDEX captures_owner_media_group_uniq
  ON public.captures (owner_id, (flags->>'media_group_id'))
  WHERE flags ? 'media_group_id';

COMMENT ON INDEX public.captures_owner_media_group_uniq IS
  'Makes concurrent album-member arrivals deterministic: the first member
   creates the group capture, later members lose the INSERT race and
   re-select the winner. Partial, so non-album captures are unaffected.';
