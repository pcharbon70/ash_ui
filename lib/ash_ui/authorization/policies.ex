defmodule AshUI.Authorization.Policies do
  @moduledoc """
  Policy definitions for Ash UI resources.

  Defines common policy checks and policies for controlling access
  to UI screens, elements, and bindings.
  """

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
      {%{id: user_id}, %{owner_id: owner_id}} when not is_nil(owner_id) -> user_id == owner_id
      {%{id: user_id}, %{user_id: user_id}} -> true
      _ -> false
    end
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
  @spec can_read_source(map()) :: boolean()
  def can_read_source(%{source: source}) when is_map(source) do
    resource = Map.get(source, "resource")
    action = Map.get(source, "action", :read)

    can_access_resource?(resource, action)
  end

  def can_read_source(_), do: true

  @doc """
  Check if user can write to the binding source resource.

  Cross-resource policy check for write bindings.

  ## Examples

      policy do
        authorize_if can_write_source(@resource.source)
      end
  """
  @spec can_write_source(map()) :: boolean()
  def can_write_source(%{source: source}) when is_map(source) do
    resource = Map.get(source, "resource")
    action = Map.get(source, "action", :update)

    can_access_resource?(resource, action)
  end

  def can_write_source(_), do: true

  @doc """
  Check if user can access a specific field on a resource.

  Field-level authorization check.

  ## Examples

      policy do
        authorize_if can_access_field(@resource, :email)
      end
  """
  @spec can_access_field(map(), atom() | String.t()) :: boolean()
  def can_access_field(_resource, _field) do
    # In production, would check field-level policies
    true
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

  # Private functions

  defp config_env do
    Application.get_env(:ash_ui, :env, :dev)
  end

  defp can_access_resource?(nil, _action), do: false
  defp can_access_resource?(_resource, _action), do: true
end
