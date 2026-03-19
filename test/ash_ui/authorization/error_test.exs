defmodule AshUI.AuthorizationErrorTest do
  use ExUnit.Case, async: true

  alias AshUI.AuthorizationError

  describe "new/1" do
    test "creates new error with options" do
      error = AuthorizationError.new(
        resource: AshUI.Screen,
        action: :mount,
        reason: :forbidden
      )

      assert error.resource == AshUI.Screen
      assert error.action == :mount
      assert error.reason == :forbidden
    end

    test "creates error with policy and details" do
      error = AuthorizationError.new(
        resource: AshUI.Screen,
        action: :mount,
        reason: :forbidden,
        policy: "admin_only",
        details: %{message: "Admin access required"}
      )

      assert error.policy == "admin_only"
      assert error.details.message == "Admin access required"
    end
  end

  describe "unauthenticated/2" do
    test "creates unauthenticated error" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)

      assert error.resource == AshUI.Screen
      assert error.action == :mount
      assert error.reason == :unauthenticated
      assert error.policy == "authentication_required"
      assert error.details.message == "You must be logged in to access this resource"
    end
  end

  describe "forbidden/3" do
    test "creates forbidden error with default policy" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)

      assert error.reason == :forbidden
      assert error.policy == "access_denied"
      assert error.details.message == "You don't have permission to perform this action"
    end

    test "creates forbidden error with custom policy" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount, "admin_only")

      assert error.policy == "admin_only"
    end
  end

  describe "inactive/2" do
    test "creates inactive user error" do
      error = AuthorizationError.inactive(AshUI.Screen, :mount)

      assert error.reason == :inactive
      assert error.policy == "user_active_required"
      assert error.details.message == "Your account must be active to access this resource"
    end
  end

  describe "format_message/1" do
    test "formats unauthenticated error" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      message = AuthorizationError.format_message(error)

      assert message == "You must be logged in to access this resource"
    end

    test "formats forbidden error" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      message = AuthorizationError.format_message(error)

      assert message == "You don't have permission to perform this action"
    end

    test "formats forbidden error with required role" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      error = AuthorizationError.with_details(error, %{required_role: :admin})
      message = AuthorizationError.format_message(error)

      assert String.contains?(message, "Required role: admin")
    end

    test "formats inactive error" do
      error = AuthorizationError.inactive(AshUI.Screen, :mount)
      message = AuthorizationError.format_message(error)

      assert message == "Your account must be active to access this resource"
    end

    test "formats string reason" do
      error = AuthorizationError.new(reason: "Custom error message")
      message = AuthorizationError.format_message(error)

      assert message == "Custom error message"
    end

    test "formats unknown reason" do
      error = AuthorizationError.new(reason: :unknown_reason)
      message = AuthorizationError.format_message(error)

      assert String.contains?(message, "Authorization failed")
    end
  end

  describe "format_debug/1" do
    test "formats error for debugging" do
      error = AuthorizationError.new(
        resource: AshUI.Screen,
        action: :mount,
        reason: :forbidden,
        policy: "admin_only"
      )

      debug = AuthorizationError.format_debug(error)

      assert String.contains?(debug, "AuthorizationError:")
      assert String.contains?(debug, "Resource: AshUI.Screen")
      assert String.contains?(debug, "Action: :mount")
      assert String.contains?(debug, "Policy: \"admin_only\"")
      assert String.contains?(debug, "Reason: :forbidden")
    end
  end

  describe "status_code/1" do
    test "returns 401 for unauthenticated" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      assert AuthorizationError.status_code(error) == 401
    end

    test "returns 403 for forbidden" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      assert AuthorizationError.status_code(error) == 403
    end

    test "returns 403 for inactive" do
      error = AuthorizationError.inactive(AshUI.Screen, :mount)
      assert AuthorizationError.status_code(error) == 403
    end
  end

  describe "translate/2" do
    test "translates to Spanish" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      spanish = AuthorizationError.translate(error, "es")

      assert spanish == "Debe iniciar sesión para acceder a este recurso"
    end

    test "translates forbidden to Spanish" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      spanish = AuthorizationError.translate(error, "es")

      assert spanish == "No tiene permiso para realizar esta acción"
    end

    test "translates to French" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      french = AuthorizationError.translate(error, "fr")

      assert french == "Vous devez être connecté pour accéder à cette ressource"
    end

    test "translates to German" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      german = AuthorizationError.translate(error, "de")

      assert german == "Sie müssen angemeldet sein, um auf diese Ressource zuzugreifen"
    end

    test "returns English for unknown locale" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      english = AuthorizationError.translate(error, "unknown")

      assert english == "You must be logged in to access this resource"
    end
  end

  describe "custom_error_page/2" do
    test "creates custom error page map" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      page = AuthorizationError.custom_error_page(error, AshUI.Screen)

      assert page.title == "Authentication Required"
      assert page.status_code == 401
      assert page.resource == AshUI.Screen
      assert page.suggested_action.label == "Log In"
      assert page.suggested_action.action == :redirect_login
    end

    test "includes help URL" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      page = AuthorizationError.custom_error_page(error, AshUI.Screen)

      assert page.help_url == "/help/access/AshUI.Screen"
    end
  end

  describe "requires_login?/1" do
    test "returns true for unauthenticated error" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      assert AuthorizationError.requires_login?(error) == true
    end

    test "returns false for other errors" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      assert AuthorizationError.requires_login?(error) == false
    end

    test "returns false for inactive error" do
      error = AuthorizationError.inactive(AshUI.Screen, :mount)
      assert AuthorizationError.requires_login?(error) == false
    end
  end

  describe "recoverable?/1" do
    test "returns false for forbidden error" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      assert AuthorizationError.recoverable?(error) == false
    end

    test "returns false for inactive error" do
      error = AuthorizationError.inactive(AshUI.Screen, :mount)
      assert AuthorizationError.recoverable?(error) == false
    end

    test "returns true for unauthenticated error" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      assert AuthorizationError.recoverable?(error) == true
    end
  end

  describe "with_details/2" do
    test "merges additional details into error" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      error = AuthorizationError.with_details(error, %{required_role: :admin})

      assert error.details.required_role == :admin
      assert error.details.message == "You don't have permission to perform this action"
    end

    test "overwrites existing detail keys" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      error = AuthorizationError.with_details(error, %{message: "Custom message"})

      assert error.details.message == "Custom message"
    end
  end

  describe "exception/1" do
    test "can be raised and rescued" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)

      assert_raise AuthorizationError, fn ->
        raise error
      end
    end

    test "message returns formatted message" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)

      assert Exception.message(error) == "You must be logged in to access this resource"
    end
  end
end
