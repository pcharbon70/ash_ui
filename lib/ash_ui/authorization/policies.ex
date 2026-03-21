defmodule AshUI.Authorization.Policies do
  @moduledoc """
  Policy definitions for Ash UI resources.

  Defines common policy checks and policies for controlling access
  to UI screens, elements, and bindings.
  """

  alias AshUI.Authorization.BindingPolicy
  alias AshUI.Authorization.ElementPolicy
  alias AshUI.Authorization.ScreenPolicy
  alias AshUI.Runtime.ResourceAccess
  alias AshUI.Resources.Binding
  alias AshUI.Resources.Element
  alias AshUI.Resources.Screen

  @type policy_result :: :authorized | :forbidden | {:error, term()}

  @doc """
  Common policy check: user must be active.

  Checks that the user has an `active` status or equivalent.

  ## Examples

      policy do
        authorize_if expr(user_active(@actor))
      end
  """
  def user_active(user) do
    case user do
      nil -> false
      %{active: true} -> true
      %{status: "active"} -> true
      _ -> false
    end
  end

  @doc """
  Common policy check: user has required role.

  Checks that the user has at least one of the required roles.

  ## Examples

      policy do
        authorize_if expr(user_role(@actor, :admin))
      end
  """
  @spec user_role(term(), atom() | [atom()]) :: boolean()
  def user_role(user, required_roles) when is_list(required_roles) do
    case user do
      nil -> false
      %{role: role} -> role in required_roles
      %{roles: roles} when is_list(roles) -> Enum.any?(roles, &(&1 in required_roles))
      _ -> false
    end
  end

  def user_role(user, required_role) when is_atom(required_role) do
    user_role(user, [required_role])
  end

  @doc """
  Common policy check: user owns the screen/resource.

  Checks that the user's ID matches the resource's owner_id.

  ## Examples

      policy do
        authorize_if expr(screen_owner(@actor, @resource))
      end
  """
  @spec screen_owner(term(), map()) :: boolean()
  def screen_owner(user, resource) do
    case {user, resource} do
      {nil, _} -> false
      {%{id: user_id}, _resource} when not is_nil(user_id) -> user_id == owner_id(resource)
      _ -> false
    end
  end

  @doc """
  Returns whether a resource is marked active.
  """
  @spec resource_active?(map()) :: boolean()
  def resource_active?(resource) do
    case resource_value(resource, :active) do
      false -> false
      _ -> true
    end
  end

  @doc """
  Returns whether a resource is explicitly public.
  """
  @spec public_resource?(map()) :: boolean()
  def public_resource?(resource), do: resource_value(resource, :public) == true

  @doc """
  Returns whether a resource is explicitly marked private.
  """
  @spec explicitly_private_resource?(map()) :: boolean()
  def explicitly_private_resource?(resource), do: resource_value(resource, :public) == false

  @doc """
  Returns the owner ID for a resource from top-level fields or metadata.
  """
  @spec owner_id(map()) :: term()
  def owner_id(resource) do
    resource_value(resource, :owner_id) || resource_value(resource, :user_id)
  end

  @doc """
  Returns the required roles for a resource.
  """
  @spec required_roles(map()) :: [atom()]
  def required_roles(resource) do
    resource
    |> resource_value(:required_roles, resource_value(resource, :required_role))
    |> case do
      nil -> []
      roles when is_list(roles) -> Enum.map(roles, &normalize_role/1)
      role -> [normalize_role(role)]
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Returns whether the user satisfies any role requirement on the resource.
  """
  @spec role_allowed?(term(), map()) :: boolean()
  def role_allowed?(user, resource) do
    case required_roles(resource) do
      [] -> true
      roles -> user_role(user, roles)
    end
  end

  @doc """
  Returns whether a resource has no explicit ownership or role restrictions.
  """
  @spec unrestricted_resource?(map()) :: boolean()
  def unrestricted_resource?(resource) do
    is_nil(owner_id(resource)) and
      required_roles(resource) == [] and
      not explicitly_private_resource?(resource)
  end

  @doc """
  Common policy check: environment check.

  Allows access based on the current environment (dev, test, prod).

  ## Examples

      policy do
        authorize_if expr(environment(:dev))
      end
  """
  @spec environment(atom() | [atom()]) :: boolean()
  def environment(required_envs) when is_list(required_envs) do
    current_env = config_env()
    current_env in required_envs
  end

  def environment(required_env) when is_atom(required_env) do
    environment([required_env])
  end

  @doc """
  Check if user can read the binding source resource.

  Cross-resource policy check for data bindings.

  ## Examples

      policy do
        authorize_if can_read_source(@resource.source)
      end
  """
  @spec can_read_source(map(), term()) :: boolean()
  def can_read_source(binding, actor \\ nil)

  def can_read_source(binding, actor) when is_map(binding) do
    source = source_map(binding)

    if map_size(source) == 0 do
      true
    else
      resource = fetch_key(source, :resource)
      action = fetch_key(source, :action) || :read

      can_access_resource?(resource, action, actor)
    end
  end

  def can_read_source(_binding, _actor), do: true

  @doc """
  Check if user can write to the binding source resource.

  Cross-resource policy check for write bindings.

  ## Examples

      policy do
        authorize_if can_write_source(@resource.source)
      end
  """
  @spec can_write_source(map(), term()) :: boolean()
  def can_write_source(binding, actor \\ nil)

  def can_write_source(binding, actor) when is_map(binding) do
    source = source_map(binding)

    if map_size(source) == 0 do
      true
    else
      resource = fetch_key(source, :resource)
      action = fetch_key(source, :action) || :update

      can_access_resource?(resource, action, actor)
    end
  end

  def can_write_source(_binding, _actor), do: true

  @doc """
  Check if user can access a specific field on a resource.

  Field-level authorization check.

  ## Examples

      policy do
        authorize_if can_access_field(@resource, :email)
      end
  """
  @spec can_access_field(map(), atom() | String.t()) :: boolean()
  def can_access_field(resource, field) do
    field_name = to_string(field)

    hidden_fields =
      resource
      |> resource_value(:hidden_fields, resource_value(resource, :private_fields, []))
      |> List.wrap()
      |> Enum.map(&to_string/1)

    allowed_fields =
      resource
      |> resource_value(:allowed_fields, [])
      |> List.wrap()
      |> Enum.map(&to_string/1)

    cond do
      hidden_fields != [] -> field_name not in hidden_fields
      allowed_fields != [] -> field_name in allowed_fields
      true -> true
    end
  end

  @doc """
  Check if user can execute a specific action.

  Action-level authorization check.

  ## Examples

      policy do
        authorize_if can_execute_action(@resource, :delete)
      end
  """
  @spec can_execute_action(map(), atom()) :: boolean()
  def can_execute_action(_resource, _action) do
    # In production, would check action-level policies
    true
  end

  @doc """
  Returns whether runtime authorization checks should be bypassed.

  This is opt-in so tests exercise the real authorization paths by default.
  """
  @spec runtime_authorization_bypass?() :: boolean()
  def runtime_authorization_bypass? do
    Application.get_env(:ash_ui, :runtime_authorization_bypass, false)
  end

  @doc """
  Evaluates record-scoped policy checks for AshUI resources.

  These checks mirror the policy modules used by the resource authorizers and
  let runtime code fail closed when it already has a loaded record in hand.
  """
  @spec allows_record_action?(term(), map(), atom()) :: boolean() | :unknown
  def allows_record_action?(user, %Screen{} = screen, action) do
    case action do
      :mount -> ScreenPolicy.can_mount?(user, screen)
      action when action in [:read] -> ScreenPolicy.can_read?(user, screen)
      action when action in [:create, :update, :destroy] -> ScreenPolicy.can_manage?(user, screen)
      _ -> :unknown
    end
  end

  def allows_record_action?(user, %Element{} = element, action) do
    case action do
      action when action in [:read] ->
        ElementPolicy.can_read?(user, element)

      action when action in [:create, :update, :destroy] ->
        ElementPolicy.can_manage?(user, element)

      _ ->
        :unknown
    end
  end

  def allows_record_action?(user, %Binding{} = binding, action) do
    case action do
      action when action in [:read, :read_with_filter] ->
        BindingPolicy.can_read?(user, binding)

      :write ->
        BindingPolicy.can_write?(user, binding)

      action when action in [:create, :update, :destroy] ->
        BindingPolicy.can_manage?(user, binding)

      _ ->
        :unknown
    end
  end

  def allows_record_action?(_user, _record, _action), do: :unknown

  # Private functions

  defp config_env do
    Application.get_env(:ash_ui, :env, :dev)
  end

  defp can_access_resource?(nil, _action, _actor), do: false

  defp can_access_resource?(resource_ref, action, actor) do
    context = %{actor: actor, ash_domains: configured_domains(), authorize?: true}

    with {:ok, %{resource: resource}} <- ResourceAccess.resolve(resource_ref, context),
         action_name <- resolve_action_name(resource, action),
         true <- is_nil(actor) or Ash.can?({resource, action_name}, actor, maybe_is: false) do
      true
    else
      {:error, _reason} -> true
      false -> false
    end
  rescue
    _ -> true
  end

  defp configured_domains do
    Application.get_env(:ash_ui, :ash_domains, [AshUI.Domain])
  end

  defp resolve_action_name(resource, action) do
    target = to_string(action || :read)

    case Enum.find(Ash.Resource.Info.actions(resource), fn existing ->
           Atom.to_string(existing.name) == target
         end) do
      nil -> action || :read
      existing -> existing.name
    end
  end

  defp normalize_role(role) when is_atom(role), do: role

  defp normalize_role(role) when is_binary(role) do
    role
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> String.to_atom(normalized)
    end
  end

  defp normalize_role(_role), do: nil

  defp resource_value(resource, key, default \\ nil)

  defp resource_value(resource, key, default) when is_map(resource) do
    metadata =
      case fetch_key(resource, :metadata) do
        %{} = metadata -> metadata
        _ -> %{}
      end

    first_present([fetch_key(resource, key), fetch_key(metadata, key), default])
  end

  defp resource_value(_resource, _key, default), do: default

  defp source_map(binding) do
    case first_present([fetch_key(binding, :source), %{}]) do
      %{} = source -> source
      _ -> %{}
    end
  end

  defp first_present(values) do
    Enum.find_value(values, fn value ->
      if is_nil(value), do: nil, else: {:ok, value}
    end)
    |> case do
      {:ok, value} -> value
      nil -> nil
    end
  end

  defp fetch_key(map, key) do
    candidates = [key, to_string(key)]

    Enum.find_value(candidates, fn candidate ->
      case Map.fetch(map, candidate) do
        {:ok, value} -> {:ok, value}
        :error -> nil
      end
    end)
    |> case do
      {:ok, value} -> value
      nil -> nil
    end
  end
end
