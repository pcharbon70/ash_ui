defmodule AshUI.Rendering.SelectorTest do
  use ExUnit.Case, async: true

  alias AshUI.Rendering.Selector

  describe "Section 7.5 - Renderer Selection" do
    test "liveview_request? returns true for LiveView request with accept header" do
      request = %{
        headers: %{"accepts" => "text/vnd.phoenix.live-view"}
      }

      assert Selector.liveview_request?(request)
    end

    test "liveview_request? returns true for LiveView request with _format param" do
      request = %{
        params: %{"_format" => "live"}
      }

      assert Selector.liveview_request?(request)
    end

    test "liveview_request? returns false for standard HTTP request" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      refute Selector.liveview_request?(request)
    end

    test "liveview_request? returns false when no LiveView indicators present" do
      request = %{params: %{}, headers: %{}}

      refute Selector.liveview_request?(request)
    end

    test "http_request? returns true for HTML request" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      assert Selector.http_request?(request)
    end

    test "http_request? returns false for LiveView request" do
      request = %{
        headers: %{"accepts" => "text/vnd.phoenix.live-view"}
      }

      refute Selector.http_request?(request)
    end

    test "select_for_request selects liveview renderer for LiveView request" do
      request = %{
        headers: %{"accepts" => "text/vnd.phoenix.live-view"}
      }

      assert {:ok, :liveview, module} = Selector.select_for_request(request)
      assert is_atom(module)
    end

    test "select_for_request selects html renderer for HTTP request" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      assert {:ok, :html, module} = Selector.select_for_request(request)
      assert is_atom(module)
    end

    test "select_for_request respects explicit renderer override" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      assert {:ok, :liveview, module} = Selector.select_for_request(request, renderer: :liveview)
      assert is_atom(module)
    end

    test "select_for_request accepts available renderer type" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      assert {:ok, :desktop, _module} =
        Selector.select_for_request(request, renderer: :desktop)
    end

    test "select_for_request selects renderer from X-Renderer header" do
      request = %{
        headers: %{"x-renderer" => "liveview"}
      }

      assert {:ok, :liveview, _module} = Selector.select_for_request(request)
    end

    test "select_for_request selects html renderer from 'html' header value" do
      request = %{
        headers: %{"x-renderer" => "html"}
      }

      assert {:ok, :html, _module} = Selector.select_for_request(request)
    end

    test "select_for_request ignores header when ignore_headers option is true" do
      request = %{
        headers: %{"x-renderer" => "liveview", "accept" => "text/html"}
      }

      assert {:ok, :html, _module} = Selector.select_for_request(request, ignore_headers: true)
    end

    test "select_with_fallback returns selected renderer when available" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      assert {:ok, :html, _module, false} = Selector.select_with_fallback(request)
    end

    test "select_with_fallback returns fallback when primary unavailable" do
      request = %{
        headers: %{"x-renderer" => "desktop"}
      }

      result = Selector.select_with_fallback(request)
      assert match?({:ok, _, _, _}, result)
    end

    test "select_with_fallback includes from_cache flag" do
      request = %{
        headers: %{"accept" => "text/html"}
      }

      assert {:ok, _, _, from_cache} = Selector.select_with_fallback(request)
      assert is_boolean(from_cache)
    end

    test "get_fallback_renderer returns a renderer" do
      result = Selector.get_fallback_renderer()
      assert match?({:ok, _, _}, result)
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
      request = %{
        headers: %{"accepts" => "text/vnd.phoenix.live-view, application/json"}
      }

      assert Selector.liveview_request?(request)
    end

    test "detects LiveView from _format=live param" do
      request_map = %{
        params: %{"_format" => "live"}
      }

      assert Selector.liveview_request?(request_map)
    end

    test "detects LiveView from _format=liveview param" do
      request_map = %{
        params: %{"_format" => "liveview"}
      }

      assert Selector.liveview_request?(request_map)
    end

    test "detects HTTP from html accept header" do
      request = %{
        headers: %{"accept" => "text/html, application/xhtml+xml"}
      }

      assert Selector.http_request?(request)
    end

    test "detects HTTP from xhtml accept header" do
      request = %{
        headers: %{"accept" => "application/xhtml+xml"}
      }

      assert Selector.http_request?(request)
    end

    test "handles lowercase header names in map" do
      request = %{
        "headers" => %{"accepts" => "text/vnd.phoenix.live-view"}
      }

      assert Selector.liveview_request?(request)
    end

    test "handles x- prefix header variations" do
      request = %{
        "headers" => %{"http-x-renderer" => "liveview"}
      }

      assert {:ok, :liveview, _} = Selector.select_for_request(request)
    end
  end
end
