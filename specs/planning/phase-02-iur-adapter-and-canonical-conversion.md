# Phase 2 - IUR Adapter and Canonical Conversion

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `AshUI.Compilation.IUR`
- `AshUI.Rendering.IURAdapter`
- `UnifiedIUR` (unified_iur package)
- `UnifiedIUR.Screen`
- `UnifiedIUR.Element`
- `UnifiedIUR.Signal`

## Relevant Assumptions / Defaults
- Ash UI compiles Ash Resources to Ash-internal IUR format
- IUR Adapter converts Ash IUR to canonical unified_iur format
- unified_iur package provides canonical data structures
- Renderer packages consume canonical IUR, not Ash-specific formats

[ ] 2 Phase 2 - IUR Adapter and Canonical Conversion
  Implement the conversion layer from Ash Resources through Ash IUR to canonical unified_iur format for renderer consumption.

  [X] 2.1 Section - Ash IUR Compilation
    Implement compilation from Ash Resources to Ash-internal IUR format.

    [X] 2.1.1 Task - Define Ash IUR data structures
      Create the internal IUR representation used during compilation.

      [X] 2.1.1.1 Subtask - Implement `AshUI.Compilation.IUR` struct with `id`, `type`, `name` fields
      [X] 2.1.1.2 Subtask - Add `attributes` (map), `children` (list), `bindings` (list) fields
      [X] 2.1.1.3 Subtask - Add `metadata` (map) and `version` (string) fields
      [X] 2.1.1.4 Subtask - Implement `@enforce_keys` for required fields

    [X] 2.1.2 Task - Implement Resource to IUR compiler
      Create the compiler that converts Ash Resources to IUR structures.

      [X] 2.1.2.1 Subtask - Implement `AshUI.Compiler.compile/2` for screen resources
      [X] 2.1.2.2 Subtask - Convert screen attributes to IUR root element
      [X] 2.1.2.3 Subtask - Load and convert associated elements as IUR children
      [X] 2.1.2.4 Subtask - Load and convert associated bindings as IUR bindings

    [X] 2.1.3 Task - Implement IUR validation
      Ensure compiled IUR structures are valid before conversion.

      [X] 2.1.3.1 Subtask - Validate IUR has required fields and correct types
      [X] 2.1.3.2 Subtask - Validate children references exist
      [X] 2.1.3.3 Subtask - Validate binding references are resolvable
      [X] 2.1.3.4 Subtask - Return structured errors for invalid IUR

  [ ] 2.2 Section - Canonical IUR Adapter
    Implement conversion from Ash IUR to canonical unified_iur format.

    [ ] 2.2.1 Task - Define adapter interface
      Create the adapter contract for IUR conversion.

      [ ] 2.2.1.1 Subtask - Implement `AshUI.Rendering.IURAdapter.to_canonical/1` function
      [ ] 2.2.1.2 Subtask - Return `{:ok, UnifiedIUR.Screen.t()}` or `{:error, term()}`
      [ ] 2.2.1.3 Subtask - Implement `compatible?/2` to check renderer compatibility
      [ ] 2.2.1.4 Subtask - Add telemetry events for conversion success/failure

    [ ] 2.2.2 Task - Implement element type mapping
      Map Ash UI element types to unified-ui widget types.

      [ ] 2.2.2.1 Subtask - Create type mapping table (button, input, text, image, etc.)
      [ ] 2.2.2.2 Subtask - Convert Ash element `type` to unified widget `type`
      [ ] 2.2.2.3 Subtask - Handle unknown element types with error or fallback
      [ ] 2.2.2.4 Subtask - Document supported element types

    [ ] 2.2.3 Task - Implement props mapping
      Map Ash element props to unified-ui widget attributes.

      [ ] 2.2.3.1 Subtask - Convert Ash `props` map to unified widget attributes
      [ ] 2.2.3.2 Subtask - Handle prop name conversions (e.g., `onClick` → `on_click`)
      [ ] 2.2.3.3 Subtask - Filter out Ash-specific props from canonical IUR
      [ ] 2.2.3.4 Subtask - Apply prop transformations for type compatibility

    [ ] 2.2.4 Task - Implement layout mapping
      Convert Ash screen layout to unified-ui layout constructs.

      [ ] 2.2.4.1 Subtask - Map Ash `layout` attribute to unified layout type
      [ ] 2.2.4.2 Subtask - Convert children to unified container structure
      [ ] 2.2.4.3 Subtask - Handle nested layouts and layering constructs
      [ ] 2.2.4.4 Subtask - Preserve layout metadata in canonical IUR

  [ ] 2.3 Section - Signal Conversion
    Convert Ash UI bindings to unified-ui signal format.

    [ ] 2.3.1 Task - Define signal mapping
      Create the mapping from Ash bindings to unified signals.

    [ ] 2.3.1.1 Subtask - Implement `AshUI.Signal.to_canonical/1` function
    [ ] 2.3.1.2 Subtask - Convert binding source to unified signal source format
    [ ] 2.3.1.3 Subtask - Convert binding target to unified signal target format
    [ ] 2.3.1.4 Subtask - Map binding type to unified signal type

    [ ] 2.3.2 Task - Implement binding type conversion
      Map Ash binding types to unified signal types.

    [ ] 2.3.2.1 Subtask - Convert `:value` binding to bidirectional signal
    [ ] 2.3.2.2 Subtask - Convert `:list` binding to collection signal
    [ ] 2.3.2.3 Subtask - Convert `:action` binding to event signal
    [ ] 2.3.2.4 Subtask - Handle transformation rules in signal definition

    [ ] 2.3.3 Task - Implement signal source resolution
      Resolve Ash resource paths in binding sources.

    [ ] 2.3.3.1 Subtask - Parse binding source path (Domain.Resource.Attribute)
    [ ] 2.3.3.2 Subtask - Validate source exists in Ash resource definitions
    [ ] 2.3.3.3 Subtask - Convert source path to unified signal reference
    [ ] 2.3.3.4 Subtask - Handle nested paths and relationship traversal

  [ ] 2.4 Section - Error Handling and Validation
    Implement error handling for IUR conversion failures.

    [ ] 2.4.1 Task - Define error types
      Create structured error types for conversion failures.

    [ ] 2.4.1.1 Subtask - Implement `AshUI.Rendering.ConversionError` exception
    [ ] 2.4.1.2 Subtask - Add error fields: `phase`, `element_id`, `reason`
    [ ] 2.4.1.3 Subtask - Implement error formatting for user display
    [ ] 2.4.1.4 Subtask - Add error telemetry with correlation IDs

    [ ] 2.4.2 Task - Implement validation checks
      Add validation at each conversion stage.

    [ ] 2.4.2.1 Subtask - Validate Ash IUR before canonical conversion
    [ ] 2.4.2.2 Subtask - Validate canonical IUR structure after conversion
    [ ] 2.4.2.3 Subtask - Collect all validation errors before returning
    [ ] 2.4.2.4 Subtask - Provide detailed error location information

  [ ] 2.5 Section - Phase 2 Integration Tests
    Validate IUR compilation and canonical conversion end-to-end.

    [ ] 2.5.1 Task - Compilation integration scenarios
      Verify Ash Resource to IUR compilation works correctly.

    [ ] 2.5.1.1 Subtask - Verify screen resource compiles to valid IUR structure
    [ ] 2.5.1.2 Subtask - Verify elements are compiled as IUR children
    [ ] 2.5.1.3 Subtask - Verify bindings are compiled as IUR bindings
    [ ] 2.5.1.4 Subtask - Verify invalid resources produce compilation errors

    [ ] 2.5.2 Task - Canonical conversion integration scenarios
      Verify Ash IUR to canonical IUR conversion works correctly.

    [ ] 2.5.2.1 Subtask - Verify simple element converts to canonical widget
    [ ] 2.5.2.2 Subtask - Verify layout converts to canonical layout structure
    [ ] 2.5.2.3 Subtask - Verify binding converts to canonical signal
    [ ] 2.5.2.4 Subtask - Verify complex nested screen converts fully

    [ ] 2.5.3 Task - Error handling integration scenarios
      Verify errors are handled gracefully.

    [ ] 2.5.3.1 Subtask - Verify invalid IUR produces structured error
    [ ] 2.5.3.2 Subtask - Verify unknown element type produces clear error
    [ ] 2.5.3.3 Subtask - Verify invalid binding source produces resolution error
    [ ] 2.5.3.4 Subtask - Verify partial failures don't crash adapter
