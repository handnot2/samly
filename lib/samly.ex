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
  @spec get_active_assertion(Conn.t()) :: nil | Assertion.t()
  def get_active_assertion(conn) do
    case Conn.get_session(conn, "samly_assertion_key") do
      {_idp_id, _nameid} = assertion_key ->
        State.get_assertion(conn, assertion_key)

      _ ->
        nil
    end
  end

  @doc """
  Returns value of the specified attribute name in the given SAML Assertion.

  Checks for the attribute in `computed` map first and `attributes` map next.
  Returns a UTF-8 binary or a list of UTF-8 binaries (in case of multi-valued)
  if the given attribute is present. Returns `nil` if attribute is not present.

  ## Parameters

  +   `assertion` - SAML assertion obtained by calling `get_active_assertion/1`
  +   `name`: Attribute name

  ## Examples

      assertion = Samly.get_active_assertion()
      # returns a list if the attribute is multi-valued
      roles = Samly.get_attribute(assertion, "roles")
      computed_fullname = Samly.get_attribute(assertion, "fullname")
  """
  @spec get_attribute(nil | Assertion.t(), Assertion.attr_name_t()) ::
          nil | Assertion.attr_value_t()
  def get_attribute(nil, _name), do: nil

  def get_attribute(%Assertion{} = assertion, name) do
    Map.get(assertion.computed, name) || Map.get(assertion.attributes, name)
  end

  def logout(conn) do
    conn
    |> Conn.delete_session("samly_assertion_key")
  end
end
