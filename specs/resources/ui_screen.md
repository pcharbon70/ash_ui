# UI.Screen Component Spec

## Module

`AshUI.Resources.Screen`

## Purpose

Defines the persisted top-level screen record used by compilation, runtime mounting, and renderer adaptation.

## Persisted Attributes

- `id`: UUID primary key
- `name`: unique screen identifier
- `unified_dsl`: nested screen tree
- `layout`: layout hint
- `route`: optional route
- `metadata`: free-form annotations
- `active`: soft enablement flag
- `version`: update version
- `inserted_at`
- `updated_at`

## Relationships

- `has_many :elements`
- `has_many :bindings`

## Actions

- `read`
- `create`
- `update`
- `destroy`

## Runtime Role

- loaded by `AshUI.LiveView.Integration`
- compiled by `AshUI.Compiler`
- adapted by `AshUI.Rendering.IURAdapter`
- authorized through runtime authorization helpers today

## Current Gaps

- resource-level `Ash.Policy.Authorizer` wiring is still pending
- lifecycle is runtime-managed rather than implemented as screen resource actions
