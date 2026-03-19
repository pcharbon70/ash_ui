import Config

# Configure your database
config :ash_ui, AshUI.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ash_ui_dev",
  pool_size: 10

# Configure Ash for dev
config :ash, AshUI.Domain,
  authorize: false

# Configure Ash to use the domain
config :ash, :domains, [AshUI.Domain]
