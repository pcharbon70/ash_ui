defmodule Repo.Migrations.AddVersionToUiElements do
  use Ecto.Migration

  def change do
    alter table(:ui_elements, primary_key: false) do
      add :version, :integer, default: 1, null: false
    end
  end
end
