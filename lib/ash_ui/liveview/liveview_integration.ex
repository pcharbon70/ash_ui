defmodule AshUI.LiveView.Integration do
  @moduledoc """
  LiveView integration layer for Ash UI screens.

  This module provides helpers and callbacks for integrating Ash UI screens
  with Phoenix LiveView, handling mount, update, and event handling.
  """

  require Logger

  alias AshUI.Compiler
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Binding
  alias AshUI.Runtime.BindingEvaluator
  alias AshUI.Rendering.IURAdapter

  @type screen_identifier :: String.t() | atom() | integer()
  @type mount_params :: map()
  @type mount_result :: {:ok, Phoenix.LiveView.Socket.t()} | {:error, term()}

  @doc """
  Mounts a UI screen in LiveView.

  Loads the screen resource, authorizes access, compiles to IUR,
  evaluates bindings, and assigns everything to the socket.

  ## Parameters
    * `socket` - LiveView socket
    * `screen_id` - Screen identifier (name, ID, or atom)
    * `params` - Optional parameters for screen loading

  ## Returns
    * `{:ok, socket}` - Screen mounted successfully
    * `{:error, reason}` - Mount failed

  ## Examples

      def mount(params, session, socket) do
        AshUI.LiveView.Integration.mount_ui_screen(socket, :dashboard, params)
      end
  """
  @spec mount_ui_screen(Phoenix.LiveView.Socket.t(), screen_identifier(), mount_params()) :: mount_result()
  def mount_ui_screen(socket, screen_id, params \\ %{}) do
    with {:ok, user} <- get_current_user(socket),
         {:ok, screen} <- load_screen(screen_id, user, params),
         :ok <- authorize_screen(screen, user),
         {:ok, iur} <- compile_screen(screen),
         {:ok, bindings} <- evaluate_bindings(screen, socket, user, params),
         socket <- assign_screen_state(socket, screen, iur, bindings, user) do
      {:ok, socket}
    else
      {:error, :unauthorized} ->
        {:error, :unauthorized}

      {:error, reason} ->
        Logger.error("Failed to mount screen #{inspect(screen_id)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Authorizes screen access for a user.

  Checks the `:mount` action policy for the screen resource.

  ## Returns
    * `:ok` - Authorized
    * `{:error, :unauthorized}` - Not authorized
  """
  @spec authorize_screen(Screen.t(), term()) :: :ok | {:error, :unauthorized}
  def authorize_screen(%Screen{} = screen, user) do
    # Check :mount action policy using Ash authorizer
    # In production, this would call Ash.can? with proper action
    case check_mount_policy(screen, user) do
      true -> :ok
      false -> {:error, :unauthorized}
    end
  end

  @doc """
  Compiles a screen resource to canonical IUR.

  ## Returns
    * `{:ok, iur}` - Compiled IUR structure
    * `{:error, reason}` - Compilation failed
  """
  @spec compile_screen(Screen.t()) :: {:ok, map()} | {:error, term()}
  def compile_screen(%Screen{} = screen) do
    with {:ok, iur} <- Compiler.compile(screen),
         {:ok, canonical_iur} <- IURAdapter.to_canonical(iur) do
      {:ok, canonical_iur}
    end
  end

  @doc """
  Evaluates all bindings for a screen.

  Loads and evaluates all bindings associated with the screen
  and its elements.

  ## Returns
    * `{:ok, binding_values}` - Map of binding IDs to evaluated values
    * `{:error, reason}` - Evaluation failed
  """
  @spec evaluate_bindings(Screen.t(), Phoenix.LiveView.Socket.t(), term(), map()) :: {:ok, map()} | {:error, term()}
  def evaluate_bindings(%Screen{} = screen, socket, user, params) do
    context = build_evaluation_context(socket, user, params)

    screen
    |> load_screen_bindings()
    |> evaluate_batch_bindings(context)
  end

  # Private functions

  defp get_current_user(socket) do
    case socket.assigns[:current_user] do
      nil -> {:error, :no_user}
      user -> {:ok, user}
    end
  end

  defp load_screen(screen_id, user, params) do
    # Load screen resource by ID or name
    # In production, would use Ash.get/3 with proper authorization
    case Ash.get(Screen, screen_id, actor: user, authorize?: true) do
      {:ok, screen} -> {:ok, screen}
      {:error, reason} -> {:error, reason}
    end
  rescue
    Ash.Error.Invalid.NoSuchResource -> {:error, :not_found}
  end

  defp check_mount_policy(%Screen{} = screen, user) do
    # Check if user can :mount this screen
    # In production, would use Ash.can?({:mount, screen}, user)
    case Ash.can?({:mount, screen}, user) do
      true -> true
      _ -> Ash.can?(screen, user, action: :mount)
    end
  rescue
    _ -> false
  end

  defp compile_screen(%Screen{} = screen) do
    with {:ok, iur} <- Compiler.compile(screen),
         {:ok, canonical_iur} <- IURAdapter.to_canonical(iur) do
      {:ok, canonical_iur}
    end
  end

  defp build_evaluation_context(socket, user, params) do
    %{
      user_id: get_user_id(user),
      user: user,
      params: params,
      assigns: socket.assigns,
      socket: socket
    }
  end

  defp get_user_id(user) do
    # Extract user ID from user struct/map
    case user do
      %{id: id} -> id
      user when is_binary(user) -> user
      _ -> nil
    end
  end

  defp load_screen_bindings(%Screen{} = screen) do
    # Load all bindings for this screen
    # In production, would use Ash.read/2 with proper filtering
    case Ash.read(Binding, filter: [screen_id: screen.id], authorize?: true) do
      {:ok, bindings} -> bindings
      {:error, _} -> []
    end
  rescue
    _ -> []
  end

  defp evaluate_batch_bindings(bindings, context) when is_list(bindings) do
    results =
      Enum.reduce(bindings, %{}, fn binding, acc ->
        case BindingEvaluator.evaluate(binding, context) do
          {:ok, value} ->
            Map.put(acc, binding.id, value)

          {:error, reason} ->
            Logger.warning("Binding #{binding.id} evaluation failed: #{inspect(reason)}")
            # Store error state for UI to handle
            Map.put(acc, binding.id, {:error, reason})
        end
      end)

    {:ok, results}
  end

  defp assign_screen_state(socket, screen, iur, bindings, user) do
    socket
    |> Phoenix.LiveView.assign(:ash_ui_screen, screen)
    |> Phoenix.LiveView.assign(:ash_ui_iur, iur)
    |> Phoenix.LiveView.assign(:ash_ui_bindings, bindings)
    |> Phoenix.LiveView.assign(:ash_ui_user, user)
    |> Phoenix.LiveView.assign(:ash_ui_loaded_at, DateTime.utc_now())
  end

  @doc """
  Redirects to login page when authorization fails.

  ## Examples

      case authorize_screen(screen, user) do
        :ok -> {:ok, socket}
        {:error, :unauthorized} = error ->
          AshUI.LiveView.Integration.redirect_to_login(socket, error)
      end
  """
  @spec redirect_to_login(Phoenix.LiveView.Socket.t(), term()) :: {:error, term()}
  def redirect_to_login(socket, _error) do
    # In production, would use Phoenix.LiveView.redirect/3
    # This is a placeholder for the redirect logic
    {:error, :unauthorized}
  end

  @doc """
  Emits telemetry events for screen operations.

  ## Events
    * `[:ash_ui, :screen, :mount]` - Screen mounted successfully
    * `[:ash_ui, :screen, :mount_error]` - Screen mount failed
    * `[:ash_ui, :screen, :auth_failure]` - Authorization failed

  ## Examples

      emit_telemetry(:mount, %{screen_id: screen.id}, %{})
  """
  def emit_telemetry(event, metadata, measurements \\ %{}) do
    :telemetry.execute(
      [:ash_ui, :screen, event],
      measurements,
      metadata
    )
  end
end
