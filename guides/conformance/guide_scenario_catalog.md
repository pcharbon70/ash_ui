# Guide Scenario Catalog

This document defines scenarios for validating guide content.

## Purpose

Scenarios in this catalog validate that guide documentation is accurate, complete, and matches the actual implementation.

## Guide Validation Scenarios

### GSCN-001: Code Example Executes Successfully

**Purpose**: Validate that all code examples in guides are runnable.

**Steps**:
1. Extract all code blocks from a guide
2. Execute each code example in a test environment
3. Verify output matches documentation

**Expected Outcome**: All code examples run without errors.

### GSCN-002: API Reference Accuracy

**Purpose**: Validate that API references in guides match current code.

**Steps**:
1. Extract all API references from a guide
2. Check against actual module documentation
3. Verify parameter lists and return types

**Expected Outcome**: All API references are accurate.

### GSCN-003: Diagram Consistency

**Purpose**: Validate that diagrams match actual architecture.

**Steps**:
1. Extract all Mermaid diagrams from a guide
2. Compare diagram structure to code
3. Verify component relationships

**Expected Outcome**: Diagrams accurately represent the system.

### GSCN-004: Link Integrity

**Purpose**: Validate that all internal and external links work.

**Steps**:
1. Extract all links from a guide
2. Check internal links to specs/guides
3. Check external links to external resources

**Expected Outcome**: All links resolve correctly.

### GSCN-005: Requirement Coverage

**Purpose**: Validate that all claimed requirements are documented.

**Steps**:
1. Extract `related_reqs` from guide metadata
2. Check each REQ-* is mentioned in the guide
3. Verify content matches requirement description

**Expected Outcome**: All listed requirements are properly covered.

## Scenario Index

| GSCN ID | Title | Target | Automation |
|---|---|---|---|
| GSCN-001 | Code Example Executes | All guides | Automated |
| GSCN-002 | API Reference Accuracy | All guides | Semi-automated |
| GSCN-003 | Diagram Consistency | All guides | Manual |
| GSCN-004 | Link Integrity | All guides | Automated |
| GSCN-005 | Requirement Coverage | All guides | Automated |

## Running Guide Validation

```bash
# Run all guide validation scenarios
./scripts/validate_guides_governance.sh

# Run specific scenario
./scripts/validate_guides_governance.sh --scenario GSCN-001

# Validate specific guide
./scripts/validate_guides_governance.sh --guide UG-0001
```

## Related Documents

- [../contracts/guide_contract.md](../contracts/guide_contract.md)
- [guide_conformance_matrix.md](guide_conformance_matrix.md)
- [../../specs/conformance/scenario_catalog.md](../../specs/conformance/scenario_catalog.md)
