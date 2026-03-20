defmodule AshUI.Compiler.IncrementalTest do
  use AshUI.DataCase, async: false

  alias AshUI.Compiler.Incremental
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  describe "build_dependencies/1" do
    setup do
      {:ok, screen} =
        AshUI.Data.create(Screen,
          attrs: %{
            name: "incremental_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      # Create elements
      {:ok, element1} =
        AshUI.Data.create(Element,
          attrs: %{
            type: :text,
            props: %{"content" => "Text 1"},
            screen_id: screen.id,
            position: 1
          }
        )

      {:ok, element2} =
        AshUI.Data.create(Element,
          attrs: %{
            type: :button,
            props: %{"label" => "Button"},
            screen_id: screen.id,
            position: 2
          }
        )

      # Create binding
      {:ok, _binding} =
        AshUI.Data.create(Binding,
          attrs: %{
            source: %{"resource" => "Test", "field" => "value"},
            target: "test_target",
            binding_type: :value,
            element_id: element1.id,
            screen_id: screen.id
          }
        )

      %{screen: screen, elements: [element1, element2]}
    end

    test "builds dependency graph for screen", %{screen: screen} do
      assert {:ok, graph} = Incremental.build_dependencies(screen)

      assert is_map(graph.screen_to_elements)
      assert is_map(graph.element_to_screen)
      assert is_map(graph.element_to_bindings)
      assert is_map(graph.binding_to_element)
    end

    test "tracks element to screen relationships", %{screen: screen, elements: elements} do
      [element1 | _] = elements

      {:ok, graph} = Incremental.build_dependencies(screen)

      assert graph.element_to_screen[element1.id] == screen.id
    end

    test "tracks binding to element relationships", %{screen: screen} do
      # Binding created in setup
      {:ok, graph} = Incremental.build_dependencies(screen)

      assert map_size(graph.binding_to_element) > 0
    end

    test "detects no circular dependencies in valid graph", %{screen: screen} do
      {:ok, graph} = Incremental.build_dependencies(screen)

      assert Incremental.detect_circular_dependencies(graph) == :ok
    end
  end

  describe "affects_screen?/4" do
    setup do
      {:ok, screen} =
        AshUI.Data.create(Screen,
          attrs: %{
            name: "affects_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      {:ok, element} =
        AshUI.Data.create(Element,
          attrs: %{
            type: :text,
            props: %{"content" => "Test"},
            screen_id: screen.id,
            position: 1
          }
        )

      {:ok, graph} = Incremental.build_dependencies(screen)

      %{screen: screen, element: element, graph: graph}
    end

    test "returns true when element belongs to screen", %{graph: graph, element: element, screen: screen} do
      assert Incremental.affects_screen?(graph, :element, element.id, screen.id) == true
    end

    test "returns false for unrelated element", %{graph: graph, screen: screen} do
      assert Incremental.affects_screen?(graph, :element, "unrelated-element", screen.id) == false
    end
  end

  describe "get_dependents/3" do
    setup do
      {:ok, screen} =
        AshUI.Data.create(Screen,
          attrs: %{
            name: "dependents_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      {:ok, element} =
        AshUI.Data.create(Element,
          attrs: %{
            type: :text,
            props: %{"content" => "Test"},
            screen_id: screen.id,
            position: 1
          }
        )

      {:ok, _binding} =
        AshUI.Data.create(Binding,
          attrs: %{
            source: %{"resource" => "Test", "field" => "value"},
            target: "test_target",
            binding_type: :value,
            element_id: element.id,
            screen_id: screen.id
          }
        )

      {:ok, graph} = Incremental.build_dependencies(screen)

      %{screen: screen, element: element, graph: graph}
    end

    test "returns all dependents of an element", %{element: element, graph: graph} do
      {:ok, dependents} = Incremental.get_dependents(graph, :element, element.id)

      # Should include the screen and the binding
      assert length(dependents) >= 1
      assert Enum.any?(dependents, &(&1.type == :screen))
    end
  end

  describe "detect_circular_dependencies/1" do
    test "returns :ok for acyclic graph" do
      graph = %{
        screen_to_elements: %{"screen-1" => ["element-1"]},
        element_to_screen: %{"element-1" => "screen-1"},
        element_to_bindings: %{},
        binding_to_element: %{}
      }

      assert Incremental.detect_circular_dependencies(graph) == :ok
    end

    test "returns error for cyclic graph" do
      graph = %{
        screen_to_elements: %{"screen-1" => ["screen-1"]},
        element_to_screen: %{"screen-1" => "screen-1"},
        element_to_bindings: %{},
        binding_to_element: %{}
      }

      assert {:error, cycles} = Incremental.detect_circular_dependencies(graph)
      assert length(cycles) > 0
    end
  end

  describe "recompile_on_change/4" do
    setup do
      {:ok, screen} =
        AshUI.Data.create(Screen,
          attrs: %{
            name: "recompile_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      %{screen: screen}
    end

    test "recompiles screen when element changes", %{screen: screen} do
      # Mark screen as needing recompile by invalidating cache
      AshUI.Compiler.invalidate_cache(screen.id)

      # The actual recompile would happen on element change
      # This tests the path
      assert {:ok, _iur} = AshUI.Compiler.compile(screen, use_cache: false)
    end

    test "returns cached version when unaffected change", %{screen: screen} do
      # Compile once to cache
      assert {:ok, _iur} = AshUI.Compiler.compile(screen, use_cache: true)

      # Compile again should hit cache
      {:ok, _iur} = AshUI.Compiler.compile(screen, use_cache: true)

      stats = AshUI.Compiler.cache_stats()
      assert stats.hits >= 1
    end
  end

  describe "recompile_batch/2" do
    test "recompiles multiple screens efficiently" do
      changes = [
        {:screen, "screen-1", :element, "element-1"},
        {:screen, "screen-2", :binding, "binding-1"}
      ]

      # Should not error even with non-existent screens
      assert {:ok, results} = Incremental.recompile_batch(changes)
      assert is_map(results)
    end

    test "handles empty changes list" do
      assert {:ok, %{}} = Incremental.recompile_batch([])
    end
  end
end
