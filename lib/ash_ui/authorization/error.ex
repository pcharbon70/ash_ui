defmodule AshUI.AuthorizationError do
  @moduledoc """
  Authorization error exception for Ash UI.

  Provides structured error types for authorization failures
  with user-friendly messaging and translation support.
  """

  defexception [:resource, :action, :policy, :reason, :details]

  @type t :: %__MODULE__{
          resource: module() | nil,
          action: atom() | nil,
          policy: String.t() | nil,
          reason: term(),
          details: map()
        }

  @impl true
  @doc """
  Builds an `AshUI.AuthorizationError` exception from keyword options.
  """
  def exception(opts) do
    struct(__MODULE__, opts)
  end

  @impl true
  @doc """
  Returns the human-readable message for the authorization error.
  """
  def message(%__MODULE__{reason: reason} = error) do
    format_message(error)
  end

  @doc """
  Creates a new authorization error.

  ## Examples

      AuthorizationError.new(
        resource: AshUI.Screen,
        action: :mount,
        reason: :unauthenticated
      )
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    exception(opts)
  end

  @doc """
  Creates an unauthenticated error.

  ## Examples

      AuthorizationError.unauthenticated(AshUI.Screen, :mount)
  """
  @spec unauthenticated(module(), atom()) :: t()
  def unauthenticated(resource, action) do
    new(
      resource: resource,
      action: action,
      reason: :unauthenticated,
      policy: "authentication_required",
      details: %{
        message: "You must be logged in to access this resource"
      }
    )
  end

  @doc """
  Creates a forbidden error.

  ## Examples

      AuthorizationError.forbidden(AshUI.Screen, :mount, "screen_not_accessible")
  """
  @spec forbidden(module(), atom(), String.t()) :: t()
  def forbidden(resource, action, policy \\ "access_denied") do
    new(
      resource: resource,
      action: action,
      reason: :forbidden,
      policy: policy,
      details: %{
        message: "You don't have permission to perform this action"
      }
    )
  end

  @doc """
  Creates an inactive user error.

  ## Examples

      AuthorizationError.inactive(AshUI.Screen, :mount)
  """
  @spec inactive(module(), atom()) :: t()
  def inactive(resource, action) do
    new(
      resource: resource,
      action: action,
      reason: :inactive,
      policy: "user_active_required",
      details: %{
        message: "Your account must be active to access this resource"
      }
    )
  end

  @doc """
  Formats the error for display to users.

  ## Examples

      AuthorizationError.format_message(error)
  """
  @spec format_message(t()) :: String.t()
  def format_message(%__MODULE__{reason: :unauthenticated} = error) do
    "You must be logged in to access this resource"
  end

  def format_message(%__MODULE__{reason: :forbidden} = error) do
    base = "You don't have permission to perform this action"

    case error.details do
      %{required_role: role} -> "#{base}. Required role: #{role}"
      %{required_permissions: perms} -> "#{base}. Required permissions: #{inspect(perms)}"
      _ -> base
    end
  end

  def format_message(%__MODULE__{reason: :inactive}) do
    "Your account must be active to access this resource"
  end

  def format_message(%__MODULE__{reason: reason}) when is_binary(reason) do
    reason
  end

  def format_message(%__MODULE__{reason: reason}) do
    "Authorization failed: #{inspect(reason)}"
  end

  @doc """
  Formats the error for logging/debugging.

  ## Examples

      AuthorizationError.format_debug(error)
  """
  @spec format_debug(t()) :: String.t()
  def format_debug(%__MODULE__{} = error) do
    """
    AuthorizationError:
      Resource: #{inspect(error.resource)}
      Action: #{inspect(error.action)}
      Policy: #{inspect(error.policy)}
      Reason: #{inspect(error.reason)}
      Details: #{inspect(error.details)}
    """
    |> String.trim()
  end

  @doc """
  Gets the HTTP status code for the error.

  ## Examples

      AuthorizationError.status_code(error)
  """
  @spec status_code(t()) :: integer()
  def status_code(%__MODULE__{reason: :unauthenticated}), do: 401
  def status_code(%__MODULE__{reason: :forbidden}), do: 403
  def status_code(%__MODULE__{reason: :inactive}), do: 403
  def status_code(%__MODULE__{}), do: 403

  @doc """
  Translates the error message for internationalization.

  ## Examples

      AuthorizationError.translate(error, "fr")
  """
  @spec translate(t(), String.t()) :: String.t()
  def translate(%__MODULE__{} = error, locale) when is_binary(locale) do
    # In production, would use Gettext or similar
    case locale do
      "es" -> translate_spanish(error)
      "fr" -> translate_french(error)
      "de" -> translate_german(error)
      _ -> format_message(error)
    end
  end

  # Private translations

  defp translate_spanish(%__MODULE__{reason: :unauthenticated}) do
    "Debe iniciar sesión para acceder a este recurso"
  end

  defp translate_spanish(%__MODULE__{reason: :forbidden}) do
    "No tiene permiso para realizar esta acción"
  end

  defp translate_spanish(%__MODULE__{reason: :inactive}) do
    "Su cuenta debe estar activa para acceder a este recurso"
  end

  defp translate_spanish(_), do: "Error de autorización"

  defp translate_french(%__MODULE__{reason: :unauthenticated}) do
    "Vous devez être connecté pour accéder à cette ressource"
  end

  defp translate_french(%__MODULE__{reason: :forbidden}) do
    "Vous n'avez pas la permission d'effectuer cette action"
  end

  defp translate_french(%__MODULE__{reason: :inactive}) do
    "Votre compte doit être actif pour accéder à cette ressource"
  end

  defp translate_french(_), do: "Erreur d'autorisation"

  defp translate_german(%__MODULE__{reason: :unauthenticated}) do
    "Sie müssen angemeldet sein, um auf diese Ressource zuzugreifen"
  end

  defp translate_german(%__MODULE__{reason: :forbidden}) do
    "Sie haben keine Berechtigung, diese Aktion auszuführen"
  end

  defp translate_german(%__MODULE__{reason: :inactive}) do
    "Ihr Konto muss aktiv sein, um auf diese Ressource zuzugreifen"
  end

  defp translate_german(_), do: "Autorisierungsfehler"

  @doc """
  Creates a custom error page per resource.

  ## Examples

      AuthorizationError.custom_error_page(error, AshUI.Screen)
  """
  @spec custom_error_page(t(), module()) :: map()
  def custom_error_page(%__MODULE__{} = error, resource_module) do
    %{
      title: error_title(error),
      message: format_message(error),
      status_code: status_code(error),
      resource: resource_module,
      suggested_action: suggested_action(error),
      help_url: help_url(error, resource_module)
    }
  end

  defp error_title(%__MODULE__{reason: :unauthenticated}), do: "Authentication Required"
  defp error_title(%__MODULE__{reason: :forbidden}), do: "Access Denied"
  defp error_title(%__MODULE__{reason: :inactive}), do: "Account Inactive"
  defp error_title(%__MODULE__{}), do: "Authorization Error"

  defp suggested_action(%__MODULE__{reason: :unauthenticated}) do
    %{label: "Log In", action: :redirect_login}
  end

  defp suggested_action(%__MODULE__{reason: :inactive}) do
    %{label: "Contact Support", action: :contact_support}
  end

  defp suggested_action(%__MODULE__{}) do
    %{label: "Go Back", action: :go_back}
  end

  defp help_url(%__MODULE__{}, resource_module) do
    # In production, would return actual help URL
    "/help/access/#{inspect(resource_module)}"
  end

  @doc """
  Checks if error suggests a login redirect.

  ## Examples

      if AuthorizationError.requires_login?(error) do
        redirect_to_login(socket)
      end
  """
  @spec requires_login?(t()) :: boolean()
  def requires_login?(%__MODULE__{reason: :unauthenticated}), do: true
  def requires_login?(%__MODULE__{}), do: false

  @doc """
  Checks if error is recoverable.

  ## Examples

      if AuthorizationError.recoverable?(error) do
        # show retry option
      end
  """
  @spec recoverable?(t()) :: boolean()
  def recoverable?(%__MODULE__{reason: reason}) when reason in [:inactive, :forbidden], do: false
  def recoverable?(%__MODULE__{}), do: true

  @doc """
  Adds additional details to an error.

  ## Examples

      error = AuthorizationError.with_details(error, %{required_role: :admin})
  """
  @spec with_details(t(), map()) :: t()
  def with_details(%__MODULE__{} = error, additional_details) do
    %{error | details: Map.merge(error.details, additional_details)}
  end
end
