defmodule AshUI.Authorization.ElementPolicy do
  @moduledoc """
  Policy definitions for AshUI.Element resource.

  Defines access control for element visibility and modification.
  """

  alias AshUI.Authorization.Policies

  @doc """
  Defines policies for element resource access.
  """
  def policies do
    [
      # Read/visibility policy - elements inherit screen policies
      %Ash.Policy.Policy{
        description: "Elements are visible if parent screen is accessible",
        policies: [
          Ash.Policy.Authorizer.expr(
            # Can see element if can access parent screen
            Policies.user_active(@actor) and
              screen_accessible?(@actor, @resource)
          )
        ]
      },

      # Create policy - inherit from screen
      %Ash.Policy.Policy{
        description: "Can create elements if can modify parent screen",
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
        description: "Can update elements if can modify parent screen",
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
        description: "Can delete elements if can modify parent screen",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, :admin) or
              (Policies.user_active(@actor) and
                 screen_owned?(@actor, @resource))
          )
        ]
      },

      # Element-specific visibility policies
      %Ash.Policy.Policy{
        description: "Respects element visibility conditions",
        policies: [
          Ash.Policy.Authorizer.expr(
            # Element is visible if condition is met or no condition
            element_visible?(@resource)
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
  Check if element should be visible to user.
  """
  def visible?(user, element) do
    cond do
      # Development bypass
      Policies.environment([:dev, :test]) -> true

      # Admins see all elements
      Policies.user_role(user, :admin) -> true

      # User must be active
      not Policies.user_active(user) -> false

      # Check element visibility conditions
      not meets_visibility_condition?(element, user) -> false

      # Check parent screen access
      not screen_accessible?(user, element) -> false

      # Default visible
      true -> true
    end
  end

  @doc """
  Check if element is editable by user.
  """
  def editable?(user, element) do
    cond do
      # Development bypass
      Policies.environment([:dev, :test]) -> true

      # Admins can edit all elements
      Policies.user_role(user, :admin) -> true

      # User must be active
      not Policies.user_active(user) -> false

      # Check if element is explicitly read-only
      Map.get(element, :read_only, false) -> false

      # Must own parent screen
      not screen_owned?(user, element) -> false

      # Default editable
      true -> true
    end
  end

  # Private functions

  defp screen_accessible?(user, element) do
    # In production, would check if user can access parent screen
    true
  end

  defp screen_owned?(user, element) do
    # In production, would check if user owns parent screen
    true
  end

  defp element_visible?(element) do
    # Check if element has visibility condition
    case Map.get(element, :visible_when) do
      nil -> true
      condition when is_function(condition, 0) -> condition.()
      condition when is_boolean(condition) -> condition
      _ -> true
    end
  end

  defp meets_visibility_condition?(element, user) do
    case Map.get(element, :visible_when) do
      nil -> true
      {field, value} ->
        # Check user field matches required value
        Map.get(user, field) == value
      condition when is_function(condition, 1) -> condition.(user)
      _ -> true
    end
  end
end
