defmodule Repo.Migrations.AddScreenFkToUiElements do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ui_elements_screen_id_fkey'
      ) THEN
        ALTER TABLE ui_elements
        ADD CONSTRAINT ui_elements_screen_id_fkey
        FOREIGN KEY (screen_id)
        REFERENCES ui_screens(id)
        ON DELETE CASCADE;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("""
    ALTER TABLE ui_elements
    DROP CONSTRAINT IF EXISTS ui_elements_screen_id_fkey
    """)
  end
end
