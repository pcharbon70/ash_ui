defmodule AshUI.Runtime.ActionBindingTest do
  use ExUnit.Case, async: true

  alias AshUI.Runtime.ActionBinding

  describe "execute_action/4" do
    setup do
      context = %{
        user_id: "user-1",
        params: %{},
        assigns: %{}
      }

      binding = %{
        id: "action-binding-test",
        source: %{"resource" => "User", "action" => "create"},
        target: "submit-button",
        binding_type: :action
      }

      %{binding: binding, context: context}
    end

    test "executes action with event data", %{binding: binding, context: context} do
      event_data = %{"name" => "John", "email" => "john@example.com"}

      assert {:ok, result} = ActionBinding.execute_action(binding, event_data, context)
      assert result.status == :ok
      assert result.data != nil
    end

    test "returns error for unauthorized action", %{binding: binding} do
      unauthorized_context = %{user_id: nil, params: %{}, assigns: %{}}

      assert {:error, _reason} = ActionBinding.execute_action(binding, %{}, unauthorized_context)
    end
  end

  describe "event_handler/2" do
    test "generates LiveView event handler" do
      binding = %{
        id: "handler-test",
        source: %{"resource" => "User", "action" => "delete"},
        target: "delete-button",
        binding_type: :action
      }

      handler = ActionBinding.event_handler(binding, "button-1")

      assert is_function(handler)
    end
  end

  describe "wire_handlers/2" do
    test "creates handler map from action bindings" do
      socket = %{assigns: %{}}

      bindings = [
        %{
          id: "action-1",
          source: %{"resource" => "User", "action" => "create"},
          target: "create-btn",
          binding_type: :action
        },
        %{
          id: "action-2",
          source: %{"resource" => "Post", "action" => "delete"},
          target: "delete-btn",
          binding_type: :action
        },
        # Non-action binding should be excluded
        %{
          id: "value-1",
          source: %{"resource" => "User", "field" => "name"},
          target: "name-input",
          binding_type: :value
        }
      ]

      handlers = ActionBinding.wire_handlers(bindings, socket)

      assert map_size(handlers) == 2
      assert Enum.all?(handlers, fn {_, handler} -> is_function(handler) end)
    end
  end
end
