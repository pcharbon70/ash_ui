#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/gen_specs_from_rfc.sh --rfc <rfcs/RFC-XXXX-title.md> [--dry-run] [--overwrite]

Options:
  --rfc <path>   Path to RFC markdown file.
  --dry-run      Print planned file writes without creating files.
  --overwrite    Overwrite existing target files for create rows.
USAGE
}

trim() {
  echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

titleize() {
  echo "$1" \
    | tr '_' ' ' \
    | tr '-' ' ' \
    | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}; print}'
}

relative_prefix_to_specs_root() {
  local spec_path="$1"
  local dir rel up i

  dir="$(dirname "$spec_path")"
  rel="${dir#specs}"
  rel="${rel#/}"

  if [[ -z "$rel" ]]; then
    echo "."
    return
  fi

  IFS='/' read -r -a parts <<< "$rel"
  up=".."
  for ((i=1; i<${#parts[@]}; i++)); do
    up="$up/.."
  done

  echo "$up"
}

ROOT="${RFC_GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

RFC_PATH=""
DRY_RUN=0
OVERWRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rfc)
      RFC_PATH="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$RFC_PATH" ]]; then
  echo "ERROR: --rfc is required"
  usage
  exit 1
fi

if [[ ! -f "$RFC_PATH" ]]; then
  echo "ERROR: RFC file not found: $RFC_PATH"
  exit 1
fi

if ! rg -q '^## Spec Creation Plan$' "$RFC_PATH"; then
  echo "ERROR: RFC is missing '## Spec Creation Plan' section: $RFC_PATH"
  exit 1
fi

RFC_ID="$(rg -o '^- RFC ID: `RFC-[0-9]{4}`$' "$RFC_PATH" | head -n1 | sed -E 's/.*`(RFC-[0-9]{4})`.*/\1/' || true)"
if [[ -z "$RFC_ID" ]]; then
  RFC_ID="$(basename "$RFC_PATH" | sed -E 's/^(RFC-[0-9]{4})-.+$/\1/')"
fi

RFC_PATH_REL="$RFC_PATH"
if [[ "$RFC_PATH" == "$ROOT"/* ]]; then
  RFC_PATH_REL="${RFC_PATH#$ROOT/}"
fi

CONTRACT_REFS="$(rg -o 'specs/contracts/[a-z0-9_]+\.md' "$RFC_PATH" | sort -u || true)"

PLAN_BLOCK="$(awk '/^## Spec Creation Plan/{flag=1;next}/^## /{if(flag)exit}flag' "$RFC_PATH")"
if [[ -z "$PLAN_BLOCK" ]]; then
  echo "ERROR: empty Spec Creation Plan in $RFC_PATH"
  exit 1
fi

rows_seen=0
create_rows=0
created=0
skipped=0
errors=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == \|* ]] || continue

  if echo "$line" | rg -q '^\|[[:space:]]*Action[[:space:]]*\|'; then
    continue
  fi

  if ! echo "$line" | rg -q '[A-Za-z0-9]'; then
    continue
  fi

  rows_seen=$((rows_seen + 1))

  IFS='|' read -r _ action spec_path component_title control_plane req_cell scn_cell ac_cell _ <<< "$line"

  action="$(trim "$action" | tr '[:upper:]' '[:lower:]')"
  spec_path="$(trim "$spec_path")"
  component_title="$(trim "$component_title")"
  control_plane="$(trim "$control_plane")"
  req_cell="$(trim "$req_cell")"
  scn_cell="$(trim "$scn_cell")"
  ac_cell="$(trim "$ac_cell")"

  if [[ "$action" != "create" ]]; then
    echo "INFO: skipping non-create action '$action' for $spec_path"
    continue
  fi

  create_rows=$((create_rows + 1))

  if ! echo "$spec_path" | rg -q '^specs/.+\.md$'; then
    echo "ERROR: invalid spec path '$spec_path' (must match specs/*.md)"
    errors=$((errors + 1))
    continue
  fi

  if [[ -z "$component_title" ]]; then
    component_title="$(titleize "$(basename "$spec_path" .md)")"
  fi

  if [[ -f "$spec_path" && "$OVERWRITE" -eq 0 ]]; then
    echo "SKIP: $spec_path already exists (use --overwrite to replace)"
    skipped=$((skipped + 1))
    continue
  fi

  up="$(relative_prefix_to_specs_root "$spec_path")"
  repo_root_prefix="$up/.."
  control_plane_contract_link="$up/contracts/control_plane_ownership_matrix.md"
  adr_link="$up/adr/ADR-0001-control-plane-authority.md"
  topology_link="$up/topology.md"
  rfc_link="$repo_root_prefix/$RFC_PATH_REL"

  req_tokens="$(echo "$req_cell" | rg -o 'REQ-[A-Z]+(?:-[0-9]{3}|-\*)?' | awk '!seen[$0]++' || true)"
  scn_tokens="$(echo "$scn_cell" | rg -o 'SCN-[0-9]+' | awk '!seen[$0]++' || true)"
  ac_tokens="$(echo "$ac_cell" | rg -o 'AC-[0-9]{2}' | awk '!seen[$0]++' || true)"

  if [[ -z "$ac_tokens" ]]; then
    ac_tokens="AC-01"
  fi

  req_lines=""
  while IFS= read -r req; do
    [[ -z "$req" ]] && continue
    req_lines+="- \`$req\`"$'\n'
  done <<< "$req_tokens"

  scn_lines=""
  while IFS= read -r scn; do
    [[ -z "$scn" ]] && continue
    scn_lines+="- \`$scn\`"$'\n'
  done <<< "$scn_tokens"

  ac_rows=""
  while IFS= read -r ac; do
    [[ -z "$ac" ]] && continue
    ac_rows+="| \`$ac\` | TODO: define criterion from $RFC_ID. | TODO: add deterministic verification mapped to required SCN coverage. |"$'\n'
  done <<< "$ac_tokens"

  contract_lines=""
  while IFS= read -r contract_ref; do
    [[ -z "$contract_ref" ]] && continue
    contract_file="$(basename "$contract_ref")"
    contract_lines+="- [$contract_file]($up/contracts/$contract_file)"$'\n'
  done <<< "$CONTRACT_REFS"

  if [[ -z "$contract_lines" ]]; then
    contract_lines+="- [control_plane_ownership_matrix.md]($control_plane_contract_link)"$'\n'
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY RUN: would write $spec_path"
    continue
  fi

  mkdir -p "$(dirname "$spec_path")"

  cat > "$spec_path" <<EOF_SPEC
# $component_title

## Purpose

\`$component_title\` is introduced by [$RFC_ID]($rfc_link) and defines runtime behavior for this component surface.

## Control Plane

Primary control-plane ownership: **$control_plane**.

## Topology Context

- [Topology]($topology_link)

## Governance Mapping

### Requirement Families

$req_lines
### Scenario Coverage

$scn_lines
### Source RFC

- [$RFC_ID]($rfc_link)

## Acceptance Criteria

| Acceptance ID (AC-XX) | Criterion | Verification |
|---|---|---|
$ac_rows
## Normative Contracts

$contract_lines
## Control Plane ADR

- [ADR-0001-control-plane-authority.md]($adr_link)
EOF_SPEC

  created=$((created + 1))
  echo "CREATED: $spec_path"
done <<< "$PLAN_BLOCK"

if [[ "$rows_seen" -eq 0 ]]; then
  echo "ERROR: no table rows found under Spec Creation Plan in $RFC_PATH"
  exit 1
fi

if [[ "$errors" -ne 0 ]]; then
  echo ""
  echo "Spec generation failed with $errors validation error(s)."
  exit 1
fi

echo ""
echo "Processed RFC: $RFC_PATH"
echo "Plan rows: $rows_seen"
echo "Create rows: $create_rows"
echo "Created: $created"
echo "Skipped existing: $skipped"
