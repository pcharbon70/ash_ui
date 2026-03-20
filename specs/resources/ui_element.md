# UI.Element Component Spec

## Module

`AshUI.Resources.Element`

## Purpose

Defines persisted element records that support relational querying, ordering, and incremental composition alongside `Screen.unified_dsl`.

## Persisted Attributes

- `id`: UUID primary key
- `type`: renderer-facing component identifier
- `props`: component properties
- `variants`: variant list
- `position`: ordering value
- `metadata`: free-form annotations
- `active`: soft enablement flag
- `version`: update version
- `inserted_at`
- `updated_at`

## Relationships

- `belongs_to :screen`
- `has_many :bindings`

## Actions

- `read`
- `create`
- `update`
- `destroy`

## Runtime Role

- loaded when screens compile from relational resources
- used for ordering and association queries
- paired with bindings for dynamic behavior

## Current Gaps

- resource-level policies are still helper-based rather than fully attached to the resource DSL
