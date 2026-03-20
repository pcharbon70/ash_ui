defmodule AshUI.RelationshipIntegrationTest do
  use AshUI.DataCase, async: false

  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  @moduletag :conformance

  setup do
    # Create a screen with multiple elements and bindings
    {:ok, screen} =
      AshUI.Data.create(Screen,
        attrs: %{
          name: "relationship_test_screen",
          unified_dsl: %{"type" => "screen"},
          layout: :column
        }
      )

    # Create multiple elements
    elements =
      Enum.map(1..3, fn i ->
        {:ok, element} =
          AshUI.Data.create(Element,
            attrs: %{
              type: :text,
              props: %{"content" => "Text #{i}"},
              screen_id: screen.id,
              position: i
            }
          )

        element
      end)

    # Create bindings for each element
    bindings =
      Enum.flat_map(elements, fn element ->
        Enum.map(1..2, fn j ->
          {:ok, binding} =
            AshUI.Data.create(Binding,
              attrs: %{
                source: %{"field" => "field_#{j}"},
                target: "target_#{j}",
                binding_type: :value,
                element_id: element.id,
                screen_id: screen.id
              }
            )

          binding
        end)
      end)

    %{screen: screen, elements: elements, bindings: bindings}
  end

  describe "Loading screen with preloaded elements" do
    test "loads all associated elements", %{screen: screen} do
      screen_with_elements =
        AshUI.Data.read_one!(Screen,
          filter: [id: screen.id],
          load: [:elements]
        )

      assert length(screen_with_elements.elements) == 3

      # Verify elements are properly associated
      Enum.each(screen_with_elements.elements, fn element ->
        assert element.screen_id == screen.id
      end)
    end

    test "loads elements in correct position order", %{screen: screen} do
      screen_with_elements =
        AshUI.Data.read_one!(Screen,
          filter: [id: screen.id],
          load: [elements: Ash.Query.sort(Element, position: :asc)]
        )

      positions = Enum.map(screen_with_elements.elements, & &1.position)
      assert positions == [1, 2, 3]
    end
  end

  describe "Loading element with preloaded bindings" do
    test "loads all associated bindings for an element", %{elements: [element | _]} do
      element_with_bindings =
        AshUI.Data.read_one!(Element,
          filter: [id: element.id],
          load: [:bindings]
        )

      assert length(element_with_bindings.bindings) == 2

      # Verify bindings are properly associated
      Enum.each(element_with_bindings.bindings, fn binding ->
        assert binding.element_id == element.id
      end)
    end
  end

  describe "Querying elements by screen association" do
    test "filters elements by screen_id", %{screen: screen} do
      elements = AshUI.Data.read!(Element, filter: [screen_id: screen.id])

      assert length(elements) == 3
    end

    test "combines screen filter with other conditions", %{screen: screen} do
      elements =
        AshUI.Data.read!(Element,
          filter: [
            screen_id: screen.id,
            position: [greater_than: 1]
          ]
        )

      assert length(elements) == 2
      Enum.each(elements, fn element ->
        assert element.position > 1
      end)
    end
  end

  describe "Querying bindings by element or screen associations" do
    test "filters bindings by element_id", %{elements: [element | _]} do
      bindings = AshUI.Data.read!(Binding, filter: [element_id: element.id])

      assert length(bindings) == 2
    end

    test "filters bindings by screen_id", %{screen: screen} do
      bindings = AshUI.Data.read!(Binding, filter: [screen_id: screen.id])

      # Each element has 2 bindings, 3 elements = 6 bindings
      assert length(bindings) == 6
    end

    test "combines element and screen filters", %{
      screen: screen,
      elements: [element | _]
    } do
      bindings =
        AshUI.Data.read!(Binding,
          filter: [
            element_id: element.id,
            screen_id: screen.id
          ]
        )

      assert length(bindings) == 2
    end
  end

  describe "Nested relationship loading" do
    test "loads screen with elements and their bindings", %{screen: screen} do
      screen_with_all =
        AshUI.Data.read_one!(Screen,
          filter: [id: screen.id],
          load: [elements: [:bindings]]
        )

      assert length(screen_with_all.elements) == 3

      # Each element should have 2 bindings
      total_bindings =
        screen_with_all.elements
        |> Enum.map(&(length(&1.bindings)))
        |> Enum.sum()

      assert total_bindings == 6
    end
  end

  describe "Cross-resource queries" do
    test "finds all bindings for screen's elements", %{screen: screen} do
      # Get all element IDs for the screen
      elements = AshUI.Data.read!(Element, filter: [screen_id: screen.id])
      element_ids = Enum.map(elements, & &1.id)

      # Find all bindings for those elements
      bindings =
        AshUI.Data.read!(Binding, filter: [element_id: [in: element_ids]])

      assert length(bindings) == 6
    end
  end
end
