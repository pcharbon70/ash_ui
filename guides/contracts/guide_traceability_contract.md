# Guide Traceability Contract

This contract defines how guides trace back to specifications and scenarios.

## Traceability Chain

```
RFC → Requirements (REQ-*) → Scenarios (SCN-*) → Component Specs → Guides (UG-*/DG-*)
```

## Traceability Requirements

### 1. Forward Traceability (Spec → Guide)

Each requirement (REQ-*) must be documented in at least one guide.

**Mapping**:
- `REQ-RES-*` → UG guides on resource definitions
- `REQ-SCREEN-*` → UG guides on screen usage
- `REQ-BIND-*` → UG guides on data binding
- `REQ-COMP-*` → DG guides on compilation
- `REQ-RENDER-*` → DG guides on rendering
- `REQ-AUTH-*` → UG guides on authorization
- `REQ-OBS-*` → DG guides on observability

### 2. Backward Traceability (Guide → Spec)

Each guide must reference all requirements it documents.

**Format**:
```markdown
## Requirements Covered

This guide documents the following requirements:
- REQ-RES-001: Resource Definition
- REQ-BIND-003: Source Resolution
```

### 3. Scenario Traceability (Guide → Test)

Each guide must be validated by at least one scenario.

**Mapping**:
- Code examples should have corresponding SCN-*
- Common workflows should be covered by SCN-*

## Traceability Matrix

| Guide ID | Title | Requirements | Scenarios | Coverage |
|---|---|---|---|---|
| UG-0001 | Getting Started | REQ-RES-001, REQ-SCREEN-001 | SCN-001, SCN-004 | 100% |
| DG-0001 | Architecture Overview | REQ-FRAMEWORK-* | SCN-101 | 100% |

## Coverage Requirements

### User Guides

Must cover:
- All public APIs
- All common workflows
- All configuration options
- Error handling

### Developer Guides

Must cover:
- All internal APIs
- All extension points
- Contribution workflow
- Testing approaches

## Traceability Validation

Guides are validated for:

1. **Metadata Completeness** - All required fields present
2. **Reference Integrity** - All REQ-* and SCN-* references exist
3. **Coverage** - All REQ-* have at least one guide
4. **Consistency** - Examples match current code

## Automated Checking

The `validate_guides_governance.sh` script checks:

- Metadata YAML is valid
- REQ-* references exist in contracts
- SCN-* references exist in scenario catalog
- Coverage meets minimum thresholds

## Related Documents

- [guide_contract.md](guide_contract.md)
- [../specs/conformance/spec_conformance_matrix.md](../specs/conformance/spec_conformance_matrix.md)
- [../scripts/validate_guides_governance.sh](../scripts/validate_guides_governance.sh)
