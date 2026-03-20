#!/usr/bin/env bash
set -euo pipefail

ROOT="${GUIDES_GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

failures=0
KNOWN_REQS="$(rg --no-filename -o 'REQ-[A-Z]+-[0-9A-Z]+' specs rfcs 2>/dev/null | sort -u || true)"
KNOWN_SCNS="$(rg --no-filename -o 'SCN-[0-9A-Z]+' specs/conformance/scenario_catalog.md 2>/dev/null | sort -u || true)"

fail() {
  echo "FAIL: $1"
  failures=1
}

extract_front_matter() {
  local file="$1"
  awk '
    BEGIN {in_block=0}
    /^---$/ {
      if (in_block == 0) {
        in_block=1
        next
      }

      exit
    }
    in_block == 1 { print }
  ' "$file"
}

echo "Checking guide directory structure..."
required_dirs=(
  "guides/user"
  "guides/developer"
  "guides/contracts"
  "guides/conformance"
  "guides/templates"
)
for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    fail "missing required directory: $dir"
  fi
done

echo "Checking guide contracts exist..."
required_contract_files=(
  "guides/contracts/guide_contract.md"
  "guides/contracts/guide_traceability_contract.md"
)
for file in "${required_contract_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing required file: $file"
  fi
done

echo "Checking guide templates exist..."
required_templates=(
  "guides/templates/user-guide-template.md"
  "guides/templates/developer-guide-template.md"
)
for file in "${required_templates[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing required template: $file"
  fi
done

echo "Checking guide conformance matrix exists..."
if [[ ! -f "guides/conformance/guide_conformance_matrix.md" ]]; then
  fail "missing guide conformance matrix"
fi

echo "Checking individual guides..."
while IFS= read -r guide; do
  [[ -z "$guide" ]] && continue
  guide_name="$(basename "$guide")"
  front_matter="$(extract_front_matter "$guide")"

  if [[ -z "$front_matter" ]]; then
    fail "guide missing front matter: $guide_name"
    continue
  fi

  required_metadata=(
    '^id: '
    '^title: '
    '^audience: '
    '^status: '
    '^owners: '
    '^last_reviewed: '
    '^next_review: '
    '^related_reqs: '
    '^related_scns: '
    '^related_guides: '
    '^diagram_required: '
  )

  for field in "${required_metadata[@]}"; do
    if ! grep -Eq "$field" <<<"$front_matter"; then
      fail "guide missing metadata field ($field): $guide_name"
    fi
  done

  required_sections=(
    '^## Overview$'
    '^## Prerequisites$'
    '^## See Also$'
  )

  for section in "${required_sections[@]}"; do
    if ! rg -q "$section" "$guide"; then
      fail "guide missing required section ($section): $guide_name"
    fi
  done

  if grep -Eq '^diagram_required: true$' <<<"$front_matter"; then
    if ! rg -q '^```mermaid$' "$guide"; then
      fail "guide requires a diagram but has no mermaid block: $guide_name"
    fi
  fi

  while IFS= read -r req; do
    [[ -z "$req" ]] && continue
    if ! grep -Fxq "$req" <<<"$KNOWN_REQS"; then
      fail "guide references unknown requirement $req: $guide_name"
    fi
  done < <(grep -Eo 'REQ-[A-Z]+-[0-9A-Z]+' <<<"$front_matter" | sort -u || true)

  while IFS= read -r scn; do
    [[ -z "$scn" ]] && continue
    if ! grep -Fxq "$scn" <<<"$KNOWN_SCNS"; then
      fail "guide references unknown scenario $scn: $guide_name"
    fi
  done < <(grep -Eo 'SCN-[0-9A-Z]+' <<<"$front_matter" | sort -u || true)

  guide_id="$(grep -E '^id: ' <<<"$front_matter" | head -n1 | sed 's/^id: //')"

  if [[ -n "$guide_id" ]]; then
    if ! rg -q "$guide_id" guides/README.md; then
      fail "guide missing from guides/README.md: $guide_id"
    fi

    if ! rg -q "$guide_id" guides/conformance/guide_conformance_matrix.md; then
      fail "guide missing from guide conformance matrix: $guide_id"
    fi
  fi
done < <(find guides/user guides/developer -type f \( -name 'UG-*.md' -o -name 'DG-*.md' \) | sort)

if [[ "$failures" -ne 0 ]]; then
  echo "Guides governance validation failed."
  exit 1
fi

echo "Guides governance validation passed."
exit 0
