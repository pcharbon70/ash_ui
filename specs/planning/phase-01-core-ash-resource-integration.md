# Phase 1 - Core Ash Resource Integration

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `AshUI.Resource`
- `AshUI.Resource.DSL`
- `Ash.Resource`
- `Ash.Domain`
- `Ash.DataLayer`
- `Ash.Query`

## Relevant Assumptions / Defaults
- UI definitions are stored as Ash Resources with PostgreSQL data layer
- unified-ui DSL is stored as a map attribute on Ash Resources
- Ash actions provide CRUD operations on UI definitions
- Ash policies authorize UI access and modification

[ ] 1 Phase 1 - Core Ash Resource Integration
  Implement Ash Resources for storing unified-ui DSL definitions with database persistence, Ash actions, and policy-based authorization.

  Status note: resource schemas, domain registration, migrations, and CRUD coverage exist in the repo today. This phase remains open because DSL extensions, screen lifecycle actions, direct resource-level authorizer wiring, and a few relationship/validation details are still unfinished.

  [ ] 1.1 Section - UI Screen Resource
    Implement the UI.Screen Ash Resource for storing unified-ui screen definitions.

    [X] 1.1.1 Task - Define UI.Screen resource schema
      Create the Ash Resource for screen definitions with unified-ui DSL storage.

      [X] 1.1.1.1 Subtask - Implement `AshUI.Resources.Screen` resource with `use Ash.Resource`
      [X] 1.1.1.2 Subtask - Add `id` (UUID primary key), `name` (string), `unified_dsl` (map) attributes
      [X] 1.1.1.3 Subtask - Add `layout` (atom), `route` (string), `metadata` (map) attributes
      [X] 1.1.1.4 Subtask - Add `version` (integer) and timestamps
      [X] 1.1.1.5 Subtask - Configure `AshPostgres.DataLayer` with `table: "ui_screens"`

    [ ] 1.1.2 Task - Define UI.Screen actions
      Implement standard Ash actions for screen CRUD operations.

      [X] 1.1.2.1 Subtask - Add default actions: `:read`, `:create`, `:update`, `:destroy`
      [ ] 1.1.2.2 Subtask - Implement `:mount` action with `user_id` and `params` arguments
      [ ] 1.1.2.3 Subtask - Implement `:unmount` action for cleanup
      [ ] 1.1.2.4 Subtask - Add action return types and error handling

    [ ] 1.1.3 Task - Define UI.Screen relationships
      Establish relationships to elements and bindings.

      [X] 1.1.3.1 Subtask - Add `has_many :elements` relationship to `AshUI.Element`
      [X] 1.1.3.2 Subtask - Add `has_many :bindings` relationship to `AshUI.Binding`
      [ ] 1.1.3.3 Subtask - Configure cascade delete for child elements and bindings

    [ ] 1.1.4 Task - Add UI.Screen DSL extension
      Create the `ui_screen` DSL block for screen-specific configuration.

      [ ] 1.1.4.1 Subtask - Implement `AshUI.Resource.DSL.Screen` extension
      [ ] 1.1.4.2 Subtask - Add `layout/1`, `route/1`, `metadata/1` DSL functions
      [ ] 1.1.4.3 Subtask - Validate DSL options at compile time
      [ ] 1.1.4.4 Subtask - Store DSL options in resource attributes

  [ ] 1.2 Section - UI Element Resource
    Implement the UI.Element Ash Resource for storing unified-ui element definitions.

    [X] 1.2.1 Task - Define UI.Element resource schema
      Create the Ash Resource for element definitions with unified-ui widget storage.

      [X] 1.2.1.1 Subtask - Implement `AshUI.Resources.Element` resource with `use Ash.Resource`
      [X] 1.2.1.2 Subtask - Add `id` (UUID), `type` (atom), `props` (map) attributes
      [X] 1.2.1.3 Subtask - Add `variants` (list of atoms), `position` (integer) attributes
      [X] 1.2.1.4 Subtask - Add `metadata` (map), `active`, `version`, and timestamps
      [X] 1.2.1.5 Subtask - Configure `AshPostgres.DataLayer` with `table: "ui_elements"`

    [X] 1.2.2 Task - Define UI.Element relationships
      Establish relationships to screen and bindings.

      [X] 1.2.2.1 Subtask - Add `belongs_to :screen` relationship to `AshUI.Screen`
      [X] 1.2.2.2 Subtask - Add `has_many :bindings` relationship to `AshUI.Binding`
      [X] 1.2.2.3 Subtask - Add foreign key `screen_id` attribute

    [ ] 1.2.3 Task - Add UI.Element DSL extension
      Create the `ui_element` DSL block for element-specific configuration.

      [ ] 1.2.3.1 Subtask - Implement `AshUI.Resource.DSL.Element` extension
      [ ] 1.2.3.2 Subtask - Add `type/1`, `props/1`, `variants/1` DSL functions
      [ ] 1.2.3.3 Subtask - Validate `type` against known unified-ui widget types
      [ ] 1.2.3.4 Subtask - Store element definition in resource attributes

  [ ] 1.3 Section - UI Binding Resource
    Implement the UI.Binding Ash Resource for data binding definitions.

    [X] 1.3.1 Task - Define UI.Binding resource schema
      Create the Ash Resource for binding Ash data to UI elements.

      [X] 1.3.1.1 Subtask - Implement `AshUI.Resources.Binding` resource with `use Ash.Resource`
      [X] 1.3.1.2 Subtask - Add `id` (UUID), `source` (map), `target` (string) attributes
      [X] 1.3.1.3 Subtask - Add `binding_type` (atom), `transform` (map) attributes
      [X] 1.3.1.4 Subtask - Add `metadata` (map), `active`, `version`, and timestamps
      [X] 1.3.1.5 Subtask - Configure `AshPostgres.DataLayer` with `table: "ui_bindings"`

    [X] 1.3.2 Task - Define UI.Binding relationships
      Establish relationships to element and screen.

      [X] 1.3.2.1 Subtask - Add `belongs_to :element` relationship to `AshUI.Element`
      [X] 1.3.2.2 Subtask - Add `belongs_to :screen` relationship to `AshUI.Screen`
      [X] 1.3.2.3 Subtask - Add foreign keys `element_id` and `screen_id`

    [ ] 1.3.3 Task - Add UI.Binding DSL extension
      Create the `ui_binding` DSL block for binding configuration.

      [ ] 1.3.3.1 Subtask - Implement `AshUI.Resource.DSL.Binding` extension
      [ ] 1.3.3.2 Subtask - Add `source/1`, `target/1`, `binding_type/1` DSL functions
      [ ] 1.3.3.3 Subtask - Add `transform/1` DSL function for transformations
      [ ] 1.3.3.4 Subtask - Validate binding type is one of `:value`, `:list`, `:action`

  [ ] 1.4 Section - Ash Domain Configuration
    Implement the AshUI domain with all resources and authorization.

    [ ] 1.4.1 Task - Create AshUI.Domain
      Define the domain containing all Ash UI resources.

      [X] 1.4.1.1 Subtask - Implement `AshUI.Domain` with `use Ash.Domain`
      [X] 1.4.1.2 Subtask - Register `AshUI.Screen`, `AshUI.Element`, `AshUI.Binding` resources
      [ ] 1.4.1.3 Subtask - Configure domain-level authorization with `Ash.Policy.Authorizer`

    [ ] 1.4.2 Task - Configure resource validations
      Add validations for UI resource attributes.

      [ ] 1.4.2.1 Subtask - Validate `unified_dsl` is a valid map structure
      [X] 1.4.2.2 Subtask - Validate `binding_type` is in allowed list
      [ ] 1.4.2.3 Subtask - Validate `source` format matches structured binding source maps
      [ ] 1.4.2.4 Subtask - Add custom validations with `validate/1`

  [X] 1.5 Section - Database Migrations
    Create Ecto migrations for UI resource tables.

    [X] 1.5.1 Task - Generate migration files
      Create Ecto migrations for all UI resource tables.

      [X] 1.5.1.1 Subtask - Generate migration for `ui_screens` table
      [X] 1.5.1.2 Subtask - Generate migration for `ui_elements` table
      [X] 1.5.1.3 Subtask - Generate migration for `ui_bindings` table
      [X] 1.5.1.4 Subtask - Add foreign key constraints and indexes

    [X] 1.5.2 Task - Add unique constraints and indexes
      Optimize queries with proper indexes.

      [X] 1.5.2.1 Subtask - Add unique index on `ui_screens.name`
      [X] 1.5.2.2 Subtask - Add index on `ui_elements.screen_id`
      [X] 1.5.2.3 Subtask - Add composite index on `ui_bindings.element_id` and `screen_id`

  [ ] 1.6 Section - Phase 1 Integration Tests
    Validate Ash Resource CRUD, relationships, and DSL behavior end-to-end.

    [X] 1.6.1 Task - Resource CRUD integration scenarios
      Verify create, read, update, and destroy operations work correctly.

      [X] 1.6.1.1 Subtask - Verify screen creation with unified_dsl storage
      [X] 1.6.1.2 Subtask - Verify element creation with screen association
      [X] 1.6.1.3 Subtask - Verify binding creation with element and screen associations
      [ ] 1.6.1.4 Subtask - Verify cascade delete from screen to elements and bindings

    [ ] 1.6.2 Task - DSL and validation integration scenarios
      Verify DSL extensions and validations work correctly.

      [ ] 1.6.2.1 Subtask - Verify `ui_screen` DSL creates valid resource attributes
      [ ] 1.6.2.2 Subtask - Verify `ui_element` DSL validates widget types
      [ ] 1.6.2.3 Subtask - Verify `ui_binding` DSL validates binding types
      [ ] 1.6.2.4 Subtask - Verify invalid DSL options produce validation errors

    [X] 1.6.3 Task - Relationship and query integration scenarios
      Verify relationships and queries work correctly.

      [X] 1.6.3.1 Subtask - Verify loading screen with preloaded elements
      [X] 1.6.3.2 Subtask - Verify loading element with preloaded bindings
      [X] 1.6.3.3 Subtask - Verify querying elements by screen association
      [X] 1.6.3.4 Subtask - Verify querying bindings by element or screen associations
