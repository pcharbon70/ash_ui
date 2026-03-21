defmodule AshUI.LiveView.ErrorHandler do
  @moduledoc """
  Error handling and recovery for Ash UI LiveView integration.

  Provides graceful error handling for runtime failures including
  compilation errors, binding errors, and action failures.
  """

  require Logger

  alias AshUI.Telemetry

  @type error_info :: %{
          type: atom(),
          reason: term(),
          message: String.t(),
          timestamp: DateTime.t(),
          context: map()
        }

  @type recovery_strategy :: :retry | :fallback | :skip | :abort

  @doc """
  Handles compilation errors during screen mounting.

  Displays a user-friendly error message and logs detailed
  information for debugging.

  ## Examples

      case AshUI.LiveView.Integration.compile_screen(screen) do
        {:ok, iur} -> {:ok, iur}
        {:error, reason} -> ErrorHandler.handle_compilation_error(reason, socket)
      end
  """
  @spec handle_compilation_error(term(), Phoenix.LiveView.Socket.t()) ::
          {:error, Phoenix.LiveView.Socket.t()}
  def handle_compilation_error(reason, socket) do
    error_info = build_error_info(:compilation, reason, socket)

    # Log detailed error for debugging
    log_compilation_error(error_info)

    # Emit error telemetry
    emit_error_telemetry(error_info)

    # Assign user-friendly error to socket
    socket = assign_error(socket, error_info)

    # Optionally provide retry option
    socket = maybe_enable_retry(socket, error_info)

    {:error, socket}
  end

  @doc """
  Handles binding evaluation errors.

  Displays placeholder or error state in UI while continuing
  to render the rest of the screen.

  ## Examples

      case BindingEvaluator.evaluate(binding, context) do
        {:ok, value} -> value
        {:error, reason} -> ErrorHandler.handle_binding_error(binding, reason, socket)
      end
  """
  @spec handle_binding_error(map(), term(), Phoenix.LiveView.Socket.t()) ::
          {:error, term(), Phoenix.LiveView.Socket.t()}
  def handle_binding_error(binding, reason, socket) do
    error_info = build_error_info(:binding, reason, socket, binding: binding)

    # Log binding error
    log_binding_error(error_info)

    # Emit error telemetry
    emit_error_telemetry(error_info)

    # Store error in binding state for UI to handle
    updated_socket = store_binding_error(socket, binding, error_info)

    {:error, reason, updated_socket}
  end

  @doc """
  Handles action execution errors.

  Displays feedback to the user about what went wrong.

  ## Examples

      case ActionBinding.execute_action(binding, data, context) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> ErrorHandler.handle_action_error(reason, socket)
      end
  """
  @spec handle_action_error(term(), Phoenix.LiveView.Socket.t()) ::
          {:error, Phoenix.LiveView.Socket.t()}
  def handle_action_error(reason, socket) do
    error_info = build_error_info(:action, reason, socket)

    # Log action error
    log_action_error(error_info)

    # Emit error telemetry
    emit_error_telemetry(error_info)

    # Assign error message to flash for display
    socket = assign_flash_error(socket, error_info)

    {:error, socket}
  end

  @doc """
  Handles authorization errors.

  Redirects to login or displays unauthorized message.

  ## Examples

      case AshUI.LiveView.Integration.authorize_screen(screen, user) do
        :ok -> :ok
        {:error, :unauthorized} = error -> ErrorHandler.handle_auth_error(error, socket)
      end
  """
  @spec handle_auth_error({:error, :unauthorized}, Phoenix.LiveView.Socket.t()) ::
          {:error, term()}
  def handle_auth_error({:error, :unauthorized}, socket) do
    error_info = build_error_info(:authorization, :unauthorized, socket)

    # Log auth failure
    log_auth_error(error_info)

    # Emit auth failure telemetry
    emit_error_telemetry(error_info)

    # In production, would redirect to login
    {:error, :unauthorized}
  end

  @doc """
  Handles general runtime errors.

  Catches unexpected errors during LiveView operation.

  ## Examples

      try do
        risky_operation()
      rescue
        e -> ErrorHandler.handle_runtime_error(e, __STACKTRACE__, socket)
      end
  """
  @spec handle_runtime_error(Exception.t(), list(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_runtime_error(exception, stacktrace, socket) do
    error_info =
      build_error_info(:runtime, exception, socket, %{
        stacktrace: format_stacktrace(stacktrace)
      })

    # Log runtime error
    log_runtime_error(error_info)

    # Emit error telemetry
    emit_error_telemetry(error_info)

    # Store error for display
    assign_error(socket, error_info)
  end

  @doc """
  Determines recovery strategy for an error.

  ## Strategies
    * `:retry` - Retry the operation (transient errors)
    * `:fallback` - Use fallback value
    * `:skip` - Skip the operation and continue
    * `:abort` - Abort and show error

  ## Examples

      case ErrorHandler.determine_recovery(error_info) do
        :retry -> # retry logic
        :fallback -> # use fallback
        :skip -> # skip operation
        :abort -> # show error
      end
  """
  @spec determine_recovery(error_info()) :: recovery_strategy()
  def determine_recovery(%{type: :compilation, reason: reason}) do
    case reason do
      {:timeout, _} -> :retry
      {:temporary, _} -> :retry
      _ -> :abort
    end
  end

  def determine_recovery(%{type: :binding, reason: reason}) do
    case reason do
      {:not_found, _} -> :fallback
      {:unauthorized, _} -> :skip
      _ -> :fallback
    end
  end

  def determine_recovery(%{type: :action, reason: reason}) do
    case reason do
      {:validation, _} -> :skip
      {:conflict, _} -> :retry
      _ -> :skip
    end
  end

  def determine_recovery(%{type: :authorization}) do
    :abort
  end

  def determine_recovery(%{type: :runtime}) do
    :abort
  end

  @doc """
  Retries an operation with exponential backoff.

  ## Examples

      ErrorHandler.retry_with_backoff(fn ->
        Ash.get(Screen, screen_id)
      end, max_attempts: 3)
  """
  @spec retry_with_backoff(fun(), keyword()) :: {:ok, term()} | {:error, term()}
  def retry_with_backoff(operation, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay = Keyword.get(opts, :base_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 5000)

    retry_with_backoff(operation, 0, max_attempts, base_delay, max_delay)
  end

  @doc """
  Creates a user-friendly error message from error info.

  ## Examples

      message = ErrorHandler.user_friendly_message(error_info)
  """
  @spec user_friendly_message(error_info()) :: String.t()
  def user_friendly_message(%{type: :compilation, reason: reason}) do
    case reason do
      {:timeout, _} -> "The screen is taking too long to load. Please try again."
      {:not_found, _} -> "The requested screen was not found."
      _ -> "Unable to load the screen. Please try again later."
    end
  end

  def user_friendly_message(%{type: :binding, reason: reason}) do
    case reason do
      {:not_found, _resource} -> "The requested data could not be found."
      {:unauthorized, _} -> "You don't have permission to view this data."
      _ -> "Unable to load some data. Please refresh the page."
    end
  end

  def user_friendly_message(%{type: :action, reason: reason}) do
    case reason do
      {:validation, errors} -> "Invalid input: #{format_validation_errors(errors)}"
      {:conflict, _} -> "This record was modified by someone else. Please refresh and try again."
      _ -> "The action could not be completed. Please try again."
    end
  end

  def user_friendly_message(%{type: :authorization}) do
    "You don't have permission to access this resource."
  end

  def user_friendly_message(%{type: :runtime}) do
    "An unexpected error occurred. Please try again."
  end

  @doc """
  Checks if an error is recoverable.

  ## Examples

      if ErrorHandler.recoverable?(error_info) do
        # attempt recovery
      end
  """
  @spec recoverable?(error_info()) :: boolean()
  def recoverable?(error_info) do
    determine_recovery(error_info) in [:retry, :fallback, :skip]
  end

  @doc """
  Gets a fallback value for a failed binding.

  ## Examples

      value = case ErrorHandler.get_fallback(binding, error_info) do
        {:ok, fallback} -> fallback
        :error -> nil
      end
  """
  @spec get_fallback(map(), error_info()) :: {:ok, term()} | :error
  def get_fallback(binding, error_info) do
    # Check for user-defined fallback
    case Map.get(binding, :fallback) do
      nil -> default_fallback(error_info)
      fallback -> {:ok, fallback}
    end
  end

  # Private functions

  defp build_error_info(type, reason, socket, extra_context \\ %{}) do
    extra_context =
      case extra_context do
        extra when is_list(extra) -> Enum.into(extra, %{})
        extra when is_map(extra) -> extra
      end

    base_context = %{
      screen_id: get_screen_id(socket),
      user_id: get_user_id(socket),
      session_id: get_session_id(socket)
    }

    %{
      type: type,
      reason: reason,
      message: format_error_message(reason),
      timestamp: DateTime.utc_now(),
      context: Map.merge(base_context, extra_context)
    }
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)

  defp format_stacktrace(stacktrace) do
    Exception.format_stacktrace(stacktrace)
  rescue
    FunctionClauseError -> inspect(stacktrace)
  end

  defp get_screen_id(socket) do
    case socket.assigns[:ash_ui_screen] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp get_user_id(socket) do
    case socket.assigns[:ash_ui_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp get_session_id(socket) do
    Map.get(socket.assigns, :ash_ui_session_id)
  end

  defp log_compilation_error(error_info) do
    Logger.error("""
    [Ash UI] Compilation error:
    Type: #{error_info.type}
    Reason: #{inspect(error_info.reason)}
    Screen: #{error_info.context.screen_id}
    User: #{error_info.context.user_id}
    """)
  end

  defp log_binding_error(error_info) do
    Logger.warning("""
    [Ash UI] Binding evaluation error:
    Type: #{error_info.type}
    Reason: #{inspect(error_info.reason)}
    Binding: #{inspect(error_info.context[:binding])}
    """)
  end

  defp log_action_error(error_info) do
    Logger.error("""
    [Ash UI] Action execution error:
    Type: #{error_info.type}
    Reason: #{inspect(error_info.reason)}
    """)
  end

  defp log_auth_error(error_info) do
    Logger.warning("""
    [Ash UI] Authorization error:
    Type: #{error_info.type}
    Screen: #{error_info.context.screen_id}
    User: #{error_info.context.user_id}
    """)
  end

  defp log_runtime_error(error_info) do
    Logger.error("""
    [Ash UI] Runtime error:
    Type: #{error_info.type}
    Reason: #{inspect(error_info.reason)}
    #{error_info.context.stacktrace}
    """)
  end

  defp emit_error_telemetry(error_info) do
    Telemetry.execute(
      [:ash_ui, :error, error_info.type],
      %{count: 1},
      %{
        error: inspect(error_info.reason),
        reason: inspect(error_info.reason),
        resource_type: :screen,
        screen_id: error_info.context.screen_id,
        user_id: error_info.context.user_id,
        status: :error
      }
    )
  end

  defp assign_error(socket, error_info) do
    Phoenix.Component.assign(socket, :ash_ui_error, %{
      type: error_info.type,
      message: user_friendly_message(error_info),
      timestamp: error_info.timestamp
    })
  end

  defp assign_flash_error(socket, error_info) do
    message = user_friendly_message(error_info)
    current_flashes = Map.get(socket.assigns, :flash, %{})
    updated = Map.put(current_flashes, :error, message)
    %{socket | assigns: Map.put(socket.assigns, :flash, updated)}
  end

  defp store_binding_error(socket, binding, error_info) do
    binding_errors = Map.get(socket.assigns, :ash_ui_binding_errors, %{})
    binding_id = Map.get(binding, :id) || Map.get(binding, "id")
    updated = Map.put(binding_errors, binding_id, error_info)
    Phoenix.Component.assign(socket, :ash_ui_binding_errors, updated)
  end

  defp maybe_enable_retry(socket, error_info) do
    if recoverable?(error_info) and determine_recovery(error_info) == :retry do
      Phoenix.Component.assign(socket, :ash_ui_can_retry, true)
    else
      socket
    end
  end

  defp retry_with_backoff(_operation, attempt, max_attempts, _base_delay, _max_delay)
       when attempt >= max_attempts do
    {:error, :max_attempts_exceeded}
  end

  defp retry_with_backoff(operation, attempt, max_attempts, base_delay, max_delay) do
    case operation.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = _error ->
        delay = min((base_delay * :math.pow(2, attempt)) |> trunc(), max_delay)
        Process.sleep(delay)
        retry_with_backoff(operation, attempt + 1, max_attempts, base_delay, max_delay)
    end
  end

  defp format_validation_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(fn
      {field, {message, _}} -> "#{field}: #{message}"
      {field, message} -> "#{field}: #{message}"
    end)
    |> Enum.join(", ")
  end

  defp format_validation_errors(error), do: inspect(error)

  defp default_fallback(%{type: :binding}) do
    {:ok, nil}
  end

  defp default_fallback(_), do: :error
end
