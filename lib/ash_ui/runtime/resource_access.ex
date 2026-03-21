defmodule AshUI.Runtime.ResourceAccess do
  @moduledoc false

  require Ash.Query

  alias AshUI.Authorization.Policies

  @type context :: map()
  @type resolved :: %{
          resource: module(),
          domain: module(),
          actor: term(),
          tenant: term() | nil,
          authorize?: boolean()
        }

  @spec resolve(module() | String.t(), context()) :: {:ok, resolved()} | {:error, term()}
  def resolve(resource_ref, context) do
    resource_ref
    |> matching_resources(context)
    |> unique_match(resource_ref, context)
  end

  @spec read_field(map(), String.t(), context(), keyword()) :: {:ok, term()} | {:error, term()}
  def read_field(source, field, context, opts \\ []) do
    with {:ok, resolved} <- resolve(source_resource(source), context),
         {:ok, record} <- optional_record(source, context, Keyword.put(opts, :resolved, resolved)) do
      {:ok, fetch_value(record, field)}
    end
  end

  @spec read_relationship(map(), String.t(), context(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def read_relationship(source, relationship_path, context, opts \\ []) do
    with {:ok, resolved} <- resolve(source_resource(source), context),
         {:ok, record} <- optional_record(source, context, Keyword.put(opts, :resolved, resolved)) do
      navigate(
        record,
        resolved.resource,
        String.split(relationship_path, ".", trim: true),
        resolved
      )
    end
  end

  @spec read_collection(map(), context(), keyword()) ::
          {:ok, %{items: list(), total: non_neg_integer()}} | {:error, term()}
  def read_collection(source, context, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 20)
    filters = Keyword.get(opts, :filters, %{})

    with {:ok, resolved} <- resolve(source_resource(source), context),
         {:ok, items} <- load_collection_items(source, resolved, context) do
      filtered_items = apply_in_memory_filters(items, filters)
      total = length(filtered_items)

      paged_items =
        filtered_items |> Enum.drop(max(page - 1, 0) * page_size) |> Enum.take(page_size)

      {:ok, %{items: paged_items, total: total}}
    end
  end

  @spec write_field(map(), term(), context(), keyword()) :: {:ok, map()} | {:error, term()}
  def write_field(source, value, context, opts \\ []) do
    with {:ok, resolved} <- resolve(source_resource(source), context),
         {:ok, record} <- required_record(source, context, Keyword.put(opts, :resolved, resolved)),
         {:ok, attribute_name} <- resolve_attribute_name(resolved.resource, source_field(source)),
         {:ok, updated} <-
           Ash.update(
             record,
             %{attribute_name => value},
             update_opts(resolved, source, opts)
           ) do
      {:ok, %{status: :ok, record: updated, value: fetch_value(updated, attribute_name)}}
    end
  end

  @spec execute_action(map(), map(), context(), keyword()) :: {:ok, term()} | {:error, term()}
  def execute_action(source, params, context, opts \\ []) do
    with {:ok, resolved} <- resolve(source_resource(source), context),
         {:ok, action} <- resolve_action(resolved.resource, source_action(source)) do
      normalized_params = normalize_params(params, resolved.resource, action)

      case action.type do
        :create ->
          Ash.create(resolved.resource, normalized_params, create_opts(resolved, action, opts))

        :update ->
          with {:ok, record} <-
                 required_record(source, context, Keyword.put(opts, :resolved, resolved)) do
            update_params = drop_primary_key(normalized_params, resolved.resource)
            Ash.update(record, update_params, action_opts(resolved, action, opts))
          end

        :destroy ->
          with {:ok, record} <-
                 required_record(source, context, Keyword.put(opts, :resolved, resolved)) do
            Ash.destroy(record, action_opts(resolved, action, opts))
          end

        :action ->
          resolved.resource
          |> Ash.ActionInput.for_action(action.name, normalized_params)
          |> Ash.run_action(action_opts(resolved, action, opts))

        other ->
          {:error, {:unsupported_action_type, other}}
      end
    end
  end

  def actor(context) do
    cond do
      Map.has_key?(context, :actor) and not is_nil(context.actor) ->
        context.actor

      Map.has_key?(context, :user) and not is_nil(context.user) ->
        context.user

      get_in(context, [:assigns, :current_user]) ->
        get_in(context, [:assigns, :current_user])

      Map.get(context, :user_id) ->
        %{id: context.user_id}

      true ->
        nil
    end
  end

  defp load_collection_items(source, resolved, context) do
    parent_filters = build_filters(source, resolved.resource, context, filters: %{})

    case source_relationship(source) do
      nil ->
        read_records(resolved, parent_filters)

      relationship_path ->
        case record_id(source, resolved.resource, context) do
          nil ->
            with {:ok, records} <- read_records(resolved, parent_filters),
                 {:ok, values} <-
                   navigate(
                     records,
                     resolved.resource,
                     String.split(relationship_path, ".", trim: true),
                     resolved
                   ) do
              {:ok, List.wrap(values) |> List.flatten()}
            end

          _id ->
            with {:ok, record} <-
                   required_record(source, context, resolved: resolved, filters: %{}),
                 {:ok, values} <-
                   navigate(
                     record,
                     resolved.resource,
                     String.split(relationship_path, ".", trim: true),
                     resolved
                   ) do
              {:ok, List.wrap(values) |> List.flatten()}
            end
        end
    end
  end

  defp optional_record(source, context, opts) do
    resolved = Keyword.fetch!(opts, :resolved)
    filters = build_filters(source, resolved.resource, context, opts)
    read_one(resolved, filters)
  end

  defp required_record(source, context, opts) do
    with {:ok, record} <- optional_record(source, context, opts) do
      case record do
        nil ->
          {:error,
           {:resource_not_found, source_resource(source),
            record_id(source, opts[:resolved].resource, context)}}

        record ->
          {:ok, record}
      end
    end
  end

  defp read_one(resolved, filters) do
    resolved.resource
    |> Ash.Query.new()
    |> maybe_filter(filters, resolved.resource)
    |> Ash.read_one(ash_opts(resolved))
    |> authorize_record_result(resolved)
  end

  defp read_records(resolved, filters) do
    resolved.resource
    |> Ash.Query.new()
    |> maybe_filter(filters, resolved.resource)
    |> Ash.read(ash_opts(resolved))
    |> authorize_records_result(resolved)
  end

  defp maybe_filter(query, filters, _resource) when filters in [%{}, [], nil], do: query

  defp maybe_filter(query, filters, resource) do
    normalized =
      filters
      |> Enum.into(%{})
      |> Enum.reduce([], fn {key, value}, acc ->
        case resolve_attribute_name(resource, key) do
          {:ok, attribute_name} -> Keyword.put(acc, attribute_name, value)
          {:error, _} -> acc
        end
      end)

    if normalized == [] do
      query
    else
      Ash.Query.filter(query, ^normalized)
    end
  end

  defp navigate(value, _resource, [], _resolved), do: {:ok, value}
  defp navigate(nil, _resource, _parts, _resolved), do: {:ok, nil}

  defp navigate(values, resource, parts, resolved) when is_list(values) do
    resolved_values =
      values
      |> Enum.map(fn item ->
        item_resource = resource_for(item) || resource

        case navigate(item, item_resource, parts, resolved) do
          {:ok, value} -> value
          {:error, _reason} -> nil
        end
      end)
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    {:ok, resolved_values}
  end

  defp navigate(value, resource, [part | rest], resolved) do
    case resolve_relationship(resource, part) do
      {:ok, relationship} ->
        with {:ok, loaded} <- Ash.load(value, relationship.name, ash_opts(resolved)),
             {:ok, next} <- maybe_authorize_loaded(Map.get(loaded, relationship.name), resolved) do
          navigate(next, relationship.destination, rest, resolved)
        end

      {:error, _} ->
        next = fetch_value(value, part)

        case rest do
          [] -> {:ok, next}
          _ -> navigate(next, resource_for(next), rest, resolved)
        end
    end
  end

  defp resolve_relationship(nil, _name), do: {:error, :no_resource}

  defp resolve_relationship(resource, name) do
    target = to_string(name)

    case Enum.find(Ash.Resource.Info.relationships(resource), fn relationship ->
           Atom.to_string(relationship.name) == target
         end) do
      nil -> {:error, {:unknown_relationship, resource, name}}
      relationship -> {:ok, relationship}
    end
  end

  defp resolve_action(_resource, nil), do: {:error, :missing_action}

  defp resolve_action(resource, name) do
    target = to_string(name)

    case Enum.find(Ash.Resource.Info.actions(resource), fn action ->
           Atom.to_string(action.name) == target
         end) do
      nil -> {:error, {:unknown_action, resource, name}}
      action -> {:ok, action}
    end
  end

  defp resolve_attribute_name(_resource, nil), do: {:error, :missing_field}

  defp resolve_attribute_name(resource, name) do
    target = to_string(name)

    case Enum.find(Ash.Resource.Info.attributes(resource), fn attribute ->
           Atom.to_string(attribute.name) == target
         end) do
      nil -> {:error, {:unknown_field, resource, name}}
      attribute -> {:ok, attribute.name}
    end
  end

  defp source_resource(source) do
    Map.get(source, :resource) || Map.get(source, "resource")
  end

  defp source_field(source) do
    Map.get(source, :field) || Map.get(source, "field")
  end

  defp source_action(source) do
    Map.get(source, :action) || Map.get(source, "action")
  end

  defp source_relationship(source) do
    Map.get(source, :relationship) || Map.get(source, "relationship")
  end

  defp build_filters(source, resource, context, opts) do
    filters =
      opts
      |> Keyword.get(:filters, %{})
      |> Enum.into(%{})

    case record_id(source, resource, context) do
      nil ->
        filters

      id ->
        primary_key = resource |> Ash.Resource.Info.primary_key() |> List.first()
        Map.put(filters, primary_key, id)
    end
  end

  defp record_id(source, resource, context) do
    Map.get(source, :id) ||
      Map.get(source, "id") ||
      context_specific_id(resource, context)
  end

  defp context_specific_id(resource, context) do
    params = Map.get(context, :params, %{})
    assigns = Map.get(context, :assigns, %{})
    primary_key = resource |> Ash.Resource.Info.primary_key() |> List.first() |> to_string()
    short_name = resource |> Module.split() |> List.last() |> Macro.underscore()

    [primary_key, "id", "#{short_name}_id"]
    |> Enum.find_value(fn key ->
      atom_key =
        try do
          String.to_existing_atom(key)
        rescue
          ArgumentError -> nil
        end

      Map.get(params, key) || Map.get(assigns, key) ||
        if(atom_key, do: Map.get(assigns, atom_key))
    end)
  end

  defp ash_opts(%{domain: domain, actor: actor, tenant: tenant, authorize?: authorize?}) do
    [domain: domain, actor: actor, tenant: tenant, authorize?: authorize?]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp action_opts(resolved, action, opts) do
    ash_opts(resolved)
    |> Keyword.put(:action, action.name)
    |> Keyword.merge(Keyword.take(opts, [:timeout]))
  end

  defp create_opts(resolved, action, opts), do: action_opts(resolved, action, opts)

  defp update_opts(resolved, source, opts) do
    action_name =
      case source_action(source) do
        nil ->
          resolved.resource
          |> Ash.Resource.Info.primary_action!(:update)
          |> Map.get(:name)

        provided when is_atom(provided) ->
          provided

        provided ->
          case resolve_action(resolved.resource, provided) do
            {:ok, action} -> action.name
            {:error, _reason} -> provided
          end
      end

    ash_opts(resolved)
    |> Keyword.put(:action, action_name)
    |> Keyword.merge(Keyword.take(opts, [:timeout]))
  end

  defp drop_primary_key(params, resource) do
    primary_keys = Ash.Resource.Info.primary_key(resource)
    Enum.reduce(primary_keys, params, &Map.delete(&2, &1))
  end

  defp normalize_params(params, resource, action) when is_map(params) do
    allowed_names =
      resource
      |> Ash.Resource.Info.attributes()
      |> Enum.map(& &1.name)
      |> Kernel.++(Enum.map(action.arguments || [], & &1.name))

    Enum.reduce(params, %{}, fn {key, value}, acc ->
      key_string = to_string(key)

      normalized_key =
        Enum.find(allowed_names, key, fn name ->
          Atom.to_string(name) == key_string
        end)

      Map.put(acc, normalized_key, value)
    end)
  end

  defp normalize_params(params, _resource, _action), do: params

  defp apply_in_memory_filters(items, filters) when filters in [%{}, [], nil], do: items

  defp apply_in_memory_filters(items, filters) do
    expected = Enum.into(filters, %{}, fn {key, value} -> {to_string(key), value} end)

    Enum.filter(items, fn item ->
      Enum.all?(expected, fn {key, value} ->
        fetch_value(item, key) == value
      end)
    end)
  end

  defp fetch_value(nil, _key), do: nil

  defp fetch_value(data, key) when is_map(data) do
    case Map.get(data, key) do
      nil ->
        case Enum.find(Map.keys(data), fn existing_key ->
               to_string(existing_key) == to_string(key)
             end) do
          nil -> nil
          existing_key -> Map.get(data, existing_key)
        end

      value ->
        value
    end
  end

  defp fetch_value(_data, _key), do: nil

  defp resource_for(%{__struct__: resource_module}) do
    Ash.Resource.Info.attributes(resource_module)
    resource_module
  rescue
    _ -> nil
  end

  defp resource_for(_value), do: nil

  defp matching_resources(resource_ref, context) do
    target = normalize_resource_ref(resource_ref)

    context_domains(context)
    |> Enum.flat_map(fn domain ->
      domain
      |> Ash.Domain.Info.resources()
      |> Enum.filter(&resource_matches?(&1, target))
      |> Enum.map(&{domain, &1})
    end)
  end

  defp unique_match([], resource_ref, _context), do: {:error, {:unknown_resource, resource_ref}}

  defp unique_match(matches, resource_ref, context) do
    matches = Enum.uniq_by(matches, fn {_domain, resource} -> resource end)

    case matches do
      [{domain, resource}] ->
        {:ok, build_resolved(domain, resource, context)}

      _ ->
        {:error,
         {:ambiguous_resource, resource_ref,
          Enum.map(matches, fn {_domain, resource} -> resource end)}}
    end
  end

  defp normalize_resource_ref(resource_ref) when is_atom(resource_ref), do: resource_ref
  defp normalize_resource_ref(resource_ref), do: to_string(resource_ref)

  defp resource_matches?(resource, target) when is_atom(target), do: resource == target

  defp resource_matches?(resource, target) do
    module_name = resource |> Atom.to_string() |> String.trim_leading("Elixir.")
    short_name = resource |> Module.split() |> List.last()
    resource_short_name = resource |> Ash.Resource.Info.short_name() |> to_string()

    target in [module_name, short_name, resource_short_name]
  end

  defp context_domains(context) do
    context
    |> Map.get(:ash_domains, Application.get_env(:ash_ui, :ash_domains, [AshUI.Domain]))
    |> List.wrap()
    |> Enum.uniq()
  end

  defp build_resolved(domain, resource, context) do
    actor = actor(context)

    %{
      resource: resource,
      domain: domain,
      actor: actor,
      tenant: Map.get(context, :tenant),
      authorize?: Map.get(context, :authorize?, not is_nil(actor))
    }
  end

  defp authorize_record_result({:ok, record}, resolved) do
    case authorize_record(record, resolved, :read) do
      :ok -> {:ok, record}
      {:error, :unauthorized} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize_record_result(other, _resolved), do: other

  defp authorize_records_result({:ok, records}, resolved) when is_list(records) do
    {:ok, Enum.filter(records, &authorized_record?(&1, resolved, :read))}
  end

  defp authorize_records_result(other, _resolved), do: other

  defp maybe_authorize_loaded(value, resolved) do
    {:ok, prune_unauthorized(value, resolved)}
  end

  defp prune_unauthorized(values, resolved) when is_list(values) do
    Enum.filter(values, &authorized_record?(&1, resolved, :read))
  end

  defp prune_unauthorized(nil, _resolved), do: nil

  defp prune_unauthorized(value, resolved) do
    if authorized_record?(value, resolved, :read), do: value, else: nil
  end

  defp authorize_record(record, resolved, action) do
    if authorized_record?(record, resolved, action) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp authorized_record?(nil, _resolved, _action), do: true
  defp authorized_record?(_record, %{authorize?: false}, _action), do: true
  defp authorized_record?(_record, %{actor: nil}, _action), do: true

  defp authorized_record?(record, resolved, action) do
    case Policies.allows_record_action?(resolved.actor, record, action) do
      true ->
        true

      false ->
        false

      :unknown ->
        Ash.can?({record, action}, resolved.actor, maybe_is: false)
    end
  rescue
    _ -> true
  end
end
