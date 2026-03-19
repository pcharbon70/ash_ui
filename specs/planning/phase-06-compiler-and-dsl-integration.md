# Phase 6 - Compiler and DSL Integration

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `AshUI.Compiler`
- `unified-ui` compiler
- `AshUI.Resource.DSL`
- unified-ui DSL

## Relevant Assumptions / Defaults
- unified-ui provides the canonical UI DSL
- Ash UI stores unified-ui DSL in Ash Resources
- Compiler loads DSL from database and compiles to IUR
- Compilation is cached for performance

[ ] 6 Phase 6 - Compiler and DSL Integration
  Integrate the unified-ui compiler with Ash Resource loading to enable database-driven UI definitions.

  [ ] 6.1 Section - Unified-UI DSL Storage
    Store unified-ui DSL definitions in Ash Resource attributes.

    [ ] 6.1.1 Task - Define DSL storage format
    Create the format for storing unified-ui DSL in database.

      [ ] 6.1.1.1 Subtask - Define `unified_dsl` map attribute structure
      [ ] 6.1.1.2 Subtask - Store root element definition in DSL map
      [ ] 6.1.1.3 Subtask - Store children array in DSL map
      [ ] 6.1.1.4 Subtask - Store signals array in DSL map

    [ ] 6.1.2 Task - Create DSL builder helpers
    Provide helper functions for building unified-ui DSL.

      [ ] 6.1.2.1 Subtask - Implement `AshUI.DSL.root/2` macro
      [ ] 6.1.2.2 Subtask - Implement `AshUI.DSL.row/1`, `column/1` layout macros
      [ ] 6.1.2.3 Subtask - Implement `AshUI.DSL.text/1`, `button/1` widget macros
      [ ] 6.1.2.4 Subtask - Implement `AshUI.DSL.signal/3` for bindings

    [ ] 6.1.3 Task - Validate DSL at write time
    Ensure stored DSL is valid unified-ui format.

      [ ] 6.1.3.1 Subtask - Validate DSL structure before database write
      [ ] 6.1.3.2 Subtask - Check widget types against unified-ui catalog
      [ ] 6.1.3.3 Subtask - Check signal references are valid
      [ ] 6.1.3.4 Subtask - Return validation errors for invalid DSL

  [ ] 6.2 Section - Compiler Integration
    Integrate unified-ui compiler with Ash Resource loading.

    [ ] 6.2.1 Task - Implement AshUI.Compiler
    Create the compiler that loads and compiles UI definitions.

      [ ] 6.2.1.1 Subtask - Implement `AshUI.Compiler.compile_screen/2`
      [ ] 6.2.1.2 Subtask - Load screen resource from database
      [ ] 6.2.1.3 Subtask - Extract `unified_dsl` from resource
      [ ] 6.2.1.4 Subtask - Pass DSL to unified-ui compiler

    [ ] 6.2.2 Task - Integrate unified-ui compiler
    Call unified-ui compiler to produce IUR.

      [ ] 6.2.2.1 Subtask - Add `unified_ui` as dependency
      [ ] 6.2.2.2 Subtask - Call `UnifiedUI.Compiler.compile/1`
      [ ] 6.2.2.3 Subtask - Handle compilation errors from unified-ui
      [ ] 6.2.2.4 Subtask - Return Ash IUR or error

    [ ] 6.2.3 Task - Implement compilation caching
    Cache compiled IUR for performance.

      [ ] 6.2.3.1 Subtask - Generate cache key from resource ID and version
      [ ] 6.2.3.2 Subtask - Store compiled IUR in ETS cache
      [ ] 6.2.3.3 Subtask - Invalidate cache on resource update
      [ ] 6.2.3.4 Subtask - Configure cache size and TTL

  [ ] 6.3 Section - Incremental Compilation
    Support efficient recompilation when resources change.

    [ ] 6.3.1 Task - Track resource dependencies
    Track which resources depend on which.

      [ ] 6.3.1.1 Subtask - Record element-to-screen dependencies
      [ ] 6.3.1.2 Subtask - Record binding-to-element dependencies
      [ ] 6.3.1.3 Subtask - Detect circular dependencies
      [ ] 6.3.1.4 Subtask - Maintain dependency graph

    [ ] 6.3.2 Task - Implement selective recompilation
    Only recompile affected resources when things change.

      [ ] 6.3.2.1 Subtask - On element change, recompile parent screen
      [ ] 6.3.2.2 Subtask - On binding change, recompile affected elements
      [ ] 6.3.2.3 Subtask - Use cached IUR for unchanged resources
      [ ] 6.3.2.4 Subtask - Batch recompilation for multiple changes

  [ ] 6.4 Section - Compiler Extensions
    Support custom widget and layout extensions.

    [ ] 6.4.1 Task - Implement custom widget registration
    Allow registration of custom unified-ui widgets.

      [ ] 6.4.1.1 Subtask - Implement `AshUI.Compiler.register_widget/2`
      [ ] 6.4.1.2 Subtask - Validate widget against unified-ui spec
      [ ] 6.4.1.3 Subtask - Add widget to compiler catalog
      [ ] 6.4.1.4 Subtask - Document widget registration API

    [ ] 6.4.2 Task - Implement custom layout registration
    Allow registration of custom unified-ui layouts.

      [ ] 6.4.2.1 Subtask - Implement `AshUI.Compiler.register_layout/2`
      [ ] 6.4.2.2 Subtask - Validate layout against unified-ui spec
      [ ] 6.4.2.3 Subtask - Add layout to compiler catalog
      [ ] 6.4.2.4 Subtask - Document layout registration API

  [ ] 6.5 Section - Phase 6 Integration Tests
    Validate compiler and DSL integration end-to-end.

    [ ] 6.5.1 Task - DSL storage and retrieval scenarios
    Verify DSL is stored and retrieved correctly.

      [ ] 6.5.1.1 Subtask - Verify DSL builder creates valid structure
      [ ] 6.5.1.2 Subtask - Verify DSL persists to database correctly
      [ ] 6.5.1.3 Subtask - Verify DSL loads from database correctly
      [ ] 6.5.1.4 Subtask - Verify invalid DSL is rejected

    [ ] 6.5.2 Task - Compilation scenarios
    Verify compilation pipeline works correctly.

      [ ] 6.5.2.1 Subtask - Verify simple screen compiles successfully
      [ ] 6.5.2.2 Subtask - Verify complex nested screen compiles successfully
      [ ] 6.5.2.3 Subtask - Verify compilation errors are reported clearly
      [ ] 6.5.2.4 Subtask - Verify cache hit returns cached IUR

    [ ] 6.5.3 Task - Incremental compilation scenarios
    Verify incremental recompilation works correctly.

      [ ] 6.5.3.1 Subtask - Verify element change triggers screen recompile
      [ ] 6.5.3.2 Subtask - Verify unchanged resources use cache
      [ ] 6.5.3.3 Subtask - Verify dependency tracking works
      [ ] 6.5.3.4 Subtask - Verify circular dependencies are detected

    [ ] 6.5.4 Task - Extension scenarios
    Verify custom widgets and layouts work.

      [ ] 6.5.4.1 Subtask - Verify custom widget can be registered
      [ ] 6.5.4.2 Subtask - Verify custom widget compiles correctly
      [ ] 6.5.4.3 Subtask - Verify custom layout can be registered
      [ ] 6.5.4.4 Subtask - Verify custom layout compiles correctly
