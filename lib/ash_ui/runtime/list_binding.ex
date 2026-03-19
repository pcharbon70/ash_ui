defmodule AshUI.Runtime.ListBinding do
  @moduledoc """
  Collection binding for `:list` type bindings.

  Handles loading, binding, and reactive updates for collections
  of Ash resources to UI elements like lists and tables.
  """

  alias AshUI.Runtime.BindingEvaluator

  @type context :: %{
          user_id: String.t() | nil,
          params: map(),
          assigns: map()
        }

  @type list_result :: %{
          items: [map()],
          total: integer(),
          page: integer(),
          page_size: integer(),
          has_next: boolean(),
          has_prev: boolean()
        }

  @doc """
  Loads a collection from Ash resource based on list binding.

  ## Parameters
    * binding - The list binding to load
    * context - Evaluation context
    * opts - Options including pagination and filtering

  ## Returns
    * `{:ok, list_result}` - Collection loaded successfully
    * `{:error, reason}` - Load failed

  ## Examples

      iex> binding = %{
      ...>   source: %{"resource" => "Post", "relationship" => "comments"},
      ...>   binding_type: :list
      ...> }
      iex> AshUI.Runtime.ListBinding.load_collection(binding, context)
      {:ok, %{items: [...], total: 10, page: 1, ...}}
  """
  @spec load_collection(map(), context(), keyword()) :: {:ok, list_result()} | {:error, term()}
  def load_collection(binding, context, opts \\ []) do
    source = binding.source || %{}
    resource = Map.get(source, "resource")
    relationship = Map.get(source, "relationship")

    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 20)
    filters = Keyword.get(opts, :filters, %{})

    with {:ok, collection} <-
           load_resource_collection(resource, relationship, page, page_size, filters, context) do
      total = get_total_count(collection)
      items = extract_items(collection)

      list_result = %{
        items: items,
        total: total,
        page: page,
        page_size: page_size,
        has_next: total > page * page_size,
        has_prev: page > 1
      }

      {:ok, list_result}
    end
  end

  @doc """
  Subscribes to collection changes for reactive updates.

  ## Parameters
    * binding - The list binding to subscribe
    * socket - LiveView socket
    * context - Evaluation context

  ## Returns
    * `{:ok, socket}` - Subscribed successfully
  """
  @spec subscribe_collection(map(), map(), context()) :: {:ok, map()}
  def subscribe_collection(binding, socket, context) do
    subscription_id = collection_subscription_id(binding)

    # Track collection subscription
    subscriptions = get_in(socket.assigns, [:ash_ui, :list_subscriptions]) || %{}

    subscription = %{
      binding_id: get_binding_id(binding),
      resource: Map.get(binding.source, "resource"),
      relationship: Map.get(binding.source, "relationship"),
      subscribed_at: System.system_time(:millisecond)
    }

    updated_subscriptions = Map.put(subscriptions, subscription_id, subscription)
    updated_socket = put_in(socket.assigns, [:ash_ui, :list_subscriptions], updated_subscriptions)

    {:ok, updated_socket}
  end

  @doc """
  Handles collection change notification and updates UI.

  ## Parameters
    * binding - The list binding
    * change_type - :insert, :update, :delete
    * change_data - Details of what changed
    * socket - LiveView socket
    * context - Evaluation context

  ## Returns
    * `{:ok, socket, should_update?}` - Updated socket and whether to re-render
  """
  @spec handle_collection_change(map(), atom(), map(), map(), context()) ::
          {:ok, map(), boolean()}
  def handle_collection_change(binding, change_type, change_data, socket, context) do
    case change_type do
      :insert ->
        handle_insert(binding, change_data, socket, context)

      :update ->
        handle_update(binding, change_data, socket, context)

      :delete ->
        handle_delete(binding, change_data, socket, context)
    end
  end

  @doc """
  Formats a collection for UI display with transformations applied.

  ## Parameters
    * list_result - The loaded collection
    * binding - The binding with transformation rules
    * context - Evaluation context

  ## Returns
    * `{:ok, formatted_items}` - Formatted collection items
  """
  @spec format_collection(list_result(), map(), context()) :: {:ok, [map()]} | {:error, term()}
  def format_collection(list_result, binding, context) do
    transform = binding.transform || %{}
    items = list_result.items

    formatted =
      Enum.map(items, fn item ->
        format_item(item, transform, context)
      end)

    {:ok, formatted}
  end

  # Private functions

  defp load_resource_collection(resource, relationship, page, page_size, filters, _context) do
    # In production, this would use Ash.Query to load the collection
    # For now, return mock data
    mock_load_collection(resource, relationship, page, page_size, filters)
  end

  defp mock_load_collection(resource, relationship, page, page_size, _filters) do
    # Generate mock collection data
    items =
      Enum.map(1..page_size, fn i ->
        %{
          "id" => "#{resource}-#{relationship}-#{(page - 1) * page_size + i}",
          "type" => relationship,
          "index" => (page - 1) * page_size + i
        }
      end)

    {:ok,
     %{
       "items" => items,
       "total" => 100, # Mock total
       "page" => page
     }}
  end

  defp get_total_count(collection) do
    Map.get(collection, "total", length(Map.get(collection, "items", [])))
  end

  defp extract_items(collection) do
    Map.get(collection, "items", [])
  end

  defp handle_insert(binding, change_data, socket, context) do
    # For insert, we may want to prepend to the list or refresh
    target = binding.target || Map.get(binding, "target")

    # Store change for UI update
    changes = get_in(socket.assigns, [:ash_ui, :list_changes, target]) || []
    updated_changes = [{:insert, change_data} | changes]
    updated_socket = put_in(socket.assigns, [:ash_ui, :list_changes, target], updated_changes)

    {:ok, updated_socket, true}
  end

  defp handle_update(binding, change_data, socket, _context) do
    # For update, find the item and update it
    target = binding.target || Map.get(binding, "target")
    item_id = Map.get(change_data, "id")

    # Update the item in the cached list
    items = get_in(socket.assigns, [:ash_ui, :lists, target, "items"]) || []

    updated_items =
      Enum.map(items, fn item ->
        if Map.get(item, "id") == item_id do
          Map.merge(item, change_data)
        else
          item
        end
      end)

    updated_socket = put_in(socket.assigns, [:ash_ui, :lists, target, "items"], updated_items)

    {:ok, updated_socket, true}
  end

  defp handle_delete(binding, change_data, socket, _context) do
    # For delete, remove the item from the list
    target = binding.target || Map.get(binding, "target")
    item_id = Map.get(change_data, "id")

    items = get_in(socket.assigns, [:ash_ui, :lists, target, "items"]) || []

    updated_items = Enum.reject(items, fn item -> Map.get(item, "id") == item_id end)

    updated_socket =
      put_in(socket.assigns, [:ash_ui, :lists, target, "items"], updated_items)

    # Update total count
    current_total = get_in(socket.assigns, [:ash_ui, :lists, target, "total"]) || 0
    updated_socket = put_in(socket.assigns, [:ash_ui, :lists, target, "total"], current_total - 1)

    {:ok, updated_socket, true}
  end

  defp format_item(item, transform, context) do
    # Apply transformations to each item
    Enum.reduce(transform, item, fn {key, rules}, acc ->
      apply_item_transform(acc, key, rules, context)
    end)
  end

  defp apply_item_transform(item, key, rules, context) when is_map(rules) do
    current_value = Map.get(item, key)

    case Map.get(rules, "function") do
      "format" ->
        format_value = Map.get(rules, "format")
        Map.put(item, key, do_format(current_value, format_value))

      "compute" ->
        computed = compute_value(item, key, rules, context)
        Map.put(item, key, computed)

      _ ->
        item
    end
  end

  defp apply_item_transform(item, _key, _rules, _context), do: item

  defp do_format(value, format_string) when is_binary(format_string) do
    # Simple format string replacement
    # In production, use more sophisticated formatting
    String.replace(format_string, "{value}", to_string(value))
  end

  defp do_format(value, _format), do: value

  defp compute_value(item, key, rules, _context) do
    expression = Map.get(rules, "expression")
    # In production, would evaluate expression safely
    # For now, return the original value
    Map.get(item, key, expression)
  end

  defp get_binding_id(binding) do
    Map.get(binding, :id) || Map.get(binding, "id")
  end

  defp collection_subscription_id(binding) do
    resource = get_in(binding, [:source, "resource"])
    relationship = get_in(binding, [:source, "relationship"])
    "list_#{resource}_#{relationship}"
  end
end
