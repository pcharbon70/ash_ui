#!/usr/bin/env bash
set -euo pipefail

ROOT="${GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

MATRIX="specs/conformance/spec_conformance_matrix.md"
SCENARIO_CATALOG="specs/conformance/scenario_catalog.md"

failures=0

fail() {
  echo "FAIL: $1"
  failures=1
}

if [[ ! -f "$MATRIX" ]]; then
  echo "ERROR: missing conformance matrix: $MATRIX"
  exit 1
fi

if [[ ! -f "$SCENARIO_CATALOG" ]]; then
  echo "ERROR: missing scenario catalog: $SCENARIO_CATALOG"
  exit 1
fi

KNOWN_REQS="$(rg --no-filename -o 'REQ-[A-Z]+-[0-9A-Z]+' specs rfcs guides 2>/dev/null | sort -u || true)"
KNOWN_SCENARIOS="$(rg --no-filename -o 'SCN-[0-9A-Z]+' "$SCENARIO_CATALOG" | sort -u || true)"

echo "Checking required contract files exist..."
required_contracts=(
  "specs/contracts/resource_contract.md"
  "specs/contracts/screen_contract.md"
  "specs/contracts/binding_contract.md"
  "specs/contracts/compilation_contract.md"
  "specs/contracts/rendering_contract.md"
  "specs/contracts/authorization_contract.md"
  "specs/contracts/observability_contract.md"
  "specs/contracts/control_plane_ownership_matrix.md"
)
for contract in "${required_contracts[@]}"; do
  if [[ ! -f "$contract" ]]; then
    fail "missing required contract: $contract"
  fi
done

echo "Checking ADR-0001 exists..."
if [[ ! -f "specs/adr/ADR-0001-control-plane-authority.md" ]]; then
  fail "missing ADR-0001"
fi

echo "Checking REQ entries in contracts..."
for contract in specs/contracts/*.md; do
  if ! rg -q 'REQ-[A-Z]+-[0-9]+' "$contract"; then
    fail "contract may be missing REQ entries: $contract"
  fi

  if [[ "$contract" != "specs/contracts/control_plane_ownership_matrix.md" ]]; then
    if ! rg -q '^## Traceability$' "$contract"; then
      fail "contract missing Traceability section: $contract"
    fi

    if ! rg -q '^## Conformance$' "$contract"; then
      fail "contract missing Conformance section: $contract"
    fi
  fi
done

echo "Checking topology.md..."
if [[ ! -f "specs/topology.md" ]]; then
  fail "missing topology.md"
fi

echo "Checking planning files..."
for phase in specs/planning/phase-0{1,2,3,4,5,6,7,8}-*.md; do
  if [[ ! -f "$phase" ]]; then
    fail "missing planning phase file: $phase"
  fi
done

echo "Checking matrix REQ references..."
while IFS= read -r req; do
  [[ -z "$req" ]] && continue
  if ! grep -Fxq "$req" <<<"$KNOWN_REQS"; then
    fail "matrix references unknown requirement: $req"
  fi
done < <(rg --no-filename -o 'REQ-[A-Z]+-[0-9A-Z]+' "$MATRIX" | sort -u || true)

echo "Checking matrix SCN references..."
while IFS= read -r scn; do
  [[ -z "$scn" ]] && continue
  if ! grep -Fxq "$scn" <<<"$KNOWN_SCENARIOS"; then
    fail "matrix references unknown scenario: $scn"
  fi
done < <(rg --no-filename -o 'SCN-[0-9A-Z]+' "$MATRIX" | sort -u || true)

if [[ "$failures" -ne 0 ]]; then
  echo "Specs governance validation failed."
  exit 1
fi

echo "Specs governance validation passed."
exit 0
