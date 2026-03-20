defmodule BasicDashboardLive do
  use Phoenix.LiveView

  alias AshUI.LiveView.EventHandler
  alias AshUI.LiveView.Integration

  def mount(_params, _session, socket) do
    socket = assign(socket, :current_user, %{id: "admin-1", role: :admin, active: true})
    Integration.mount_ui_screen(socket, :basic_dashboard, %{})
  end

  def handle_event("ash_ui_change", params, socket) do
    EventHandler.handle_value_change(params, socket)
  end

  def handle_event("ash_ui_action", params, socket) do
    EventHandler.handle_action_event(params, socket)
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>{@ash_ui_screen.name}</h1>
      <pre><%= inspect(@ash_ui_iur, pretty: true) %></pre>
    </section>
    """
  end
end
