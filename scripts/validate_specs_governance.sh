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

# Ash UI uses SCN (Scenario) entries, not AC entries
KNOWN_SCENARIOS="$(rg -o 'SCN-[0-9]+' "$SCENARIO_CATALOG" | sort -u || true)"

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
done

echo "Checking topology.md..."
if [[ ! -f "specs/topology.md" ]]; then
  fail "missing topology.md"
fi

echo "Governance validation passed."
exit 0
