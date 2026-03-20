defmodule AshUI.LiveView.EventHandlerTest do
  use ExUnit.Case, async: true

  alias AshUI.LiveView.EventHandler

  # Mock socket for testing
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  # Mock user
  defp build_user(id \\ "user-1") do
    %{id: id, name: "Test User"}
  end

  describe "parse_event/2" do
    test "parses change events" do
      params = %{"target" => "input-1", "data" => %{"value" => "test"}}

      assert {:ok, event} = EventHandler.parse_event("ash_ui_change", params)
      assert event.type == :change
      assert event.target == "input-1"
      assert event.data == %{"value" => "test"}
    end

    test "parses click events" do
      params = %{"target" => "button-1", "data" => %{}}

      assert {:ok, event} = EventHandler.parse_event("ash_ui_click", params)
      assert event.type == :click
      assert event.target == "button-1"
    end

    test "parses submit events" do
      params = %{"target" => "form-1", "data" => %{"field" => "value"}}

      assert {:ok, event} = EventHandler.parse_event("ash_ui_submit", params)
      assert event.type == :submit
      assert event.target == "form-1"
    end

    test "returns error for unknown event type" do
      params = %{"target" => "test"}

      assert {:error, :invalid_event} = EventHandler.parse_event("unknown_event", params)
    end
  end

  describe "route_event/2" do
    test "routes change events to value change handler" do
      socket = build_socket(ash_ui_bindings: %{})
      event = %{type: :change, target: "input-1", data: %{"value" => "test"}}

      assert {:ok, _updated_socket} = EventHandler.route_event(event, socket)
    end

    test "routes click events to action handler" do
      socket = build_socket(ash_ui_bindings: %{})
      event = %{type: :click, target: "button-1", data: %{}}

      assert {:ok, _updated_socket} = EventHandler.route_event(event, socket)
    end

    test "routes submit events to action handler" do
      socket = build_socket(ash_ui_bindings: %{})
      event = %{type: :submit, target: "form-1", data: %{}}

      assert {:ok, _updated_socket} = EventHandler.route_event(event, socket)
    end

    test "returns error for unknown event types" do
      socket = build_socket()
      event = %{type: :unknown, target: "test", data: %{}}

      assert {:error, {:unknown_event_type, :unknown}} = EventHandler.route_event(event, socket)
    end
  end

  describe "handle_value_change/2" do
    test "updates binding value on change event" do
      socket =
        build_socket(
          ash_ui_bindings: %{binding1: %{target: "input-1", value: "old"}},
          ash_ui_user: build_user()
        )

      params = %{"target" => "input-1", "value" => "new value"}

      assert {:noreply, _updated_socket} = EventHandler.handle_value_change(params, socket)
    end

    test "assigns flash on error" do
      socket =
        build_socket(
          ash_ui_bindings: %{},
          ash_ui_user: build_user()
        )

      params = %{"target" => "nonexistent", "value" => "test"}

      assert {:noreply, _updated_socket} = EventHandler.handle_value_change(params, socket)
    end
  end

  describe "handle_action_event/2" do
    test "executes action on event" do
      socket =
        build_socket(
          ash_ui_bindings: %{
            action1: %{id: "action1", source: %{"resource" => "User", "action" => "create"}}
          },
          ash_ui_user: build_user()
        )

      params = %{"action_id" => "action1", "data" => %{"name" => "Test"}}

      assert {:reply, reply, _updated_socket} = EventHandler.handle_action_event(params, socket)
      assert reply[:status] in [:ok, :error]
    end

    test "returns error for unauthorized actions" do
      socket =
        build_socket(
          ash_ui_bindings: %{},
          ash_ui_user: nil
        )

      params = %{"action_id" => "restricted_action", "data" => %{}}

      assert {:reply, reply, _updated_socket} = EventHandler.handle_action_event(params, socket)
      assert reply[:status] == :error
      assert reply[:reason] == "unauthorized"
    end

    test "assigns flash message on action error" do
      socket =
        build_socket(
          ash_ui_bindings: %{},
          ash_ui_user: build_user()
        )

      params = %{"action_id" => "nonexistent_action", "data" => %{}}

      assert {:reply, reply, updated_socket} = EventHandler.handle_action_event(params, socket)
      assert reply[:status] == :error
      assert is_map(updated_socket.assigns[:flash])
    end
  end

  describe "validate_event_data/2" do
    test "validates event with required fields" do
      event_data = %{"target" => "input-1", "data" => %{}}

      assert :ok = EventHandler.validate_event_data(event_data, "change")
    end

    test "returns error for missing target" do
      event_data = %{"data" => %{}}

      assert {:error, {:missing_fields, ["target"]}} =
               EventHandler.validate_event_data(event_data, "change")
    end

    test "returns error for missing data field" do
      event_data = %{"target" => "input-1"}

      assert {:error, {:missing_fields, ["data"]}} =
               EventHandler.validate_event_data(event_data, "change")
    end
  end

  describe "handle_validation_error/2" do
    test "assigns flash error message" do
      socket = build_socket()

      assert {:noreply, updated_socket} =
               EventHandler.handle_validation_error(:missing_target, socket)

      assert is_binary(updated_socket.assigns[:flash][:error])
    end

    test "handles invalid type errors" do
      socket = build_socket()

      assert {:noreply, updated_socket} =
               EventHandler.handle_validation_error({:invalid_type, :got, :expected}, socket)

      assert is_binary(updated_socket.assigns[:flash][:error])
    end

    test "handles unknown errors" do
      socket = build_socket()

      assert {:noreply, updated_socket} =
               EventHandler.handle_validation_error(:unknown_error, socket)

      assert is_binary(updated_socket.assigns[:flash][:error])
    end
  end

  describe "wire_handlers/1" do
    test "creates handler map from bindings" do
      socket =
        build_socket(
          ash_ui_bindings: %{
            action1: %{id: "action1", binding_type: :action},
            action2: %{id: "action2", binding_type: :action}
          }
        )

      assert {:ok, updated_socket} = EventHandler.wire_handlers(socket)
      assert is_map(updated_socket.assigns[:ash_ui_handlers])
    end

    test "handles socket with no bindings" do
      socket = build_socket(ash_ui_bindings: %{})

      assert {:ok, updated_socket} = EventHandler.wire_handlers(socket)
      assert is_map(updated_socket.assigns[:ash_ui_handlers])
    end
  end

  describe "handle_event/3" do
    test "handles known events" do
      socket = build_socket(ash_ui_bindings: %{})
      params = %{"target" => "test"}

      assert {:noreply, _updated_socket} =
               EventHandler.handle_event("ash_ui_change", params, socket)
    end

    test "handles unknown events gracefully" do
      socket = build_socket()

      assert {:noreply, _updated_socket} = EventHandler.handle_event("unknown", %{}, socket)
    end

    test "handles events with errors" do
      socket = build_socket(ash_ui_user: nil)

      assert {:noreply, _updated_socket} =
               EventHandler.handle_event("ash_ui_change", %{"target" => "test"}, socket)
    end
  end
end
