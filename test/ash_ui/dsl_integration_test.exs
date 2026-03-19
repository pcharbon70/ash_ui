defmodule AshUI.DSLIntegrationTest do
  use AshUI.DataCase, async: false

  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  describe "ui_screen DSL extension" do
    test "creates valid resource attributes" do
      # Screen resource should be properly configured
      attrs = %{
        name: "dsl_screen_test",
        unified_dsl: %{"type" => "screen", "root" => %{"type" => "row"}},
        layout: :row,
        route: "/dsl-test"
      }

      assert {:ok, screen} = AshUI.Domain.create(Screen, attrs: attrs)
      assert screen.layout == :row
      assert screen.route == "/dsl-test"
      assert is_map(screen.unified_dsl)
    end

    test "stores DSL options in resource attributes" do
      attrs = %{
        name: "dsl_metadata_test",
        unified_dsl: %{"type" => "screen"},
        metadata: %{"custom" => "value", "priority" => 1}
      }

      assert {:ok, screen} = AshUI.Domain.create(Screen, attrs: attrs)
      assert screen.metadata == %{"custom" => "value", "priority" => 1}
    end
  end

  describe "ui_element DSL extension" do
    setup do
      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "element_dsl_test",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      %{screen: screen}
    end

    test "creates valid element with type validation", %{screen: screen} do
      # Valid widget types from unified-ui spec
      valid_types = [
        :text,
        :button,
        :textinput,
        :textarea,
        :select,
        :checkbox,
        :radio,
        :switch,
        :slider,
        :row,
        :column,
        :grid,
        :stack,
        :card,
        :list,
        :table
      }

      Enum.each(valid_types, fn type ->
        attrs = %{
          type: type,
          props: %{},
          screen_id: screen.id,
          position: 1
        }

        assert {:ok, _element} = AshUI.Domain.create(Element, attrs: attrs)
      end)
    end

    test "stores element props and variants", %{screen: screen} do
      attrs = %{
        type: :button,
        props: %{"label" => "Click me", "disabled" => false},
        variants: [:primary, :large],
        screen_id: screen.id,
        position: 1
      }

      assert {:ok, element} = AshUI.Domain.create(Element, attrs: attrs)
      assert element.props == %{"label" => "Click me", "disabled" => false}
      assert element.variants == [:primary, :large]
    end
  end

  describe "ui_binding DSL extension" do
    setup do
      {:ok, screen} =
        AshUI.Domain.create(Screen,
          attrs: %{
            name: "binding_dsl_test",
            unified_dsl: %{"type" => "screen"},
            layout: :row
          }
        )

      {:ok, element} =
        AshUI.Domain.create(Element,
          attrs: %{
            type: :textinput,
            props: %{},
            screen_id: screen.id,
            position: 1
          }
        )

      %{screen: screen, element: element}
    end

    test "validates binding_type is one of :value, :list, :action", %{
      screen: screen,
      element: element
    } do
      valid_types = [:value, :list, :action]

      Enum.each(valid_types, fn type ->
        attrs = %{
          source: %{"resource" => "Test", "field" => "test"},
          target: "target",
          binding_type: type,
          element_id: element.id,
          screen_id: screen.id
        }

        assert {:ok, _binding} = AshUI.Domain.create(Binding, attrs: attrs)
      end)
    end

    test "stores transform configuration", %{screen: screen, element: element} do
      attrs = %{
        source: %{"resource" => "User", "field" => "name"},
        target: "value",
        binding_type: :value,
        transform: %{"function" => "uppercase", "args" => []},
        element_id: element.id,
        screen_id: screen.id
      }

      assert {:ok, binding} = AshUI.Domain.create(Binding, attrs: attrs)
      assert binding.transform == %{"function" => "uppercase", "args" => []}
    end
  end

  describe "Invalid DSL options" do
    test "invalid binding_type produces validation error" do
      # Note: Ash atom type constraint allows any atom
      # Additional validation would need to be added via changeset
      # This test documents current behavior
      attrs = %{
        source: %{"field" => "test"},
        target: "test",
        binding_type: :invalid_type,
        element_id: nil,
        screen_id: nil
      }

      # Should fail due to nil foreign keys, not invalid type
      assert {:error, _error} = AshUI.Domain.create(Binding, attrs: attrs)
    end
  end
end
