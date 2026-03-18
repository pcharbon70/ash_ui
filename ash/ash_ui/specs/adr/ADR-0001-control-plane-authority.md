# ADR-0001: Control Plane Authority

## Status

**Accepted**

## Context

The Ash UI framework is organized into multiple control planes, each with distinct responsibilities. As the system grows, we need clear rules for authority delegation, dispute resolution, and cross-cutting concerns to prevent architectural drift and ensure consistent behavior.

## Decision

### Control Plane Hierarchy

We establish the following precedence hierarchy for control plane authority:

1. **Framework Control Plane** (highest) - Owns resource schemas, type system, action contracts
2. **Compilation Control Plane** - Owns compilation pipeline, IUR schema
3. **Runtime Control Plane** - Owns session lifecycle, event handling
4. **Rendering Control Plane** - Owns output format, renderer contracts
5. **Extension Control Plane** (lowest) - Owns extension contracts, plugin admission

### Authority Principles

1. **Exclusive Authority**: Each control plane has exclusive authority over its designated scope
2. **Contract-Based Interaction**: Control planes interact only through defined contracts
3. **No Direct Internals Access**: Control planes never directly access another control plane's internal modules
4. **Explicit Delegation**: Cross-cutting concerns are explicitly delegated via contracts

### Dispute Resolution

When authority boundaries are unclear:

1. **Framework Precedence**: Framework control plane has final say on resource schemas
2. **Runtime > Rendering**: Runtime controls when rendering occurs
3. **Compilation > Extension**: Compilation controls what can be compiled
4. **ADR Creation**: All disputes must result in an ADR documenting the decision

### Namespace Convention

All modules follow the namespace hierarchy:

```elixir
AshUI                      # Application root
AshUI.Framework            # Framework Control Plane
AshUI.Compilation          # Compilation Control Plane
AshUI.Runtime              # Runtime Control Plane
AshUI.Rendering            # Rendering Control Plane
AshUI.Extension            # Extension Control Plane
```

### Cross-Cutting Concerns

| Concern | Owner | Enforcement |
|---|---|---|
| Authorization | Framework (policy definition) | Runtime (enforcement) |
| Observability | Framework (schema) | All planes (emission) |
| Configuration | Framework (schema) | All planes (usage) |

## Consequences

### Positive

- Clear ownership prevents duplicate work
- Disputes have a resolution path
- Architectural consistency is maintained
- Teams can work autonomously within their control plane

### Negative

- Additional overhead for cross-plane changes
- ADRs are required for precedent-setting decisions
- Some flexibility is lost due to strict boundaries

### Mitigations

- Keep contracts minimal and focused
- Regular cross-plane reviews
- ADR template for quick creation
- Allow experimental features with sunset clauses

## Related

- [Control Plane Ownership Matrix](../contracts/control_plane_ownership_matrix.md)
- [Topology](../topology.md)
- All REQ-* contracts

## References

- jido_os ADR-0001 (inspiration)
- Ash Framework architecture
