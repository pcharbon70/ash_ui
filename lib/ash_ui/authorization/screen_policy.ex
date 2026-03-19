defmodule AshUI.Authorization.ScreenPolicy do
  @moduledoc """
  Policy definitions for AshUI.Screen resource.

  Defines access control for screen viewing, mounting, and management.
  """

  @behaviour Ash.Policy.Authorizer

  alias AshUI.Authorization.Policies

  @doc """
  Defines policies for screen resource access.
  """
  def policies do
    [
      # Read policy - users can view screens they have access to
      %Ash.Policy.Policy{
        description: "Users can view screens they have access to",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, [:admin, :user]) and
              Policies.user_active(@actor)
          )
        ]
      },

      # Mount policy - screens must be explicitly mountable
      %Ash.Policy.Policy{
        description: "Users can mount screens they have access to",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, [:admin, :user]) and
              Policies.user_active(@actor) and
              (@resource.public == true or
                 Policies.screen_owner(@actor, @resource) or
                 Policies.user_role(@actor, :admin))
          )
        ]
      },

      # Create policy - admins can create screens
      %Ash.Policy.Policy{
        description: "Only admins can create screens",
        policies: [
          Ash.Policy.Authorizer.expr(
            Policies.user_role(@actor, :admin) and
              Policies.user_active(@actor)
          )
        ]
      },

      # Update policy - owners and admins can update screens
      %Ash.Policy.Policy{
        description: "Owners and admins can update screens",
        policies: [
          Ash.Policy.Authorizer.expr(
            (Policies.screen_owner(@actor, @resource) or
               Policies.user_role(@actor, :admin)) and
              Policies.user_active(@actor)
          )
        ]
      },

      # Destroy policy - owners and admins can delete screens
      %Ash.Policy.Policy{
        description: "Owners and admins can delete screens",
        policies: [
          Ash.Policy.Authorizer.expr(
            (Policies.screen_owner(@actor, @resource) or
               Policies.user_role(@actor, :admin)) and
              Policies.user_active(@actor)
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
  Filter screens based on user access.
  """
  def filter_screens(user) do
    base_filter = [active: true]

    user_filter =
      case user do
        %{role: :admin} -> []
        %{id: user_id} -> [or: [[public: true], [owner_id: user_id]]]
        _ -> [public: true]
      end

    base_filter ++ user_filter
  end

  @doc """
  Check if user can mount a specific screen.
  """
  def can_mount?(user, screen) do
    cond do
      # Admins can mount any screen
      Policies.user_role(user, :admin) -> true

      # Public screens can be mounted by active users
      Map.get(screen, :public, false) and Policies.user_active(user) -> true

      # Owners can mount their screens
      Policies.screen_owner(user, screen) and Policies.user_active(user) -> true

      # Development bypass
      Policies.environment([:dev, :test]) -> true

      # Default deny
      true -> false
    end
  end
end
