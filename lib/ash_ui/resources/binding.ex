defmodule AshUI.Resources.Binding do
  @moduledoc """
  Ash Resource for data binding definitions.

  Bindings connect UI elements to Ash resource data.
  """

  use Ash.Resource,
    domain: AshUI.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ui_bindings"
    repo AshUI.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :source, :map, allow_nil?: false, default: %{}
    attribute :target, :string, allow_nil?: false
    attribute :binding_type, :atom, constraints: [one_of: [:value, :list, :action]]
    attribute :transform, :map, default: %{}
    attribute :metadata, :map, default: %{}
    attribute :active, :boolean, default: true
    attribute :version, :integer, default: 1
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :element, AshUI.Resources.Element do
      attribute_type :uuid
      allow_nil? true
    end

    belongs_to :screen, AshUI.Resources.Screen do
      attribute_type :uuid
      allow_nil? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:source, :target, :binding_type, :transform, :element_id, :screen_id, :metadata, :active, :version]
    end

    update :update do
      primary? true
      accept [:source, :target, :binding_type, :transform, :element_id, :screen_id, :metadata, :active]
      change increment(:version)
    end

    read :read_with_filter do
      filter expr(active == true)
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
