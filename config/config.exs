import Config

# Configure AshUI Domain
config :ash_ui, AshUI.Domain,
  resources: [
    AshUI.Resources.Screen,
    AshUI.Resources.Element,
    AshUI.Resources.Binding
  ]

# Configure Ash
config :ash, :domains, [AshUI.Domain]

# Configure AshPostgres
config :ash, AshUI.Repo,
  timeout: 30_000,
  poll_interval: 50_000

# Import environment specific config
import_config "#{config_env()}.exs"
