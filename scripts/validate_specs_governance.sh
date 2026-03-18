#!/bin/bash
# validate_specs_governance.sh
# Validates Ash UI specification governance compliance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for errors
ERRORS=0
WARNINGS=0

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPECS_DIR="$PROJECT_ROOT/specs"

echo "================================"
echo "Ash UI Specs Governance Validator"
echo "================================"
echo ""

# Function to print error
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

# Function to print warning
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS++))
}

# Function to print success
success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Check 1: Verify all contract files exist
echo "Checking contract files..."
CONTRACTS=(
    "$SPECS_DIR/contracts/control_plane_ownership_matrix.md"
    "$SPECS_DIR/contracts/resource_contract.md"
    "$SPECS_DIR/contracts/screen_contract.md"
    "$SPECS_DIR/contracts/binding_contract.md"
    "$SPECS_DIR/contracts/compilation_contract.md"
    "$SPECS_DIR/contracts/rendering_contract.md"
    "$SPECS_DIR/contracts/authorization_contract.md"
    "$SPECS_DIR/contracts/observability_contract.md"
)

for contract in "${CONTRACTS[@]}"; do
    if [ -f "$contract" ]; then
        success "Contract exists: $(basename "$contract")"
    else
        error "Contract missing: $contract"
    fi
done
echo ""

# Check 2: Verify ADR-0001 exists
echo "Checking ADR files..."
if [ -f "$SPECS_DIR/adr/ADR-0001-control-plane-authority.md" ]; then
    success "ADR-0001 exists"
else
    error "ADR-0001 is missing"
fi
echo ""

# Check 3: Verify conformance files exist
echo "Checking conformance files..."
CONFORMANCE_FILES=(
    "$SPECS_DIR/conformance/spec_conformance_matrix.md"
    "$SPECS_DIR/conformance/scenario_catalog.md"
)

for file in "${CONFORMANCE_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "Conformance file exists: $(basename "$file")"
    else
        error "Conformance file missing: $file"
    fi
done
echo ""

# Check 4: Verify all contracts have valid REQ- entries
echo "Checking requirement format..."
for contract in "$SPECS_DIR"/contracts/*.md; do
    if [ -f "$contract" ]; then
        # Check for REQ- pattern
        if grep -qE "REQ-[A-Z]+-[0-9]+" "$contract"; then
            success "$(basename "$contract") has valid REQ- entries"
        else
            warning "$(basename "$contract") may be missing REQ- entries"
        fi
    fi
done
echo ""

# Check 5: Verify topology.md exists
echo "Checking topology..."
if [ -f "$SPECS_DIR/topology.md" ]; then
    success "topology.md exists"
    # Check for Mermaid diagrams
    if grep -q '```mermaid' "$SPECS_DIR/topology.md"; then
        success "topology.md includes Mermaid diagrams"
    else
        warning "topology.md should include Mermaid diagrams"
    fi
else
    error "topology.md is missing"
fi
echo ""

# Check 6: Verify README files
echo "Checking README files..."
README_DIRS=(
    "$SPECS_DIR"
    "$SPECS_DIR/resources"
    "$SPECS_DIR/compilation"
    "$SPECS_DIR/rendering"
)

for dir in "${README_DIRS[@]}"; do
    if [ -f "$dir/README.md" ]; then
        success "README exists in $(basename "$dir")/"
    else
        warning "Missing README in $dir/"
    fi
done
echo ""

# Check 7: Verify contract references in conformance matrix
echo "Checking conformance matrix completeness..."
if [ -f "$SPECS_DIR/conformance/spec_conformance_matrix.md" ]; then
    # Check for contract references
    CONTRACT_REFS=(
        "resource_contract.md"
        "screen_contract.md"
        "binding_contract.md"
        "compilation_contract.md"
        "rendering_contract.md"
        "authorization_contract.md"
        "observability_contract.md"
    )

    for ref in "${CONTRACT_REFS[@]}"; do
        if grep -q "$ref" "$SPECS_DIR/conformance/spec_conformance_matrix.md"; then
            success "Conformance matrix references $ref"
        else
            warning "Conformance matrix may be missing reference to $ref"
        fi
    done
fi
echo ""

# Check 8: Verify scenario catalog has SCN- entries
echo "Checking scenario catalog..."
if [ -f "$SPECS_DIR/conformance/scenario_catalog.md" ]; then
    SCN_COUNT=$(grep -c "SCN-[0-9]" "$SPECS_DIR/conformance/scenario_catalog.md" || true)
    if [ "$SCN_COUNT" -gt 0 ]; then
        success "Scenario catalog has $SCN_COUNT SCN- entries"
    else
        warning "Scenario catalog may be missing SCN- entries"
    fi
fi
echo ""

# Summary
echo "================================"
echo "Validation Summary"
echo "================================"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    success "All specs governance checks passed!"
    exit 0
else
    error "Specs governance validation failed!"
    exit 1
fi
