defmodule AshUI.Runtime.BidirectionalBindingTest do
  use AshUI.DataCase, async: false

  alias AshUI.Runtime.BidirectionalBinding

  describe "read_binding/2" do
    test "reads binding value and updates socket assigns" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{ash_ui: %{}}
      }

      binding = %{
        id: "binding-read-test",
        source: %{"resource" => "User", "field" => "name"},
        target: "name-input",
        binding_type: :value
      }

      context = %{user_id: "user-1", params: %{}, assigns: %{}}

      assert {:ok, updated_socket} = BidirectionalBinding.read_binding(binding, socket, context)
      assert updated_socket != socket
    end
  end

  describe "write_binding/4" do
    test "writes user input back to Ash resource" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{ash_ui: %{}}
      }

      binding = %{
        id: "binding-write-test",
        source: %{"resource" => "User", "field" => "name"},
        target: "name-input",
        binding_type: :value
      }

      context = %{user_id: "user-1", params: %{}, assigns: %{}}
      new_value = "Updated Name"

      assert {:ok, _socket, result} = BidirectionalBinding.write_binding(binding, new_value, socket, context)
      assert result.status == :ok
    end

    test "validates input before writing" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{ash_ui: %{}}
      }

      binding = %{
        id: "binding-validate-test",
        source: %{"resource" => "User", "field" => "email"},
        target: "email-input",
        binding_type: :value,
        transform: %{"validate" => [%{"type" => "required"}]}
      }

      context = %{user_id: "user-1", params: %{}, assigns: %{}}

      # Empty string should fail required validation
      assert {:error, _reason, _socket} = BidirectionalBinding.write_binding(binding, "", socket, context)
    end
  end

  describe "subscribe_binding/3" do
    test "subscribes to resource changes" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{ash_ui: %{}}
      }

      binding = %{
        id: "binding-subscribe-test",
        source: %{"resource" => "User", "field" => "name"},
        target: "name-input",
        binding_type: :value
      }

      context = %{user_id: "user-1", params: %{}, assigns: %{}}

      assert {:ok, updated_socket} = BidirectionalBinding.subscribe_binding(binding, socket, context)

      subscriptions = get_in(updated_socket.assigns, [:ash_ui, :subscriptions])
      assert is_map(subscriptions)
    end
  end
end
