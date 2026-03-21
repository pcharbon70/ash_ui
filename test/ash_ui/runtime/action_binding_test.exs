defmodule AshUI.Runtime.ActionBindingTest do
  use ExUnit.Case, async: true

  alias AshUI.Runtime.ActionBinding
  alias AshUI.Test.RuntimeDomain
  alias AshUI.Test.RuntimeFixtures
  alias AshUI.Test.User

  describe "execute_action/4" do
    setup do
      fixtures = RuntimeFixtures.seed!()

      binding = %{
        id: "action-binding-test",
        source: %{"resource" => "User", "action" => "create"},
        target: "submit-button",
        binding_type: :action,
        transform: %{
          "params" => %{
            "name" => {"event", "name"},
            "email" => {"event", "email"},
            "nickname" => {"static", "Created"}
          }
        }
      }

      %{binding: binding, context: RuntimeFixtures.context(fixtures)}
    end

    test "executes an Ash create action with mapped event data", %{
      binding: binding,
      context: context
    } do
      event_data = %{"name" => "John", "email" => "john@example.com"}

      assert {:ok, result} = ActionBinding.execute_action(binding, event_data, context)
      assert result.status == :ok
      assert %User{} = result.data
      assert result.data.name == "John"
      assert result.data.nickname == "Created"
    end

    test "returns a formatted error for unauthorized actions", %{binding: binding} do
      unauthorized_context = %{user_id: nil, params: %{}, assigns: %{}, ash_domains: [RuntimeDomain]}

      assert {:error, error} = ActionBinding.execute_action(binding, %{}, unauthorized_context)
      assert error.status == :error
      assert error.errors == [%{"message" => "Unauthorized"}]
    end
  end

  describe "event_handler/2" do
    test "executes the bound action from a LiveView-style handler" do
      fixtures = RuntimeFixtures.seed!()

      binding = %{
        id: "handler-test",
        source: %{"resource" => "User", "action" => "create"},
        target: "create-user",
        binding_type: :action,
        metadata: %{"success_message" => "Created"},
        transform: %{
          "params" => %{
            "name" => {"event", "name"},
            "email" => {"event", "email"}
          }
        }
      }

      handler = ActionBinding.event_handler(binding, "button-1")
      socket = RuntimeFixtures.socket(current_user: fixtures.actor)

      assert {:noreply, updated_socket} =
               handler.(socket, %{"name" => "Handler User", "email" => "handler@example.com"}, %{})

      assert get_in(updated_socket.assigns, [:ash_ui, :actions, "create-user", "result", :status]) == :ok
      assert get_in(updated_socket.assigns, [:flash, :info]) == ["Created"]
    end
  end

  describe "wire_handlers/2" do
    test "creates handler map from action bindings" do
      socket = RuntimeFixtures.socket()

      bindings = [
        %{
          id: "action-1",
          source: %{"resource" => "User", "action" => "create"},
          target: "create-btn",
          binding_type: :action
        },
        %{
          id: "value-1",
          source: %{"resource" => "User", "field" => "name"},
          target: "name-input",
          binding_type: :value
        }
      ]

      handlers = ActionBinding.wire_handlers(bindings, socket)

      assert Map.keys(handlers) == ["ash_ui_action_create-btn"]
      assert is_function(handlers["ash_ui_action_create-btn"])
    end
  end
end
