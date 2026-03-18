# Guide Contract

This contract defines the requirements for all Ash UI documentation guides.

## Purpose

Ensures consistent quality, structure, and traceability across all documentation.

## Guide Types

### User Guides (UG-XXXX)

Written for application developers using Ash UI.

**Audience**: Developers building applications with Ash UI

**Content Focus**:
- How to use framework features
- Common patterns and examples
- Integration with other tools
- Best practices

### Developer Guides (DG-XXXX)

Written for contributors to the Ash UI framework.

**Audience**: Developers working on the Ash UI codebase

**Content Focus**:
- Internal architecture
- Contribution guidelines
- Development workflow
- Extension points

## Required Metadata

Every guide must include:

```yaml
---
id: UG-0001 or DG-0001
title: Guide Title
audience: [Application Developers | Framework Developers | Contributors]
status: [Draft | Review | Active | Deprecated]
owners: [Name of responsible team/individual]
last_reviewed: YYYY-MM-DD
next_review: YYYY-MM-DD
related_reqs: [REQ-XXXX, REQ-YYYY]
related_scns: [SCN-XXX, SCN-YYY]
related_guides: [UG-XXXX, DG-YYYY]
diagram_required: true | false
---
```

## Required Sections

### 1. Overview

Brief introduction to the guide's topic and purpose.

### 2. Prerequisites

What the reader should know before reading this guide.

### 3. Content

The main content of the guide, organized with clear headings.

### 4. Examples

Practical code examples where applicable.

### 5. See Also

Links to related guides, specs, and external resources.

## Diagram Requirements

When `diagram_required: true`, the guide must include:

- At least one Mermaid diagram
- Diagrams must use supported syntax (flowchart, graph, sequenceDiagram)
- Diagrams must be referenced in the text

## Code Examples

All code examples must:

1. Be syntactically correct
2. Be runnable (or clearly marked as pseudo-code)
3. Include explanatory comments
4. Follow project formatting standards

## Traceability

Guides must link to:

- **Requirements (REQ-*)** - Which specs this guide documents
- **Scenarios (SCN-*)** - Which test scenarios validate the content
- **Related Guides** - Other guides with related content

## Quality Standards

### Clarity

- Use clear, concise language
- Avoid jargon unless defined
- Explain complex concepts step by step

### Accuracy

- Code examples must be tested
- API references must be current
- Diagrams must match implementation

### Completeness

- Cover all common use cases
- Document error conditions
- Link to deeper details

### Accessibility

- Use semantic heading structure
- Include alt text for diagrams
- Consider screen reader compatibility

## Review Process

### Initial Review

Before publishing:

1. Technical review for accuracy
2. Copy edit for clarity
3. Test all code examples

### Periodic Review

Guides must be reviewed annually:

1. Check for accuracy with current code
2. Update examples if needed
3. Verify all links still work
4. Update `last_reviewed` date

### Update Triggers

Guides must be updated when:

- Related requirements change
- API changes affect examples
- New scenarios are added
- Deprecation notices are needed

## Related Documents

- [guide_traceability_contract.md](guide_traceability_contract.md)
- [../conformance/guide_conformance_matrix.md](../conformance/guide_conformance_matrix.md)
