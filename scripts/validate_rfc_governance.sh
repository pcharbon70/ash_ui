#!/bin/bash
# validate_rfc_governance.sh
# Validates Ash UI RFC governance compliance

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
RFC_DIR="$PROJECT_ROOT/rfcs"

echo "================================"
echo "Ash UI RFC Governance Validator"
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

# Check 1: Verify RFC directory structure
echo "Checking RFC directory structure..."
RFC_DIRS=(
    "$RFC_DIR"
    "$RFC_DIR/templates"
)

for dir in "${RFC_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        success "Directory exists: $(basename "$dir")/"
    else
        error "Directory missing: $dir"
    fi
done
echo ""

# Check 2: Verify RFC metadata files exist
echo "Checking RFC metadata files..."
RFC_META_FILES=(
    "$RFC_DIR/README.md"
    "$RFC_DIR/index.md"
    "$RFC_DIR/getting-started.md"
)

for file in "${RFC_META_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "Metadata file exists: $(basename "$file")"
    else
        error "Metadata file missing: $file"
    fi
done
echo ""

# Check 3: Verify RFC template exists
echo "Checking RFC template..."
if [ -f "$RFC_DIR/templates/rfc-template.md" ]; then
    success "RFC template exists"
    # Check for required template sections
    REQUIRED_SECTIONS=(
        "Status"
        "Summary"
        "Motivation"
        "Proposed Design"
        "Governance Mapping"
        "Alternatives"
    )

    for section in "${REQUIRED_SECTIONS[@]}"; do
        if grep -q "$section" "$RFC_DIR/templates/rfc-template.md"; then
            success "Template has section: $section"
        else
            warning "Template may be missing section: $section"
        fi
    done
else
    error "RFC template is missing"
fi
echo ""

# Check 4: Validate all RFC files
echo "Validating RFC files..."
RFC_COUNT=0
for rfc in "$RFC_DIR"/RFC-*.md; do
    if [ -f "$rfc" ]; then
        ((RFC_COUNT++))
        rfc_name=$(basename "$rfc")
        success "Found RFC: $rfc_name"

        # Check for required metadata
        if grep -qE "^\\*\\*Status\\*\\*:" "$rfc"; then
            success "  $rfc_name has Status field"
        else
            error "  $rfc_name missing Status field"
        fi

        if grep -qE "^\\*\\*Phase\\*\\*:" "$rfc"; then
            success "  $rfc_name has Phase field"
        else
            warning "  $rfc_name missing Phase field"
        fi

        if grep -qE "^## Summary" "$rfc"; then
            success "  $rfc_name has Summary section"
        else
            error "  $rfc_name missing Summary section"
        fi

        # Check for governance mapping section
        if grep -qE "^## Governance Mapping" "$rfc"; then
            success "  $rfc_name has Governance Mapping"
        else
            warning "  $rfc_name should have Governance Mapping"
        fi
    fi
done

if [ "$RFC_COUNT" -eq 0 ]; then
    warning "No RFC files found (except RFC-0001 template)"
else
    success "Total RFC files found: $RFC_COUNT"
fi
echo ""

# Check 5: Verify RFC index is up to date
echo "Checking RFC index..."
if [ -f "$RFC_DIR/index.md" ]; then
    # Count RFCs in index vs actual RFC files
    INDEX_COUNT=$(grep -c "RFC-" "$RFC_DIR/index.md" || true)
    # Subtract 1 for the header row if present
    if [ "$INDEX_COUNT" -gt 0 ]; then
        ((INDEX_COUNT--))
    fi

    if [ "$RFC_COUNT" -eq "$INDEX_COUNT" ]; then
        success "RFC index is up to date ($RFC_COUNT RFCs)"
    elif [ "$RFC_COUNT" -gt "$INDEX_COUNT" ]; then
        warning "RFC index may be missing entries (has $INDEX_COUNT, found $RFC_COUNT)"
    else
        warning "RFC index may have extra entries (has $INDEX_COUNT, found $RFC_COUNT)"
    fi
fi
echo ""

# Check 6: Verify RFC numbers are sequential (optional check)
echo "Checking RFC numbering..."
if [ "$RFC_COUNT" -gt 1 ]; then
    # Extract RFC numbers
    RFC_NUMBERS=$(find "$RFC_DIR" -name "RFC-*.md" -exec basename {} \; | sed 's/RFC-\([0-9]*\).*/\1/' | sort -n)
    EXPECTED_NUMBER=1

    for number in $RFC_NUMBERS; do
        if [ "$number" != "$EXPECTED_NUMBER" ]; then
            warning "RFC numbering gap: expected RFC-$EXPECTED_NUMBER, found RFC-$number"
        fi
        ((EXPECTED_NUMBER++))
    done
fi
echo ""

# Check 7: Verify README exists in RFC directory
echo "Checking RFC README..."
if [ -f "$RFC_DIR/README.md" ]; then
    success "RFC README exists"
    if grep -q "RFC Lifecycle" "$RFC_DIR/README.md"; then
        success "README includes lifecycle information"
    fi
else
    error "RFC README is missing"
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
    success "All RFC governance checks passed!"
    exit 0
else
    error "RFC governance validation failed!"
    exit 1
fi
