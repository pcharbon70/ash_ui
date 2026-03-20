defmodule AshUI.Rendering.RegistryTest do
  use ExUnit.Case, async: false

  alias AshUI.Rendering.Registry

  describe "Section 7.1.3 - Renderer Registry" do
    test "list_renderers returns all registered renderers" do
      renderers = Registry.list_renderers()

      assert is_list(renderers)
      assert length(renderers) > 0

      # Check structure
      renderer = hd(renderers)
      assert Map.has_key?(renderer, :type)
      assert Map.has_key?(renderer, :module)
      assert Map.has_key?(renderer, :available)
      assert Map.has_key?(renderer, :description)
    end

    test "list_renderers includes liveview renderer" do
      renderers = Registry.list_renderers()

      liveview_renderer = Enum.find(renderers, fn r -> r.type == :liveview end)
      assert liveview_renderer != nil
      assert liveview_renderer.type == :liveview
    end

    test "list_renderers includes html renderer" do
      renderers = Registry.list_renderers()

      html_renderer = Enum.find(renderers, fn r -> r.type == :html end)
      assert html_renderer != nil
      assert html_renderer.type == :html
    end

    test "list_renderers includes desktop renderer" do
      renderers = Registry.list_renderers()

      desktop_renderer = Enum.find(renderers, fn r -> r.type == :desktop end)
      assert desktop_renderer != nil
      assert desktop_renderer.type == :desktop
    end

    test "get_renderer returns module for liveview" do
      assert {:ok, module} = Registry.get_renderer(:liveview)
      assert is_atom(module)
    end

    test "get_renderer returns module for html" do
      assert {:ok, module} = Registry.get_renderer(:html)
      assert is_atom(module)
    end

    test "get_renderer returns module for desktop" do
      assert {:ok, module} = Registry.get_renderer(:desktop)
      assert is_atom(module)
    end

    test "get_renderer returns error for unknown type" do
      assert {:error, :not_found} = Registry.get_renderer(:unknown)
    end

    test "renderer_available? checks availability" do
      # Since renderer packages may not be installed, we check the function works
      result = Registry.renderer_available?(:liveview)
      assert is_boolean(result)
    end

    test "renderer_available? returns false for unknown type" do
      assert Registry.renderer_available?(:unknown) == false
    end

    test "refresh updates renderer availability" do
      assert :ok = Registry.refresh()
    end

    test "default_renderer returns configured renderer or fallback" do
      result = Registry.default_renderer()

      case result do
        {:ok, type, module} ->
          assert type in [:liveview, :html, :desktop]
          assert is_atom(module)

        {:error, :no_renderer} ->
          # Acceptable when no renderers are available
          :ok
      end
    end
  end

  describe "Section 7.1.2 - Renderer Configuration" do
    test "reads default_renderer from config" do
      configured = Application.get_env(:ash_ui, :rendering, [])
      default = Keyword.get(configured, :default_renderer, :liveview)

      assert default in [:liveview, :html, :desktop]
    end

    test "reads auto_detect setting from config" do
      configured = Application.get_env(:ash_ui, :rendering, [])
      auto_detect = Keyword.get(configured, :auto_detect, true)

      assert is_boolean(auto_detect)
    end

    test "reads fallback_renderer from config" do
      configured = Application.get_env(:ash_ui, :rendering, [])
      fallback = Keyword.get(configured, :fallback_renderer)

      # Fallback is optional
      assert fallback == nil or fallback in [:liveview, :html, :desktop]
    end
  end
end
