defmodule AshUI.Resources.Screen do
  @moduledoc """
  Ash Resource for storing unified-ui screen definitions.
  """

  use Ash.Resource,
    domain: AshUI.Domain,
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

  # Note: Policy DSL requires Ash.Policy.Authorizer extension
  # This will be added when authorization policies are fully implemented
  # policies do
  #   policy action(:read) do
  #     authorize_if expr(active == true)
  #   end
  # end
end
