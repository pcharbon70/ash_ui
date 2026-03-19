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
end
