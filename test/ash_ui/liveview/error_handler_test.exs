defmodule AshUI.LiveView.ErrorHandlerTest do
  use ExUnit.Case, async: true

  alias AshUI.LiveView.ErrorHandler

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

  # Mock screen
  defp build_screen(id \\ "screen-1") do
    %{id: id, name: "Test Screen"}
  end

  describe "handle_compilation_error/2" do
    test "assigns error info to socket" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      assert {:error, socket} = ErrorHandler.handle_compilation_error(:not_found, socket)
      assert socket.assigns[:ash_ui_error] != nil
    end

    test "enables retry for transient errors" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      assert {:error, socket} =
               ErrorHandler.handle_compilation_error({:timeout, 5000}, socket)

      assert socket.assigns[:ash_ui_can_retry] == true
    end

    test "does not enable retry for permanent errors" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      assert {:error, socket} = ErrorHandler.handle_compilation_error(:not_found, socket)
      refute Map.has_key?(socket.assigns, :ash_ui_can_retry)
    end
  end

  describe "handle_binding_error/3" do
    test "stores binding error in socket" do
      socket = build_socket(ash_ui_user: build_user())
      binding = %{id: "binding-1"}

      assert {:error, _reason} =
               ErrorHandler.handle_binding_error(binding, :not_found, socket)

      # Error should be stored in binding errors
      assert socket.assigns[:ash_ui_binding_errors] != nil
    end

    test "returns error tuple" do
      socket = build_socket()
      binding = %{id: "binding-1"}

      assert {:error, :not_found} = ErrorHandler.handle_binding_error(binding, :not_found, socket)
    end
  end

  describe "handle_action_error/2" do
    test "assigns flash error message" do
      socket = build_socket()

      assert {:error, socket} = ErrorHandler.handle_action_error(:validation_failed, socket)
      assert socket.assigns[:flash][:error] != nil
    end

    test "formats validation errors" do
      socket = build_socket()

      validation_error = {:validation, [{:name, {"is required", []}}]}

      assert {:error, socket} = ErrorHandler.handle_action_error(validation_error, socket)
      assert String.contains?(socket.assigns[:flash][:error], "Invalid input")
    end
  end

  describe "handle_auth_error/2" do
    test "returns unauthorized error" do
      socket = build_socket()

      assert {:error, :unauthorized} =
               ErrorHandler.handle_auth_error({:error, :unauthorized}, socket)
    end
  end

  describe "handle_runtime_error/3" do
    test "stores error info in socket" do
      socket = build_socket()

      exception = RuntimeError.exception("Test error")
      socket = ErrorHandler.handle_runtime_error(exception, [], socket)

      assert socket.assigns[:ash_ui_error] != nil
      assert socket.assigns[:ash_ui_error].type == :runtime
    end

    test "includes stacktrace in error info" do
      socket = build_socket()

      exception = RuntimeError.exception("Test error")
      socket = ErrorHandler.handle_runtime_error(exception, [{:line, 1}], socket)

      # Error should be stored
      assert socket.assigns[:ash_ui_error] != nil
    end
  end

  describe "determine_recovery/1" do
    test "returns retry for timeout errors" do
      error_info = %{type: :compilation, reason: {:timeout, 5000}}
      assert ErrorHandler.determine_recovery(error_info) == :retry
    end

    test "returns retry for temporary errors" do
      error_info = %{type: :compilation, reason: {:temporary, "unavailable"}}
      assert ErrorHandler.determine_recovery(error_info) == :retry
    end

    test "returns abort for permanent compilation errors" do
      error_info = %{type: :compilation, reason: :not_found}
      assert ErrorHandler.determine_recovery(error_info) == :abort
    end

    test "returns fallback for binding not found" do
      error_info = %{type: :binding, reason: {:not_found, "Resource"}}
      assert ErrorHandler.determine_recovery(error_info) == :fallback
    end

    test "returns skip for unauthorized binding" do
      error_info = %{type: :binding, reason: {:unauthorized, "No permission"}}
      assert ErrorHandler.determine_recovery(error_info) == :skip
    end

    test "returns skip for validation errors" do
      error_info = %{type: :action, reason: {:validation, []}}
      assert ErrorHandler.determine_recovery(error_info) == :skip
    end

    test "returns retry for conflict errors" do
      error_info = %{type: :action, reason: {:conflict, "Record changed"}}
      assert ErrorHandler.determine_recovery(error_info) == :retry
    end

    test "returns abort for authorization errors" do
      error_info = %{type: :authorization, reason: :unauthorized}
      assert ErrorHandler.determine_recovery(error_info) == :abort
    end

    test "returns abort for runtime errors" do
      error_info = %{type: :runtime, reason: %RuntimeError{}}
      assert ErrorHandler.determine_recovery(error_info) == :abort
    end
  end

  describe "user_friendly_message/1" do
    test "formats timeout errors" do
      error_info = %{type: :compilation, reason: {:timeout, 5000}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "taking too long")
    end

    test "formats not found errors" do
      error_info = %{type: :compilation, reason: {:not_found, "Screen"}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "not found")
    end

    test "formats binding not found errors" do
      error_info = %{type: :binding, reason: {:not_found, "Profile"}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "could not be found")
    end

    test "formats unauthorized binding errors" do
      error_info = %{type: :binding, reason: {:unauthorized, "No permission"}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "permission")
    end

    test "formats validation errors" do
      error_info = %{type: :action, reason: {:validation, [{:name, {"is required", []}}]}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "Invalid input")
    end

    test "formats conflict errors" do
      error_info = %{type: :action, reason: {:conflict, "Record changed"}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "modified by someone else")
    end

    test "formats authorization errors" do
      error_info = %{type: :authorization, reason: :unauthorized}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "permission")
    end

    test "formats runtime errors" do
      error_info = %{type: :runtime, reason: %RuntimeError{}}
      message = ErrorHandler.user_friendly_message(error_info)

      assert String.contains?(message, "unexpected error")
    end
  end

  describe "recoverable?/1" do
    test "returns true for retry errors" do
      error_info = %{type: :compilation, reason: {:timeout, 5000}}
      assert ErrorHandler.recoverable?(error_info) == true
    end

    test "returns true for fallback errors" do
      error_info = %{type: :binding, reason: {:not_found, "Resource"}}
      assert ErrorHandler.recoverable?(error_info) == true
    end

    test "returns true for skip errors" do
      error_info = %{type: :action, reason: {:validation, []}}
      assert ErrorHandler.recoverable?(error_info) == true
    end

    test "returns false for abort errors" do
      error_info = %{type: :authorization, reason: :unauthorized}
      assert ErrorHandler.recoverable?(error_info) == false
    end
  end

  describe "get_fallback/2" do
    test "returns user-defined fallback" do
      binding = %{id: "binding-1", fallback: "default value"}
      error_info = %{type: :binding, reason: {:not_found, "Resource"}}

      assert {:ok, "default value"} = ErrorHandler.get_fallback(binding, error_info)
    end

    test "returns nil default for binding errors" do
      binding = %{id: "binding-1"}
      error_info = %{type: :binding, reason: {:not_found, "Resource"}}

      assert {:ok, nil} = ErrorHandler.get_fallback(binding, error_info)
    end

    test "returns error for non-binding errors" do
      binding = %{id: "binding-1"}
      error_info = %{type: :authorization, reason: :unauthorized}

      assert :error = ErrorHandler.get_fallback(binding, error_info)
    end
  end

  describe "retry_with_backoff/2" do
    test "succeeds on first attempt" do
      operation = fn -> {:ok, :success} end

      assert {:ok, :success} = ErrorHandler.retry_with_backoff(operation)
    end

    test "retries on failure" do
      attempts = :atomics.new(1, [])
      :atomics.put(attempts, 1, 0)

      operation = fn ->
        count = :atomics.increment_get(attempts, 1)
        if count < 3, do: {:error, :retry}, else: {:ok, :success}
      end

      assert {:ok, :success} = ErrorHandler.retry_with_backoff(operation, max_attempts: 3)
    end

    test "exceeds max attempts" do
      operation = fn -> {:error, :permanent} end

      assert {:error, :max_attempts_exceeded} =
               ErrorHandler.retry_with_backoff(operation, max_attempts: 2)
    end

    test "respects custom max attempts" do
      operation = fn -> {:error, :retry} end

      assert {:error, :max_attempts_exceeded} =
               ErrorHandler.retry_with_backoff(operation, max_attempts: 5)
    end
  end
end
