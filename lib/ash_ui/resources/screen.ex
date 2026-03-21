defmodule AshUI.Resources.Screen do
  @moduledoc """
  Ash Resource for storing unified-ui screen definitions.
  """

  use Ash.Resource,
    domain: AshUI.Domain,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ui_screens"
    repo AshUI.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :unified_dsl, :map, default: %{}
    attribute :layout, :atom, default: :default
    attribute :route, :string
    attribute :metadata, :map, default: %{}
    attribute :active, :boolean, default: true
    attribute :version, :integer, default: 1
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    has_many :elements, AshUI.Resources.Element do
      destination_attribute :screen_id
    end

    has_many :bindings, AshUI.Resources.Binding do
      destination_attribute :screen_id
    end
  end

  actions do
    defaults [:read]

    read :mount do
      get? true
    end

    create :create do
      primary? true
      accept [:name, :unified_dsl, :layout, :route, :metadata, :active, :version]
    end

    update :update do
      primary? true
      accept [:name, :unified_dsl, :layout, :route, :metadata, :active]
      change increment(:version)
    end

    destroy :destroy do
      primary? true
      change cascade_destroy(:elements)
    end
  end

  policies do
    bypass actor_absent() do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action([:read, :mount]) do
      authorize_if {AshUI.Authorization.Checks.ScreenAccess, mode: :read}
    end

    policy action(:create) do
      authorize_if {AshUI.Authorization.Checks.ScreenAccess, mode: :manage}
    end

    policy action([:update, :destroy]) do
      authorize_if {AshUI.Authorization.Checks.ScreenAccess, mode: :manage}
    end
  end
end
