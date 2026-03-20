import Config

if config_env() == :prod do
  config :ash_ui, AshUI.Repo,
    username: System.get_env("DATABASE_USERNAME") || "postgres",
    password: System.get_env("DATABASE_PASSWORD") || "postgres",
    hostname: System.get_env("DATABASE_HOSTNAME") || "localhost",
    database: System.get_env("DATABASE_NAME") || "ash_ui_prod",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
