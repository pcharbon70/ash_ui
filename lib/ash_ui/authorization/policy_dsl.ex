defmodule AshUI.Authorization.PolicyDSL do
  @moduledoc """
  DSL extensions for common UI authorization patterns.

  Provides convenience functions for defining UI policies
  in a more declarative way.
  """

  alias AshUI.Authorization.Policies

  @doc """
  Policy helper: element is visible if condition is met.

  ## Examples

      policy do
        authorize_if visible_if(@actor, & &1.role == :admin)
      end
  """
  def visible_if(user, condition) when is_function(condition, 1) do
    case user do
      nil -> false
      _ -> condition.(user)
    end
  end

  def visible_if(user, {field, value}) do
    case user do
      nil -> false
      %{^field => user_value} -> user_value == value
      _ -> false
    end
  end

  def visible_if(_user, condition) when is_boolean(condition) do
    condition
  end

  @doc """
  Policy helper: element is editable if condition is met.

  ## Examples

      policy do
        authorize_if editable_if(@actor, fn user ->
          user.role == :admin or user.id == @resource.owner_id
        end)
      end
  """
  def editable_if(user, condition) when is_function(condition, 1) do
    case user do
      nil -> false
      _ -> condition.(user)
    end
  end

  def editable_if(user, roles) when is_list(roles) do
    Policies.user_role(user, roles)
  end

  def editable_if(user, role) when is_atom(role) do
    Policies.user_role(user, role)
  end

  @doc """
  Policy helper: resource is accessible if condition is met.

  ## Examples

      policy do
        authorize_if accessible_if(@actor, @resource)
      end
  """
  def accessible_if(user, resource) do
    cond do
      is_nil(user) -> false
      not Policies.user_active(user) -> false
      Map.get(resource, :public, false) -> true
      Policies.screen_owner(user, resource) -> true
      Policies.user_role(user, :admin) -> true
      true -> false
    end
  end

  @doc """
  Policy helper: user can read binding source resource.

  ## Examples

      policy do
        authorize_if can_read_source(@resource)
      end
  """
  def can_read_source(binding) do
    Policies.can_read_source(binding)
  end

  @doc """
  Policy helper: user can write to binding source resource.

  ## Examples

      policy do
        authorize_if can_write_source(@resource)
      end
  """
  def can_write_source(binding) do
    Policies.can_write_source(binding)
  end

  @doc """
  Policy helper: user can access specific field on resource.

  ## Examples

      policy do
        authorize_if can_access_field(@resource, :email)
      end
  """
  def can_access_field(resource, field) do
    Policies.can_access_field(resource, field)
  end

  @doc """
  Policy helper: user can execute specific action.

  ## Examples

      policy do
        authorize_if can_execute_action(@resource, :delete)
      end
  """
  def can_execute_action(resource, action) do
    Policies.can_execute_action(resource, action)
  end

  @doc """
  Builds a visibility policy for an element.

  Returns a policy map that can be used in element definitions.

  ## Examples

      element_policy = PolicyDSL.build_visibility_policy(fn user ->
        user.role == :admin
      end)
  """
  def build_visibility_policy(condition) do
    %{
      type: :visibility,
      condition: condition
    }
  end

  @doc """
  Builds an editability policy for an element.

  ## Examples

      edit_policy = PolicyDSL.build_editability_policy([:admin, :editor])
  """
  def build_editability_policy(roles) when is_list(roles) do
    %{
      type: :editability,
      condition: {:roles, roles}
    }
  end

  def build_editability_policy(condition) when is_function(condition, 1) do
    %{
      type: :editability,
      condition: condition
    }
  end

  @doc """
  Builds an access policy for a resource.

  ## Examples

      access_policy = PolicyDSL.build_access_policy(:read, fn user, resource ->
        resource.public == true or Policies.screen_owner(user, resource)
      end)
  """
  def build_access_policy(action, condition) do
    %{
      type: :access,
      action: action,
      condition: condition
    }
  end

  @doc """
  Combines multiple policies with AND logic.

  All policies must pass for access to be granted.

  ## Examples

      combined = PolicyDSL.all_of([
        Policies.user_active(@actor),
        Policies.user_role(@actor, :admin)
      ])
  """
  def all_of(policies) when is_list(policies) do
    fn user, resource ->
      Enum.all?(policies, fn
        policy when is_function(policy, 2) -> policy.(user, resource)
        policy when is_function(policy, 1) -> policy.(user)
        value -> value
      end)
    end
  end

  @doc """
  Combines multiple policies with OR logic.

  At least one policy must pass for access to be granted.

  ## Examples

      combined = PolicyDSL.any_of([
        Policies.user_role(@actor, :admin),
        Policies.screen_owner(@actor, @resource)
      ])
  """
  def any_of(policies) when is_list(policies) do
    fn user, resource ->
      Enum.any?(policies, fn
        policy when is_function(policy, 2) -> policy.(user, resource)
        policy when is_function(policy, 1) -> policy.(user)
        value -> value
      end)
    end
  end

  @doc """
  Negates a policy condition.

  ## Examples

      not_admin = PolicyDSL.not_(&Policies.user_role(&1, :admin))
  """
  def not_(policy) when is_function(policy, 1) do
    fn user -> not policy.(user) end
  end

  def not_(policy) when is_function(policy, 2) do
    fn user, resource -> not policy.(user, resource) end
  end

  @doc """
  Creates a policy that checks time-based access.

  ## Examples

      business_hours = PolicyDSL.time_policy(
        Time.utc_now().hour,
        fn hour -> hour >= 9 and hour < 17 end
      )
  """
  def time_policy(value, condition) when is_function(condition, 1) do
    condition.(value)
  end

  @doc """
  Creates a policy that checks environment-based access.

  ## Examples

      dev_only = PolicyDSL.environment_policy(:dev)
      dev_or_test = PolicyDSL.environment_policy([:dev, :test])
  """
  def environment_policy(envs) when is_list(envs) do
    Policies.environment(envs)
  end

  def environment_policy(env) when is_atom(env) do
    Policies.environment(env)
  end

  @doc """
  Policy documentation helper.

  Returns a documentation map for a policy.

  ## Examples

      policy_docs = PolicyDSL.document_policy(:screen_read, %{
        description: "Allows reading of public screens or owned screens",
        checks: [:user_active, :screen_public_or_owned]
      })
  """
  def document_policy(name, attrs) do
    Map.put(attrs, :name, name)
  end

  @doc """
  Generates policy documentation for a resource.

  ## Examples

      docs = PolicyDSL.generate_policy_docs(AshUI.Screen)
  """
  def generate_policy_docs(resource_module) do
    %{
      resource: resource_module,
      policies: list_policies(resource_module),
      checks: list_checks(resource_module)
    }
  end

  # Private functions

  defp list_policies(_resource_module) do
    # In production, would extract from resource definition
    [:read, :mount, :create, :update, :destroy]
  end

  defp list_checks(_resource_module) do
    # In production, would extract from resource definition
    [:user_active, :user_role, :screen_owner, :environment]
  end
end
