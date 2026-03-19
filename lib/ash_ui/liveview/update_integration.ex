defmodule AshUI.LiveView.UpdateIntegration do
  @moduledoc """
  LiveView update integration for reactive data binding.

  Handles subscriptions to Ash resource changes and updates
  the LiveView when bound data changes.
  """

  require Logger

  alias AshUI.Resources.Binding
  alias AshUI.Runtime.BindingEvaluator
  alias AshUI.LiveView.Integration

  @type subscription :: %{
          id: String.t(),
          resource: module(),
          action: atom(),
          filter: map()
        }

  @type update_result :: {:noreply, Phoenix.LiveView.Socket.t()}

  @doc """
  Subscribes to Ash resource change notifications.

  ## Parameters
    * `socket` - LiveView socket
    * `resource` - Ash resource module to watch
    * `filter` - Optional filter for changes to watch

  ## Returns
    * `{:ok, subscription}` - Subscription created
    * `{:error, reason}` - Subscription failed

  ## Examples

      {:ok, sub} = UpdateIntegration.subscribe(socket, User.Profile, user_id: user.id)
  """
  @spec subscribe(Phoenix.LiveView.Socket.t(), module(), keyword()) :: {:ok, subscription()} | {:error, term()}
  def subscribe(socket, resource, opts \\ []) do
    filter = Keyword.get(opts, :filter, %{})
    action = Keyword.get(opts, :action, :update)

    subscription = %{
      id: generate_subscription_id(resource, filter),
      resource: resource,
      action: action,
      filter: filter
    }

    case subscribe_to_resource(resource, subscription) do
      :ok ->
        socket = track_subscription(socket, subscription)
        {:ok, subscription}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unsubscribes from a resource change notification.

  ## Examples

      UpdateIntegration.unsubscribe(socket, subscription)
  """
  @spec unsubscribe(Phoenix.LiveView.Socket.t(), subscription()) :: :ok | {:error, term()}
  def unsubscribe(socket, subscription) do
    case unsubscribe_from_resource(subscription) do
      :ok ->
        socket = remove_subscription(socket, subscription)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles resource change notifications from Ash.Notifier.

  This should be called from LiveView's `handle_info/2` callback.

  ## Examples

      def handle_info({:ash_change, notification}, socket) do
        AshUI.LiveView.UpdateIntegration.handle_resource_change(notification, socket)
      end
  """
  @spec handle_resource_change(map(), Phoenix.LiveView.Socket.t()) :: update_result()
  def handle_resource_change(notification, socket) do
    screen = socket.assigns[:ash_ui_screen]
    bindings = socket.assigns[:ash_ui_bindings] || %{}

    with {:ok, affected_bindings} <- find_affected_bindings(notification, bindings),
         {:ok, updated_values} <- reevaluate_bindings(affected_bindings, socket),
         socket <- update_socket_assigns(socket, updated_values),
         {:ok, socket} <- maybe_trigger_render(socket) do
      {:noreply, socket}
    else
      {:error, reason} ->
        Logger.error("Failed to handle resource change: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc """
  Batches multiple updates for performance.

  Instead of triggering a re-render for each binding change,
  collects changes and applies them together.

  ## Examples

      UpdateIntegration.batch_updates(socket, fn socket ->
        # Multiple updates here
        socket
      end)
  """
  @spec batch_updates(Phoenix.LiveView.Socket.t(), fun()) :: update_result()
  def batch_updates(socket, update_fn) when is_function(update_fn, 1) do
    # Mark the start of a batch
    socket = Phoenix.LiveView.assign(socket, :_ash_ui_batch_mode, true)

    # Apply all updates
    socket = update_fn.(socket)

    # Clear batch mode and trigger single render
    socket = Phoenix.LiveView.assign(socket, :_ash_ui_batch_mode, false)

    {:noreply, socket}
  end

  @doc """
  Handles subscription messages from Ash.Notifier.

  Routes different notification types to appropriate handlers.

  ## Notification Types
    * `{:created, resource}` - New resource created
    * `{:updated, resource}` - Resource updated
    * `{:destroyed, resource}` - Resource deleted

  ## Examples

      def handle_info({:ash_notification, notification}, socket) do
        AshUI.LiveView.UpdateIntegration.handle_notification(notification, socket)
      end
  """
  @spec handle_notification(tuple(), Phoenix.LiveView.Socket.t()) :: update_result()
  def handle_notification({:created, resource}, socket) do
    handle_resource_change(%{
      type: :created,
      resource: resource,
      timestamp: DateTime.utc_now()
    }, socket)
  end

  def handle_notification({:updated, resource}, socket) do
    handle_resource_change(%{
      type: :updated,
      resource: resource,
      timestamp: DateTime.utc_now()
    }, socket)
  end

  def handle_notification({:destroyed, resource}, socket) do
    handle_resource_change(%{
      type: :destroyed,
      resource: resource,
      timestamp: DateTime.utc_now()
    }, socket)
  end

  def handle_notification(unknown, socket) do
    Logger.debug("Unknown notification type: #{inspect(unknown)}")
    {:noreply, socket}
  end

  @doc """
  Re-evaluates all bindings for a screen after data changes.

  ## Examples

      UpdateIntegration.refresh_bindings(socket)
  """
  @spec refresh_bindings(Phoenix.LiveView.Socket.t()) :: update_result()
  def refresh_bindings(socket) do
    screen = socket.assigns[:ash_ui_screen]
    user = socket.assigns[:ash_ui_user]
    params = socket.assigns[:ash_ui_params] || %{}

    case Integration.evaluate_bindings(screen, socket, user, params) do
      {:ok, bindings} ->
        socket = Phoenix.LiveView.assign(socket, :ash_ui_bindings, bindings)
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to refresh bindings: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc """
  Filters notifications to bound resources only.

  Ensures we only process notifications for resources
  that are actually bound to the current screen.

  ## Examples

      if UpdateIntegration.relevant_notification?(notification, socket) do
        # process notification
      end
  """
  @spec relevant_notification?(map(), Phoenix.LiveView.Socket.t()) :: boolean()
  def relevant_notification?(notification, socket) do
    subscriptions = get_subscriptions(socket)
    resource = get_notification_resource(notification)

    Enum.any?(subscriptions, fn sub ->
      sub.resource == resource
    end)
  end

  # Private functions

  defp generate_subscription_id(resource, filter) do
    "#{inspect(resource)}_#{:erlang.phash2(filter)}"
  end

  defp subscribe_to_resource(resource, subscription) do
    # Subscribe to Ash.Notifier
    # In production, would call Ash.Notifier.subscribe/2
    try do
      # Ash.Notifier.subscribe(subscription.resource, subscription.filter)
      :ok
    rescue
      e -> {:error, {:subscription_failed, e}}
    end
  end

  defp unsubscribe_from_resource(subscription) do
    # Unsubscribe from Ash.Notifier
    # In production, would call Ash.Notifier.unsubscribe/1
    try do
      # Ash.Notifier.unsubscribe(subscription.resource)
      :ok
    rescue
      e -> {:error, {:unsubscribe_failed, e}}
    end
  end

  defp track_subscription(socket, subscription) do
    subscriptions = Map.get(socket.assigns, :ash_ui_subscriptions, [])
    updated = [subscription | subscriptions]
    Phoenix.LiveView.assign(socket, :ash_ui_subscriptions, updated)
  end

  defp remove_subscription(socket, subscription) do
    subscriptions = Map.get(socket.assigns, :ash_ui_subscriptions, [])
    updated = Enum.reject(subscriptions, fn sub -> sub.id == subscription.id end)
    Phoenix.LiveView.assign(socket, :ash_ui_subscriptions, updated)
  end

  defp get_subscriptions(socket) do
    Map.get(socket.assigns, :ash_ui_subscriptions, [])
  end

  defp get_notification_resource(%{resource: resource}), do: resource
  defp get_notification_resource(_), do: nil

  defp find_affected_bindings(notification, bindings) do
    # Find bindings that reference the changed resource
    affected =
      Enum.filter(bindings, fn {_id, _value} ->
        # In production, would check if binding source matches notification resource
        true
      end)

    {:ok, affected}
  end

  defp reevaluate_bindings(affected_bindings, socket) do
    context = build_evaluation_context(socket)

    results =
      Enum.reduce(affected_bindings, %{}, fn {binding_id, _value}, acc ->
        case get_binding_by_id(binding_id, socket) do
          {:ok, binding} ->
            case BindingEvaluator.evaluate(binding, context) do
              {:ok, value} ->
                Map.put(acc, binding_id, value)

              {:error, _reason} ->
                # Keep old value on error
                acc
            end

          :error ->
            acc
        end
      end)

    {:ok, results}
  end

  defp build_evaluation_context(socket) do
    %{
      user_id: get_user_id(socket),
      user: socket.assigns[:ash_ui_user],
      params: socket.assigns[:ash_ui_params] || %{},
      assigns: socket.assigns,
      socket: socket
    }
  end

  defp get_user_id(socket) do
    case socket.assigns[:ash_ui_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp get_binding_by_id(binding_id, socket) do
    # In production, would load binding from Ash
    {:ok, %{id: binding_id}}
  end

  defp update_socket_assigns(socket, updated_values) do
    current_bindings = socket.assigns[:ash_ui_bindings] || %{}
    updated_bindings = Map.merge(current_bindings, updated_values)
    Phoenix.LiveView.assign(socket, :ash_ui_bindings, updated_bindings)
  end

  defp maybe_trigger_render(socket) do
    batch_mode = Map.get(socket.assigns, :_ash_ui_batch_mode, false)

    if batch_mode do
      {:ok, socket}
    else
      # Trigger re-render
      {:ok, socket}
    end
  end

  @doc """
  Cleanup all subscriptions on unmount.

  Should be called from LiveView's terminate/2 callback.

  ## Examples

      def terminate(reason, socket) do
        AshUI.LiveView.UpdateIntegration.cleanup_subscriptions(socket)
      end
  """
  @spec cleanup_subscriptions(Phoenix.LiveView.Socket.t()) :: :ok
  def cleanup_subscriptions(socket) do
    subscriptions = get_subscriptions(socket)

    Enum.each(subscriptions, fn subscription ->
      unsubscribe_from_resource(subscription)
    end)

    :ok
  end
end
