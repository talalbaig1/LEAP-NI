#!/usr/bin/env bash
# Fail if a tracked file contains a banned identity / infrastructure
# literal (rules.md rule 25). Structural patterns only — this file
# must not itself contain live ids, names, or domains.
#
# Banned (CI): email, webhook path, n8n host, supabase project URL,
# pooler host.
# Allowed: row-level uuids (people / captures / assets / follow_ups /
# jobs / ledger / entity_candidates / extraction_runs), 8-char prefixes
# of those, n8n execution ids, Gmail draft/message ids.
#
# Names, company domains, workflow ids, credential ids live in the
# gitignored replace-text map. CI cannot list them without re-leaking.
# Optional local extra: CHECK_SCRUB_MAP=1 (uses docs/scrub-map.local.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

scan() {
  local title="$1" regex="$2"
  local hits
  hits="$(git grep -nI -E "$regex" -- . 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    echo "FAIL [$title]"
    echo "$hits"
    echo
    fail=1
  fi
}

email_hits="$(git grep -nI -E '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- . 2>/dev/null || true)"
if [[ -n "$email_hits" ]]; then
  filtered="$(printf '%s\n' "$email_hits" | grep -vE '@(example\.com|example\.invalid|users\.noreply\.github\.com)|@lni-probe-[A-Za-z0-9]+\.example' || true)"
  if [[ -n "$filtered" ]]; then
    echo "FAIL [email]"
    echo "$filtered"
    echo
    fail=1
  fi
fi

scan "webhook path" '/webhook/[A-Za-z0-9_-]+'
scan "n8n host" 'vmi[0-9]+|contaboserver\.net'
scan "supabase project URL" '[a-z0-9]+\.supabase\.co'
scan "supabase pooler host" 'pooler\.supabase\.com'

if [[ "${CHECK_SCRUB_MAP:-}" == "1" && -f docs/scrub-map.local.md ]]; then
  map_hits=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \#* || -z "$line" ]] && continue
    lit="${line%%==>*}"
    [[ -z "$lit" || "$lit" == "$line" ]] && continue
    hit="$(git grep -nIF -- "$lit" -- . 2>/dev/null || true)"
    if [[ -n "$hit" ]]; then
      map_hits+="$hit"$'\n'
    fi
  done < docs/scrub-map.local.md
  if [[ -n "$map_hits" ]]; then
    echo "FAIL [scrub-map leftover]"
    printf '%s' "$map_hits"
    echo
    fail=1
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "rule 25: identity/infrastructure literals belong in gitignored docs/environment.local.md"
  echo "tokens look like <OWNER_ID>, <WF01_ID>, <CONTACT_1_EMAIL>, <CONTACT_1_NAME>"
  exit 1
fi

echo "rule 25 check: clean"
exit 0
