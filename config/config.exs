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

# Configure AshUI Rendering
config :ash_ui, :rendering,
  # Default renderer: :liveview, :html, or :desktop
  default_renderer: :liveview,
  # Enable automatic renderer detection based on context
  auto_detect: true,
  # Fallback renderer if primary is unavailable
  fallback_renderer: nil,
  # Renderer-specific options
  renderers: %{
    liveview: [
      # Enable LiveView optimizations
      optimize_patches: true,
      # Default LiveView module for renders
      view_module: nil
    ],
    html: [
      # Enable SEO meta tags
      seo_enabled: true,
      # Elm client integration
      elm_enabled: false,
      elm_module: "Main"
    ],
    desktop: [
      # Window properties
      window_width: 1280,
      window_height: 720,
      window_resizable: true,
      # Platform-specific features
      native_menu_bar: true
    ]
  }

# Import environment specific config
import_config "#{config_env()}.exs"
