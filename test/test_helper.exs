ExUnit.start()
ExUnit.configure(exclude: [skip: true])

# Start the application for tests
Application.put_env(:ash_ui, :ash_domains, [AshUI.Domain])

# Ecto migrations are handled by AshPostgres
# Ensure the Repo is started for tests
{:ok, _} = Application.ensure_all_started(:ash_ui)
