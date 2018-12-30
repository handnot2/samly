defmodule Samly do
  @moduledoc """
  Elixir library used to enable SAML SP SSO to a Phoenix/Plug based application.
  """

  alias Plug.Conn
  alias Samly.{Assertion, State}

  @doc """
  Returns authenticated user SAML Assertion.

  The struct includes the attributes sent from IdP as well as any corresponding locally
  computed/derived attributes. Returns `nil` if the current Plug session
  is not authenticated.

  ## Parameters

  +   `conn` - Plug connection

  ## Examples

      # When there is an authenticated SAML assertion
      %Assertion{} = Samly.get_active_assertion()
  """
  @spec get_active_assertion(Conn.t()) :: Assertion.t() | nil
  def get_active_assertion(conn) do
    case Conn.get_session(conn, "samly_assertion_key") do
      {_idp_id, _nameid} = assertion_key ->
        State.get_assertion(conn, assertion_key)
      _ -> nil
    end
  end

  @doc """
  Returns value of the specified attribute name in the given SAML Assertion.

  Checks for the attribute in `computed` map first and `attributes` map next.
  Returns `nil` if attribute is not present.

  ## Parameters

  +   `assertion` - SAML assertion obtained by calling `get_active_assertion/1`
  +   `name`: Attribute name

  ## Examples

      assertion = Samly.get_active_assertion()
      computed_fullname = Samly.get_attribute(assertion, "fullname")
  """
  @spec get_attribute(nil | Assertion.t(), String.t()) :: nil | String.t()
  def get_attribute(nil, _name), do: nil

  def get_attribute(%Assertion{} = assertion, name) do
    computed = assertion.computed
    attributes = assertion.attributes
    Map.get(computed, name) || Map.get(attributes, name)
  end
end
