#!/bin/bash
# validate_guides_governance.sh
# Validates Ash UI guide governance compliance

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
GUIDES_DIR="$PROJECT_ROOT/guides"

echo "================================"
echo "Ash UI Guides Governance Validator"
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

# Check 1: Verify guide directory structure
echo "Checking guide directory structure..."
GUIDE_DIRS=(
    "$GUIDES_DIR/user"
    "$GUIDES_DIR/developer"
    "$GUIDES_DIR/contracts"
    "$GUIDES_DIR/conformance"
    "$GUIDES_DIR/templates"
)

for dir in "${GUIDE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        success "Directory exists: $(basename "$dir")/"
    else
        error "Directory missing: $dir"
    fi
done
echo ""

# Check 2: Verify guide contract files exist
echo "Checking guide contracts..."
CONTRACT_FILES=(
    "$GUIDES_DIR/contracts/guide_contract.md"
    "$GUIDES_DIR/contracts/guide_traceability_contract.md"
)

for file in "${CONTRACT_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "Contract exists: $(basename "$file")"
    else
        error "Contract missing: $file"
    fi
done
echo ""

# Check 3: Verify guide conformance files exist
echo "Checking guide conformance files..."
CONFORMANCE_FILES=(
    "$GUIDES_DIR/conformance/guide_conformance_matrix.md"
    "$GUIDES_DIR/conformance/guide_scenario_catalog.md"
)

for file in "${CONFORMANCE_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "Conformance file exists: $(basename "$file")"
    else
        error "Conformance file missing: $file"
    fi
done
echo ""

# Check 4: Verify template files exist
echo "Checking guide templates..."
TEMPLATE_FILES=(
    "$GUIDES_DIR/templates/user-guide-template.md"
    "$GUIDES_DIR/templates/developer-guide-template.md"
)

for file in "${TEMPLATE_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "Template exists: $(basename "$file")"
    else
        error "Template missing: $file"
    fi
done
echo ""

# Check 5: Validate individual user guides
echo "Validating user guides..."
UG_COUNT=0
for guide in "$GUIDES_DIR/user"/UG-*.md; do
    if [ -f "$guide" ]; then
        ((UG_COUNT++))
        guide_name=$(basename "$guide")
        success "Found user guide: $guide_name"

        # Check for required metadata
        if grep -qE "^id: UG-" "$guide"; then
            success "  $guide_name has id field"
        else
            error "  $guide_name missing id field"
        fi

        if grep -qE "^audience:" "$guide"; then
            success "  $guide_name has audience field"
        else
            error "  $guide_name missing audience field"
        fi

        if grep -qE "^status:" "$guide"; then
            success "  $guide_name has status field"
        else
            error "  $guide_name missing status field"
        fi

        if grep -qE "^related_reqs:" "$guide"; then
            success "  $guide_name has related_reqs field"
        else
            warning "  $guide_name should have related_reqs field"
        fi

        if grep -qE "^related_scns:" "$guide"; then
            success "  $guide_name has related_scns field"
        else
            warning "  $guide_name should have related_scns field"
        fi
    fi
done

if [ "$UG_COUNT" -eq 0 ]; then
    warning "No user guides found"
else
    success "Total user guides found: $UG_COUNT"
fi
echo ""

# Check 6: Validate individual developer guides
echo "Validating developer guides..."
DG_COUNT=0
for guide in "$GUIDES_DIR/developer"/DG-*.md; do
    if [ -f "$guide" ]; then
        ((DG_COUNT++))
        guide_name=$(basename "$guide")
        success "Found developer guide: $guide_name"

        # Check for required metadata
        if grep -qE "^id: DG-" "$guide"; then
            success "  $guide_name has id field"
        else
            error "  $guide_name missing id field"
        fi

        if grep -qE "^audience:" "$guide"; then
            success "  $guide_name has audience field"
        else
            error "  $guide_name missing audience field"
        fi
    fi
done

if [ "$DG_COUNT" -eq 0 ]; then
    warning "No developer guides found"
else
    success "Total developer guides found: $DG_COUNT"
fi
echo ""

# Check 7: Verify README files exist
echo "Checking README files..."
README_FILES=(
    "$GUIDES_DIR/README.md"
    "$GUIDES_DIR/user/README.md"
    "$GUIDES_DIR/developer/README.md"
)

for file in "${README_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "README exists: $(basename "$file")"
    else
        error "README missing: $file"
    fi
done
echo ""

# Check 8: Verify guide conformance matrix is updated
echo "Checking guide conformance matrix..."
if [ -f "$GUIDES_DIR/conformance/guide_conformance_matrix.md" ]; then
    # Check if UG-0001 and DG-0001 are listed
    if grep -q "UG-0001" "$GUIDES_DIR/conformance/guide_conformance_matrix.md"; then
        success "Conformance matrix includes UG-0001"
    else
        warning "Conformance matrix should include UG-0001"
    fi

    if grep -q "DG-0001" "$GUIDES_DIR/conformance/guide_conformance_matrix.md"; then
        success "Conformance matrix includes DG-0001"
    else
        warning "Conformance matrix should include DG-0001"
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
    success "All guides governance checks passed!"
    exit 0
else
    error "Guides governance validation failed!"
    exit 1
fi
