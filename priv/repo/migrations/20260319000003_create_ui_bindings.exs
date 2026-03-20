defmodule AshUi.Repo.Migrations.CreateUiBindings do
  use Ecto.Migration

  def change do
    create table(:ui_bindings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :source, :map, default: "{}"
      add :target, :string
      add :binding_type, :string, default: "value"
      add :transform, :map, default: "{}"
      add :element_id, references(:ui_elements, type: :uuid, on_delete: :delete_all)
      add :screen_id, references(:ui_screens, type: :uuid, on_delete: :delete_all)
      add :metadata, :map, default: "{}"
      add :version, :integer, default: 1
      timestamps(type: :utc_datetime)
      add :active, :boolean, default: true
    end

    create index(:ui_bindings, [:element_id])
    create index(:ui_bindings, [:screen_id])
    create index(:ui_bindings, [:element_id, :screen_id])
    create index(:ui_bindings, [:binding_type])
    create index(:ui_bindings, [:active])
  end
end
