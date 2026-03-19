defmodule AshUI.CompilerTest do
  use AshUI.DataCase, async: false

  alias AshUI.Compiler
  alias AshUI.Compilation.IUR
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  describe "compile/2" do
    setup do
      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "compiler_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row,
            route: "/compiler-test"
          }
        )

      # Create test elements
      {:ok, element1} =
        AshUI.Domain.create(Element,
          attrs: %{
            type: :text,
            props: %{"content" => "Hello"},
            screen_id: screen.id,
            position: 1
          }
        )

      {:ok, element2} =
        AshUI.Domain.create(Element,
          attrs: %{
            type: :button,
            props: %{"label" => "Click me"},
            screen_id: screen.id,
            position: 2
          }
        )

      # Create test binding
      {:ok, _binding} =
        AshUI.Domain.create(Binding,
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

    test "compiles screen resource to valid IUR structure", %{screen: screen} do
      assert {:ok, %IUR{} = iur} = Compiler.compile(screen)

      assert iur.type == :screen
      assert iur.name == "compiler_test_screen"
      assert is_map(iur.attributes)
      assert iur.attributes["layout"] == :row
      assert iur.attributes["route"] == "/compiler-test"
    end

    test "compiles elements as IUR children", %{screen: screen, elements: elements} do
      assert {:ok, %IUR{} = iur} = Compiler.compile(screen)

      assert length(iur.children) == 2

      # First element is text
      [child1, child2] = iur.children
      assert child1.type == :text
      assert child1.props["content"] == "Hello"

      # Second element is button
      assert child2.type == :button
      assert child2.props["label"] == "Click me"
    end

    test "compiles bindings as IUR bindings", %{screen: screen} do
      assert {:ok, %IUR{} = iur} = Compiler.compile(screen)

      assert length(iur.bindings) > 0

      binding = hd(iur.bindings)
      assert is_map(binding)
      assert binding["source"]["resource"] == "Test"
      assert binding["target"] == "test_target"
      assert binding["binding_type"] == :value
    end

    test "validates IUR after compilation", %{screen: screen} do
      assert {:ok, %IUR{} = iur} = Compiler.compile(screen)
      assert :ok = IUR.validate(iur)
    end
  end

  describe "compile/2 with options" do
    setup do
      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "options_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :column
          }
        )

      %{screen: screen}
    end

    test "load_elements: false skips loading elements", %{screen: screen} do
      assert {:ok, %IUR{} = iur} = Compiler.compile(screen, load_elements: false)
      assert iur.children == []
    end

    test "load_bindings: false skips loading bindings", %{screen: screen} do
      assert {:ok, %IUR{} = iur} = Compiler.compile(screen, load_bindings: false)
      assert iur.bindings == []
    end
  end

  describe "compile/2 error handling" do
    test "returns error for non-existent screen" do
      assert {:error, _reason} = Compiler.compile("non-existent-id")
    end
  end

  # Phase 6: Compiler and DSL Integration Tests

  describe "compile_from_unified_dsl/2" do
    setup do
      dsl = %{
        type: "row",
        props: %{"spacing" => 16},
        children: [
          %{
            type: "text",
            props: %{"content" => "Hello"},
            children: [],
            signals: [],
            metadata: %{}
          }
        ],
        signals: [],
        metadata: %{}
      }

      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "dsl_test_screen",
            unified_dsl: dsl,
            layout: :row
          }
        )

      %{screen: screen, dsl: dsl}
    end

    test "compiles valid unified_dsl to IUR", %{screen: screen} do
      assert {:ok, %IUR{} = iur} = Compiler.compile_from_unified_dsl(screen)
      assert iur.type == :screen
    end

    test "validates dsl before compilation" do
      invalid_dsl = %{
        type: "invalid_widget_type",
        props: %{},
        children: [],
        signals: [],
        metadata: %{}
      }

      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "invalid_dsl_screen",
            unified_dsl: invalid_dsl,
            layout: :row
          }
        )

      assert {:error, {:invalid_dsl, _errors}} = Compiler.compile_from_unified_dsl(screen)
    end
  end

  describe "caching" do
    setup do
      Compiler.init_cache()
      :ok
    end

    test "caches compiled IUR" do
      dsl = %{
        type: "text",
        props: %{"content" => "Cached"},
        children: [],
        signals: [],
        metadata: %{}
      }

      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "cache_test_screen",
            unified_dsl: dsl,
            layout: :row
          }
        )

      assert {:ok, iur1} = Compiler.compile(screen, use_cache: true)
      assert {:ok, iur2} = Compiler.compile(screen, use_cache: true)

      # Should get same result
      stats = Compiler.cache_stats()
      assert stats.hits >= 1
    end

    test "use_cache: false bypasses cache" do
      dsl = %{
        type: "text",
        props: %{},
        children: [],
        signals: [],
        metadata: %{}
      }

      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "no_cache_screen",
            unified_dsl: dsl,
            layout: :row
          }
        )

      Compiler.clear_cache()
      Compiler.init_cache()

      assert {:ok, _iur} = Compiler.compile(screen, use_cache: false)
      assert Compiler.cache_stats().hits == 0
    end

    test "invalidate_cache removes cached entry" do
      dsl = %{
        type: "text",
        props: %{},
        children: [],
        signals: [],
        metadata: %{}
      }

      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "invalidate_screen",
            unified_dsl: dsl,
            layout: :row
          }
        )

      assert {:ok, _iur} = Compiler.compile(screen)
      assert Compiler.cache_stats().size > 0

      Compiler.invalidate_cache(screen.id)

      # Size should decrease
      assert Compiler.cache_stats().size == 0
    end

    test "clear_cache removes all entries" do
      Compiler.clear_cache()

      assert Compiler.cache_stats().size == 0
    end

    test "cache_stats returns current statistics" do
      stats = Compiler.cache_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :size)
      assert Map.has_key?(stats, :hits)
      assert Map.has_key?(stats, :misses)
    end
  end

  describe "compile_batch/2" do
    test "compiles multiple screens" do
      # Create multiple screens
      dsl1 = %{type: "text", props: %{}, children: [], signals: [], metadata: %{}}
      dsl2 = %{type: "button", props: %{}, children: [], signals: [], metadata: %{}}

      {:ok, screen1} =
        AshUI.Domain.create(Screen,
          attrs: %{name: "batch_screen_1", unified_dsl: dsl1, layout: :row}
        )

      {:ok, screen2} =
        AshUI.Domain.create(Screen,
          attrs: %{name: "batch_screen_2", unified_dsl: dsl2, layout: :row}
        )

      assert {:ok, results} = Compiler.compile_batch([screen1.id, screen2.id])
      assert map_size(results) == 2
    end
  end
end
