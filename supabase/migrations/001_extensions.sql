-- 001_extensions
-- pg_trgm must exist before any trigram index (architecture.md §4).

create extension if not exists pg_trgm;
