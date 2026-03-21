defmodule AshUI.Rendering.SelectorTest do
  use ExUnit.Case, async: false

  alias AshUI.Rendering.{Registry, Selector}
  alias AshUI.Telemetry

  setup do
    Telemetry.reset_metrics()
    :ok
  end

  describe "Section 7.5 - Renderer Selection" do
    test "liveview_request? returns true for LiveView request with accept header" do
      request = %{headers: %{"accepts" => "text/vnd.phoenix.live-view"}}
      assert Selector.liveview_request?(request)
    end

    test "liveview_request? returns true for LiveView request with _format param" do
      request = %{params: %{"_format" => "live"}}
      assert Selector.liveview_request?(request)
    end

    test "liveview_request? returns false for standard HTTP request" do
      request = %{headers: %{"accept" => "text/html"}}
      refute Selector.liveview_request?(request)
    end

    test "liveview_request? returns false when no LiveView indicators present" do
      request = %{params: %{}, headers: %{}}
      refute Selector.liveview_request?(request)
    end

    test "http_request? returns true for HTML request" do
      request = %{headers: %{"accept" => "text/html"}}
      assert Selector.http_request?(request)
    end

    test "http_request? returns false for LiveView request" do
      request = %{headers: %{"accepts" => "text/vnd.phoenix.live-view"}}
      refute Selector.http_request?(request)
    end

    test "select_for_request selects liveview renderer for LiveView request" do
      request = %{headers: %{"accepts" => "text/vnd.phoenix.live-view"}}

      assert {:ok, :liveview, module} = Selector.select_for_request(request)
      assert {:ok, info} = Registry.renderer_info(:liveview)
      assert module == info.module
    end

    test "select_for_request selects html renderer for HTTP request" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, :html, module} = Selector.select_for_request(request)
      assert {:ok, info} = Registry.renderer_info(:html)
      assert module == info.module
    end

    test "select_for_request respects explicit renderer override" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, :liveview, module} = Selector.select_for_request(request, renderer: :liveview)
      assert {:ok, info} = Registry.renderer_info(:liveview)
      assert module == info.module
    end

    test "select_for_request accepts available renderer type" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, :desktop, module} = Selector.select_for_request(request, renderer: :desktop)
      assert {:ok, info} = Registry.renderer_info(:desktop)
      assert module == info.module
    end

    test "select_for_request can require an external renderer" do
      request = %{headers: %{"accept" => "text/html"}}
      assert {:ok, info} = Registry.renderer_info(:desktop, allow_adapter_fallback: false)

      result =
        Selector.select_for_request(request, renderer: :desktop, allow_adapter_fallback: false)

      if info.available do
        assert {:ok, :desktop, module} = result
        assert module == info.module
      else
        assert {:error, {:renderer_not_available, :desktop}} = result
      end
    end

    test "select_for_request selects renderer from X-Renderer header" do
      request = %{headers: %{"x-renderer" => "liveview"}}
      assert {:ok, :liveview, _module} = Selector.select_for_request(request)
    end

    test "select_for_request selects html renderer from html header value" do
      request = %{headers: %{"x-renderer" => "html"}}
      assert {:ok, :html, _module} = Selector.select_for_request(request)
    end

    test "select_for_request ignores header when ignore_headers option is true" do
      request = %{headers: %{"x-renderer" => "liveview", "accept" => "text/html"}}
      assert {:ok, :html, _module} = Selector.select_for_request(request, ignore_headers: true)
    end

    test "select_with_fallback reports adapter fallback usage" do
      request = %{headers: %{"accept" => "text/html"}}
      assert {:ok, info} = Registry.renderer_info(:html)

      assert {:ok, :html, module, fallback_used} = Selector.select_with_fallback(request)
      assert module == info.module
      assert fallback_used == (info.mode == :adapter_fallback)
    end

    test "select_with_fallback can switch renderer types when primary is unavailable" do
      request = %{headers: %{"x-renderer" => "desktop"}}

      result =
        Selector.select_with_fallback(
          request,
          allow_adapter_fallback: false,
          fallback_renderer: :html,
          fallback_allow_adapter_fallback: true
        )

      assert {:ok, desktop_info} = Registry.renderer_info(:desktop, allow_adapter_fallback: false)

      if desktop_info.available do
        assert {:ok, :desktop, module, false} = result
        assert module == desktop_info.module
      else
        assert {:ok, :html, module, true} = result
        assert {:ok, html_info} = Registry.renderer_info(:html)
        assert module == html_info.module
      end
    end

    test "select_with_fallback falls back from unknown renderer header" do
      request = %{headers: %{"x-renderer" => "printer", "accept" => "text/html"}}

      assert {:ok, :html, module, true} = Selector.select_with_fallback(request)
      assert {:ok, html_info} = Registry.renderer_info(:html)
      assert module == html_info.module
    end

    test "select_with_fallback records fallback telemetry" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, _type, _module, _fallback_used} = Selector.select_with_fallback(request)

      snapshot = Telemetry.snapshot()
      assert snapshot.dashboards.renderer_usage.fallback >= 0

      assert {:ok, info} = Registry.renderer_info(:html)

      expected_fallback_count =
        if info.mode == :adapter_fallback do
          1
        else
          0
        end

      assert snapshot.dashboards.renderer_usage.fallback == expected_fallback_count
    end

    test "get_fallback_renderer returns a renderer" do
      result = Selector.get_fallback_renderer()
      assert match?({:ok, _, _}, result)
    end

    test "get_fallback_renderer honors explicit fallback policy" do
      result =
        Selector.get_fallback_renderer(
          fallback_renderer: :html,
          allow_adapter_fallback: false,
          fallback_allow_adapter_fallback: true
        )

      assert {:ok, :html, module} = result
      assert {:ok, info} = Registry.renderer_info(:html)
      assert module == info.module
    end

    test "select_for_environment selects renderer for dev environment" do
      assert {:ok, _, module} = Selector.select_for_environment(:dev)
      assert is_atom(module)
    end

    test "select_for_environment selects renderer for test environment" do
      assert {:ok, _, module} = Selector.select_for_environment(:test)
      assert is_atom(module)
    end

    test "select_for_environment selects renderer for prod environment" do
      assert {:ok, _, module} = Selector.select_for_environment(:prod)
      assert is_atom(module)
    end

    test "select_for_environment returns error for invalid environment" do
      assert {:error, _} = Selector.select_for_environment(:invalid)
    end

    test "detects LiveView from accepts header" do
      request = %{headers: %{"accepts" => "text/vnd.phoenix.live-view, application/json"}}
      assert Selector.liveview_request?(request)
    end

    test "detects LiveView from _format=live param" do
      request = %{params: %{"_format" => "live"}}
      assert Selector.liveview_request?(request)
    end

    test "detects LiveView from _format=liveview param" do
      request = %{params: %{"_format" => "liveview"}}
      assert Selector.liveview_request?(request)
    end

    test "detects HTTP from html accept header" do
      request = %{headers: %{"accept" => "text/html, application/xhtml+xml"}}
      assert Selector.http_request?(request)
    end

    test "detects HTTP from xhtml accept header" do
      request = %{headers: %{"accept" => "application/xhtml+xml"}}
      assert Selector.http_request?(request)
    end

    test "handles lowercase header names in map" do
      request = %{"headers" => %{"accepts" => "text/vnd.phoenix.live-view"}}
      assert Selector.liveview_request?(request)
    end

    test "handles x- prefix header variations" do
      request = %{"headers" => %{"http-x-renderer" => "liveview"}}
      assert {:ok, :liveview, _} = Selector.select_for_request(request)
    end
  end
end
