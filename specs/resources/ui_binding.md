# UI.Binding Component Spec

## Module

`AshUI.Resources.Binding`

## Purpose

Defines persisted runtime bindings for value reads, list reads, and action execution.

## Persisted Attributes

- `id`: UUID primary key
- `source`: structured map describing resource, field, relationship, or action
- `target`: renderer-facing target string
- `binding_type`: one of `:value`, `:list`, `:action`
- `transform`: transformation configuration
- `metadata`: free-form annotations
- `active`: soft enablement flag
- `version`: update version
- `inserted_at`
- `updated_at`

## Relationships

- `belongs_to :element`
- `belongs_to :screen`

## Actions

- `read`
- `create`
- `update`
- `destroy`
- optional filtered reads

## Runtime Role

- evaluated by `AshUI.Runtime.BindingEvaluator`
- written through `AshUI.Runtime.BidirectionalBinding`
- action-triggered through `AshUI.Runtime.ActionBinding`
- list-oriented updates handled by `AshUI.Runtime.ListBinding`

## Current Gaps

- runtime binding paths resolve reads, writes, list loading, and actions through real Ash-backed helpers
- structured source maps are the implemented baseline; older string path examples are obsolete
