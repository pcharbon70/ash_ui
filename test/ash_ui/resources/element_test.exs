defmodule AshUI.Resources.ElementTest do
  use AshUI.DataCase, async: false

  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element

  describe "Element CRUD operations" do
    setup do
      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "element_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      %{screen: screen}
    end

    test "create/1 creates an element with screen association", %{screen: screen} do
      attrs = %{
        type: :text,
        props: %{"content" => "Hello World"},
        screen_id: screen.id,
        position: 1
      }

      assert {:ok, element} = AshUI.Domain.create(Element, attrs: attrs)
      assert element.type == :text
      assert element.props == %{"content" => "Hello World"}
      assert element.screen_id == screen.id
      assert element.position == 1
    end

    test "update/2 updates element attributes", %{screen: screen} do
      attrs = %{
        type: :text,
        props: %{"content" => "Original"},
        screen_id: screen.id,
        position: 1
      }

      {:ok, element} = AshUI.Domain.create(Element, attrs: attrs)
      {:ok, updated} = AshUI.Domain.update(element, attrs: %{props: %{"content" => "Updated"}})

      assert updated.props == %{"content" => "Updated"}
    end

    test "destroy/1 deletes an element", %{screen: screen} do
      attrs = %{
        type: :text,
        props: %{},
        screen_id: screen.id,
        position: 1
      }

      {:ok, element} = AshUI.Domain.create(Element, attrs: attrs)
      assert {:ok, _} = AshUI.Domain.destroy(element)

      assert [] = AshUI.Domain.read!(Element, filter: [id: element.id])
    end
  end

  describe "Element type validation" do
    test "validates element type against known widget types" do
      valid_types = [:text, :button, :textinput, :select, :checkbox, :row, :column]

      Enum.each(valid_types, fn type ->
        attrs = %{
          type: type,
          props: %{},
          position: 1
        }

        # Type should be accepted (validation happens at DSL level)
        assert {:ok, _element} = AshUI.Domain.create(Element, attrs: attrs)
      end)
    end
  end

  describe "Screen association" do
    test "loads elements through screen relationship" do
      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "association_test_screen",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      # Create elements
      Enum.each(1..3, fn i ->
        attrs = %{
          type: :text,
          props: %{"content" => "Element #{i}"},
          screen_id: screen.id,
          position: i
        }

        AshUI.Domain.create(Element, attrs: attrs)
      end)

      # Load screen with elements
      screen_with_elements =
        AshUI.Domain.read_one!(Screen,
          filter: [id: screen.id],
          load: [:elements]
        )

      assert length(screen_with_elements.elements) == 3
    end
  end
end
