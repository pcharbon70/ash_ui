defmodule AshUI.Resources.BindingTest do
  use AshUI.DataCase, async: false

  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  @moduletag :conformance

  setup do
    {:ok, screen} =
      AshUI.Domain.create(Screen,
        attrs: %{
          name: "binding_test_screen",
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

  describe "Binding CRUD operations" do
    test "create/1 creates a binding with element and screen associations", %{
      screen: screen,
      element: element
    } do
      attrs = %{
        source: %{"resource" => "User", "field" => "name"},
        target: "value",
        binding_type: :value,
        element_id: element.id,
        screen_id: screen.id
      }

      assert {:ok, binding} = AshUI.Domain.create(Binding, attrs: attrs)
      assert binding.source == %{"resource" => "User", "field" => "name"}
      assert binding.target == "value"
      assert binding.binding_type == :value
      assert binding.element_id == element.id
      assert binding.screen_id == screen.id
    end

    test "create/1 with list binding type", %{screen: screen, element: element} do
      attrs = %{
        source: %{"resource" => "Post", "relationship" => "comments"},
        target: "items",
        binding_type: :list,
        element_id: element.id,
        screen_id: screen.id
      }

      assert {:ok, binding} = AshUI.Domain.create(Binding, attrs: attrs)
      assert binding.binding_type == :list
    end

    test "create/1 with action binding type", %{screen: screen, element: element} do
      attrs = %{
        source: %{"resource" => "User", "action" => "create"},
        target: "onClick",
        binding_type: :action,
        element_id: element.id,
        screen_id: screen.id
      }

      assert {:ok, binding} = AshUI.Domain.create(Binding, attrs: attrs)
      assert binding.binding_type == :action
    end

    test "update/2 updates binding attributes", %{screen: screen, element: element} do
      attrs = %{
        source: %{"resource" => "User", "field" => "name"},
        target: "value",
        binding_type: :value,
        element_id: element.id,
        screen_id: screen.id
      }

      {:ok, binding} = AshUI.Domain.create(Binding, attrs: attrs)

      {:ok, updated} =
        AshUI.Domain.update(binding,
          attrs: %{
            transform: %{"function" => "uppercase"}
          }
        )

      assert updated.transform == %{"function" => "uppercase"}
    end
  end

  describe "Binding relationships" do
    test "loads bindings through element relationship", %{element: element, screen: screen} do
      # Create bindings
      Enum.each(1..3, fn i ->
        attrs = %{
          source: %{"field" => "field_#{i}"},
          target: "target_#{i}",
          binding_type: :value,
          element_id: element.id,
          screen_id: screen.id
        }

        AshUI.Domain.create(Binding, attrs: attrs)
      end)

      # Load element with bindings
      element_with_bindings =
        AshUI.Domain.read_one!(Element,
          filter: [id: element.id],
          load: [:bindings]
        )

      assert length(element_with_bindings.bindings) == 3
    end
  end

  describe "Cascade delete behavior" do
    test "deleting screen cascades to elements and bindings", %{
      screen: screen,
      element: element
    } do
      # Create a binding
      attrs = %{
        source: %{"field" => "test"},
        target: "test_target",
        binding_type: :value,
        element_id: element.id,
        screen_id: screen.id
      }

      {:ok, binding} = AshUI.Domain.create(Binding, attrs: attrs)

      # Delete screen
      :ok = AshUI.Domain.destroy(screen)

      # Element should be deleted
      assert [] = AshUI.Domain.read!(Element, filter: [id: element.id])

      # Binding should be deleted
      assert [] = AshUI.Domain.read!(Binding, filter: [id: binding.id])
    end
  end
end
