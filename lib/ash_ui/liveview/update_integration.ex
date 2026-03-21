defmodule AshUI.LiveView.UpdateIntegration do
  @moduledoc """
  LiveView update integration for reactive data binding.

  Handles subscriptions to Ash resource changes and updates
  the LiveView when bound data changes.
  """

  require Logger

  alias AshUI.LiveView.Integration
  alias AshUI.Notifications
  alias AshUI.Runtime.BindingEvaluator
  alias AshUI.Runtime.ResourceAccess

  @subscription_table :ash_ui_liveview_subscriptions

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
  """
  @spec subscribe(Phoenix.LiveView.Socket.t(), module(), keyword()) ::
          {:ok, subscription()}
  def subscribe(socket, resource, opts \\ []) do
    filter = opts |> Keyword.get(:filter, %{}) |> Enum.into(%{})
    action = Keyword.get(opts, :action, :update)
    subscription = build_subscription(resource, action, filter)

    :ok = subscribe_to_resource(resource, subscription)
    store_subscription(socket, subscription)
    {:ok, subscription}
  end

  @doc """
  Registers subscriptions for all resource-backed bindings currently assigned
  to the socket and returns the socket with the subscription list assigned.
  """
  @spec sync_binding_subscriptions(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def sync_binding_subscriptions(socket) do
    bindings = socket.assigns[:ash_ui_bindings] || %{}
    existing_subscriptions = subscriptions(socket)

    {created, all_subscriptions} =
      bindings
      |> binding_resources(socket)
      |> Enum.reduce({[], existing_subscriptions}, fn resource, {created, subscriptions} ->
        if Enum.any?(subscriptions, &(&1.resource == resource)) do
          {created, subscriptions}
        else
          subscription = build_subscription(resource, :update, %{})
          :ok = subscribe_to_resource(resource, subscription)
          store_subscription(socket, subscription)
          {[subscription | created], [subscription | subscriptions]}
        end
      end)

    if created == [] do
      Phoenix.Component.assign(socket, :ash_ui_subscriptions, existing_subscriptions)
    else
      Phoenix.Component.assign(socket, :ash_ui_subscriptions, merge_unique_subscriptions(all_subscriptions))
    end
  end

  @doc """
  Returns the subscriptions currently tracked for the LiveView session.
  """
  @spec subscriptions(Phoenix.LiveView.Socket.t()) :: [subscription()]
  def subscriptions(socket) do
    assigned = Map.get(socket.assigns, :ash_ui_subscriptions, [])

    socket
    |> session_scope()
    |> registry_subscriptions()
    |> Kernel.++(assigned)
    |> merge_unique_subscriptions()
  end

  @doc """
  Unsubscribes from a resource change notification.
  """
  @spec unsubscribe(Phoenix.LiveView.Socket.t(), subscription()) :: :ok
  def unsubscribe(socket, subscription) do
    :ok = unsubscribe_from_resource(subscription)
    delete_subscription(socket, subscription)
    :ok
  end

  @doc """
  Handles resource change notifications from Ash.Notifier.

  This should be called from LiveView's `handle_info/2` callback.
  """
  @spec handle_resource_change(map() | Ash.Notifier.Notification.t(), Phoenix.LiveView.Socket.t()) ::
          update_result()
  def handle_resource_change(notification, socket) do
    bindings = socket.assigns[:ash_ui_bindings] || %{}

    with {:ok, affected_bindings} <- find_affected_bindings(notification, bindings, socket),
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
  """
  @spec batch_updates(Phoenix.LiveView.Socket.t(), fun()) :: update_result()
  def batch_updates(socket, update_fn) when is_function(update_fn, 1) do
    socket = Phoenix.Component.assign(socket, :_ash_ui_batch_mode, true)
    socket = update_fn.(socket)
    socket = Phoenix.Component.assign(socket, :_ash_ui_batch_mode, false)

    {:noreply, socket}
  end

  @doc """
  Handles subscription messages from Ash.Notifier.
  """
  @spec handle_notification(term(), Phoenix.LiveView.Socket.t()) :: update_result()
  def handle_notification(%Ash.Notifier.Notification{} = notification, socket) do
    handle_resource_change(notification, socket)
  end

  def handle_notification({:created, resource}, socket) do
    handle_resource_change(%{type: :created, resource: resource, timestamp: DateTime.utc_now()}, socket)
  end

  def handle_notification({:updated, resource}, socket) do
    handle_resource_change(%{type: :updated, resource: resource, timestamp: DateTime.utc_now()}, socket)
  end

  def handle_notification({:destroyed, resource}, socket) do
    handle_resource_change(%{type: :destroyed, resource: resource, timestamp: DateTime.utc_now()}, socket)
  end

  def handle_notification(unknown, socket) do
    Logger.debug("Unknown notification type: #{inspect(unknown)}")
    {:noreply, socket}
  end

  @doc """
  Re-evaluates all bindings for a screen after data changes.
  """
  @spec refresh_bindings(Phoenix.LiveView.Socket.t()) :: update_result()
  def refresh_bindings(socket) do
    screen = socket.assigns[:ash_ui_screen]
    user = socket.assigns[:ash_ui_user]
    params = socket.assigns[:ash_ui_params] || %{}

    cond do
      not match?(%AshUI.Resources.Screen{}, screen) or is_nil(user) ->
        {:noreply, socket}

      true ->
        {:ok, bindings} = Integration.evaluate_bindings(screen, socket, user, params)

        socket =
          socket
          |> Phoenix.Component.assign(:ash_ui_bindings, bindings)
          |> sync_runtime_binding_assigns(bindings)
          |> sync_binding_subscriptions()

        {:noreply, socket}
    end
  end

  @doc """
  Filters notifications to bound resources only.
  """
  @spec relevant_notification?(map(), Phoenix.LiveView.Socket.t()) :: boolean()
  def relevant_notification?(notification, socket) do
    resource = get_notification_resource(notification)

    Enum.any?(subscriptions(socket), fn subscription ->
      subscription.resource == resource
    end)
  end

  @doc """
  Cleanup all subscriptions on unmount.

  Should be called from LiveView's terminate/2 callback.
  """
  @spec cleanup_subscriptions(Phoenix.LiveView.Socket.t()) :: :ok
  def cleanup_subscriptions(socket) do
    subscriptions(socket)
    |> Enum.each(&unsubscribe_from_resource/1)

    clear_scope(socket)

    :ok
  end

  defp build_subscription(resource, action, filter) do
    %{
      id: generate_subscription_id(resource, filter, action),
      resource: resource,
      action: action,
      filter: filter
    }
  end

  defp generate_subscription_id(resource, filter, action) do
    "#{inspect(resource)}_#{action}_#{:erlang.phash2(filter)}"
  end

  defp subscribe_to_resource(resource, _subscription), do: Notifications.subscribe(resource)

  defp unsubscribe_from_resource(%{resource: resource}), do: Notifications.unsubscribe(resource)
  defp unsubscribe_from_resource(_subscription), do: :ok

  defp binding_resources(bindings, socket) do
    bindings
    |> normalize_bindings()
    |> Enum.map(&binding_resource(&1, socket))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp find_affected_bindings(notification, bindings, socket) do
    resource = get_notification_resource(notification)

    affected =
      bindings
      |> normalize_bindings()
      |> Enum.filter(&binding_matches_resource?(&1, resource, socket))

    {:ok, affected}
  end

  defp normalize_bindings(bindings) when is_map(bindings) do
    Enum.reduce(bindings, [], fn
      {binding_key, binding_state}, acc when is_map(binding_state) ->
        binding_state =
          binding_state
          |> Map.put_new(:id, binding_key)
          |> Map.put(:binding_key, binding_key)

        [binding_state | acc]

      _other, acc ->
        acc
    end)
  end

  defp normalize_bindings(bindings) when is_list(bindings) do
    Enum.filter(bindings, &is_map/1)
  end

  defp normalize_bindings(_other), do: []

  defp binding_matches_resource?(_binding, nil, _socket), do: false

  defp binding_matches_resource?(binding, resource, socket) do
    binding_type = Map.get(binding, :binding_type) || Map.get(binding, "binding_type")

    if binding_type in [:action, "action"] do
      false
    else
      binding_resource(binding, socket) == resource
    end
  end

  defp binding_resource(binding, socket) do
    source = Map.get(binding, :source) || Map.get(binding, "source") || %{}
    resource_ref = Map.get(source, :resource) || Map.get(source, "resource")

    cond do
      is_nil(resource_ref) ->
        nil

      is_atom(resource_ref) ->
        resource_ref

      true ->
        case ResourceAccess.resolve(resource_ref, build_evaluation_context(socket)) do
          {:ok, %{resource: resource}} -> resource
          {:error, _reason} -> nil
        end
    end
  end

  defp reevaluate_bindings(affected_bindings, socket) do
    context = build_evaluation_context(socket)

    results =
      Enum.reduce(affected_bindings, %{}, fn binding, acc ->
        case BindingEvaluator.evaluate(binding, context) do
          {:ok, value} ->
            Map.put(acc, storage_key(binding), updated_binding_state(binding, value, nil))

          {:error, reason} ->
            Logger.warning("Binding #{inspect(binding_id(binding))} re-evaluation failed: #{inspect(reason)}")

            current_value = Map.get(binding, :value) || Map.get(binding, "value")
            Map.put(acc, storage_key(binding), updated_binding_state(binding, current_value, reason))
        end
      end)

    {:ok, results}
  end

  defp build_evaluation_context(socket) do
    %{
      user_id: get_user_id(socket),
      user: socket.assigns[:ash_ui_user],
      authorize?: true,
      params: socket.assigns[:ash_ui_params] || %{},
      assigns: socket.assigns,
      socket: socket,
      ash_domains: Map.get(socket.assigns, :ash_ui_domains, Application.get_env(:ash_ui, :ash_domains, [AshUI.Domain]))
    }
  end

  defp get_user_id(socket) do
    case socket.assigns[:ash_ui_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp updated_binding_state(binding, value, error) do
    binding
    |> Map.drop([:binding_key])
    |> Map.put(:value, value)
    |> Map.put(:error, error)
    |> Map.put(:updated_at, System.system_time(:millisecond))
  end

  defp update_socket_assigns(socket, updated_values) when map_size(updated_values) == 0, do: socket

  defp update_socket_assigns(socket, updated_values) do
    current_bindings = socket.assigns[:ash_ui_bindings] || %{}
    updated_bindings = Map.merge(current_bindings, updated_values)

    socket
    |> Phoenix.Component.assign(:ash_ui_bindings, updated_bindings)
    |> sync_runtime_binding_assigns(updated_values)
  end

  defp sync_runtime_binding_assigns(socket, bindings) do
    ash_ui = Map.get(socket.assigns, :ash_ui, %{})
    runtime_bindings = Map.get(ash_ui, :bindings, %{})

    updated_runtime_bindings =
      Enum.reduce(bindings, runtime_bindings, fn {_binding_id, binding_state}, acc ->
        case Map.get(binding_state, :target) || Map.get(binding_state, "target") do
          nil ->
            acc

          target ->
            Map.put(acc, target, %{
              "value" => Map.get(binding_state, :value),
              "error" => Map.get(binding_state, :error),
              "updated_at" => Map.get(binding_state, :updated_at)
            })
        end
      end)

    Phoenix.Component.assign(socket, :ash_ui, Map.put(ash_ui, :bindings, updated_runtime_bindings))
  end

  defp maybe_trigger_render(socket) do
    if Map.get(socket.assigns, :_ash_ui_batch_mode, false) do
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  defp session_scope(socket) do
    {self(), Map.get(socket.assigns, :ash_ui_session_id) || Map.get(socket.assigns, :ash_ui_session_key) || :default}
  end

  defp store_subscription(socket, subscription) do
    table = ensure_subscription_table()
    scope = session_scope(socket)

    delete_subscription(socket, subscription)
    :ets.insert(table, {scope, subscription})
  end

  defp delete_subscription(socket, subscription) do
    table = ensure_subscription_table()
    scope = session_scope(socket)

    for {^scope, existing} <- :ets.lookup(table, scope),
        existing.id == subscription.id do
      :ets.delete_object(table, {scope, existing})
    end

    :ok
  end

  defp registry_subscriptions(scope) do
    table = ensure_subscription_table()

    table
    |> :ets.lookup(scope)
    |> Enum.map(fn {^scope, subscription} -> subscription end)
  end

  defp clear_scope(socket) do
    table = ensure_subscription_table()
    :ets.match_delete(table, {session_scope(socket), :_})
  end

  defp ensure_subscription_table do
    case :ets.whereis(@subscription_table) do
      :undefined ->
        try do
          :ets.new(@subscription_table, [:named_table, :public, :bag, read_concurrency: true])
        rescue
          ArgumentError -> @subscription_table
        end

      table ->
        table
    end
  end

  defp merge_unique_subscriptions(subscriptions) do
    subscriptions
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn
      %{id: id} -> id
      %{"id" => id} -> id
      other -> inspect(other)
    end)
  end

  defp get_notification_resource(%Ash.Notifier.Notification{resource: resource}), do: resource
  defp get_notification_resource(%{resource: %{__struct__: resource}}), do: resource
  defp get_notification_resource(%{resource: resource}) when is_atom(resource), do: resource
  defp get_notification_resource(_), do: nil

  defp binding_id(binding) do
    Map.get(binding, :id) || Map.get(binding, "id")
  end

  defp storage_key(binding) do
    Map.get(binding, :binding_key) || Map.get(binding, "binding_key") || binding_id(binding)
  end
end
