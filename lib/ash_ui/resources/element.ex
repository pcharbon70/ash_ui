defmodule AshUI.Resources.Element do
  @moduledoc """
  Ash Resource for storing unified-ui element definitions.

  Elements are atomic UI components (widgets) like buttons, inputs, text, etc.
  """

  use Ash.Resource,
    domain: AshUI.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ui_elements"
    repo AshUI.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :type, :atom, allow_nil?: false
    attribute :props, :map, default: %{}
    attribute :variants, {:array, :atom}, default: []
    attribute :position, :integer, default: 0
    attribute :metadata, :map, default: %{}
    attribute :active, :boolean, default: true
    attribute :version, :integer, default: 1
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :screen, AshUI.Resources.Screen do
      attribute_type :uuid
      allow_nil? true
    end

    has_many :bindings, AshUI.Resources.Binding do
      destination_attribute :element_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:type, :props, :variants, :position, :screen_id, :metadata, :active, :version]
    end

    update :update do
      primary? true
      accept [:type, :props, :variants, :position, :screen_id, :metadata, :active]
      change increment(:version)
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
