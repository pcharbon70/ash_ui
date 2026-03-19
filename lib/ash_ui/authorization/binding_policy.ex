defmodule AshUI.Authorization.BindingPolicy do
  @moduledoc """
  Policy definitions for AshUI.Binding resource.

  Defines access control for binding evaluation and modification.
  """

  alias AshUI.Authorization.Policies

  @doc """
  Defines policies for binding resource access.
  """
  def policies do
    [
      # Read/evaluation policy - bindings inherit from parent
      %Ash.Policy.Policy{
        description: "Bindings are evaluable if parent screen is accessible",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_active(@actor) and
              can_access_binding?(@actor, @resource)
          )
        ]
      },

      # Create policy - inherit from screen
      %Ash.Policy.Policy{
        description: "Can create bindings if can modify parent screen",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, :admin) or
              (Policies.user_active(@actor) and
                 screen_owned?(@actor, @resource))
          )
        ]
      },

      # Update policy - inherit from screen
      %Ash.Policy.Policy{
        description: "Can update bindings if can modify parent screen",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, :admin) or
              (Policies.user_active(@actor) and
                 screen_owned?(@actor, @resource))
          )
        ]
      },

      # Destroy policy - inherit from screen
      %Ash.Policy.Policy{
        description: "Can delete bindings if can modify parent screen",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, :admin) or
              (Policies.user_active(@actor) and
                 screen_owned?(@actor, @resource))
          )
        ]
      },

      # Data source access policy
      %Ash.Policy.Policy{
        description: "Must have access to binding source data",
        policies: [
          Ash.Policy.Authorizer.expr(
            has_data_access?(@resource, @actor)
          )
        ]
      },

      # Development environment bypass
      %Ash.Policy.Policy{
        description: "Development environment bypass",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.environment([:dev, :test])
          )
        ]
      }
    ]
  end

  @doc """
  Check if user can evaluate a binding.
  """
  def can_evaluate?(user, binding) do
    cond do
      # Development bypass
      Policies.environment([:dev, :test]) -> true

      # Admins can evaluate all bindings
      Policies.user_role(user, :admin) -> true

      # User must be active
      not Policies.user_active(user) -> false

      # Check data source access
      not has_data_access?(binding, user) -> false

      # Default allow
      true -> true
    end
  end

  @doc """
  Check if user can write to a binding.
  """
  def can_write?(user, binding) do
    cond do
      # Development bypass
      Policies.environment([:dev, :test]) -> true

      # Admins can write to all bindings
      Policies.user_role(user, :admin) -> true

      # User must be active
      not Policies.user_active(user) -> false

      # Check if binding is read-only
      Map.get(binding, :read_only, false) -> false

      # Check write access to data source
      not has_write_access?(binding, user) -> false

      # Default allow
      true -> true
    end
  end

  @doc """
  Get redacted value for binding if user is unauthorized.

  Returns a placeholder value instead of actual data.
  """
  def redacted_value(binding) do
    case Map.get(binding, :binding_type) do
      :value -> "[PROTECTED]"
      :list -> []
      :action -> nil
      _ -> nil
    end
  end

  @doc """
  Check if binding source resource is accessible.
  """
  def source_accessible?(user, binding) do
    source = Map.get(binding, :source, %{})

    cond do
      # No source means no restriction
      map_size(source) == 0 -> true

      # Check resource-level access
      not Policies.can_read_source(binding) -> false

      # Check field-level access
      not field_accessible?(user, binding) -> false

      # Default allow
      true -> true
    end
  end

  # Private functions

  defp can_access_binding?(user, binding) do
    # In production, would check parent screen access
    Policies.user_active(user)
  end

  defp screen_owned?(user, binding) do
    # In production, would check parent screen ownership
    true
  end

  defp has_data_access?(binding, user) do
    source = Map.get(binding, :source, %{})

    cond do
      map_size(source) == 0 -> true
      not Policies.can_read_source(binding) -> false
      not Policies.can_access_field(binding.source, Map.get(source, "field")) -> false
      true -> true
    end
  end

  defp has_write_access?(binding, user) do
    source = Map.get(binding, :source, %{})

    cond do
      map_size(source) == 0 -> true
      not Policies.can_write_source(binding) -> false
      true -> true
    end
  end

  defp field_accessible?(user, binding) do
    source = Map.get(binding, :source, %{})
    field = Map.get(source, "field")

    case field do
      nil -> true
      _ -> Policies.can_access_field(binding, field)
    end
  end
end
