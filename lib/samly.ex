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
  """
  def get_active_assertion(conn) do
    nameid = conn |> Conn.get_session("samly_nameid")
    case State.get_by_nameid(nameid) do
      {^nameid, saml_assertion} -> saml_assertion
      _ -> nil
    end
  end

  @doc """
  Returns value of the specified attribute name in the given SAML Assertion.

  Checks for the attribute in `computed` map first and `attributes` map next.
  Returns `nil` if not present in either.
  """
  def get_attribute(nil, _name), do: nil
  def get_attribute(%Assertion{} = assertion, name) do
    computed = assertion.computed
    attributes = assertion.attributes
    Map.get(computed, name) || Map.get(attributes, name)
  end
end
