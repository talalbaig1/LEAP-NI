#!/usr/bin/env bash
# Fail if a tracked file contains a literal identifier that belongs
# only in gitignored docs/environment.local.md (rules.md rule 25).
# Structural patterns — this file must not itself contain live ids.
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

scan "uuid" '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
scan "webhook path" '/webhook/[A-Za-z0-9_-]+'
scan "n8n host" 'vmi[0-9]+|contaboserver\.net'
scan "supabase project URL" '[a-z0-9]+\.supabase\.co'
scan "supabase pooler host" 'pooler\.supabase\.com'

if [[ "$fail" -ne 0 ]]; then
  echo "rule 25: literals belong in gitignored docs/environment.local.md"
  echo "tokens look like <OWNER_ID>, <WF01_ID>, <CONTACT_1_EMAIL>"
  exit 1
fi

echo "rule 25 check: clean"
exit 0
