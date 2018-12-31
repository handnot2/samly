defmodule Samly.State.Session do
  @moduledoc """
  Stores SAML assertion in Plug session.

  This provider uses Plug session to save the authenticated SAML
  assertions from IdP. The session key name in the configuration is optional.

  ## Options

  +   `:key` - Session key name used when saving the assertion (optional)
               Value is either a binary or an atom

  ## Configuration Example

      config :samly, Samly.State,
        store: Samly.State.Session,
        opts: [key: :my_assertion]
  """

  alias Plug.Conn
  alias Samly.Assertion

  @behaviour Samly.State.Store

  @session_key "samly_assertion"

  @impl Samly.State.Store
  def init(opts) do
    opts |> Map.new() |> Map.put_new(:key, @session_key)
  end

  @impl Samly.State.Store
  def get_assertion(conn, assertion_key, opts) do
    %{key: key} = opts

    case Conn.get_session(conn, key) do
      {^assertion_key, %Assertion{} = assertion} -> assertion
      _ -> nil
    end
  end

  @impl Samly.State.Store
  def put_assertion(conn, assertion_key, assertion, opts) do
    %{key: key} = opts
    Conn.put_session(conn, key, {assertion_key, assertion})
  end

  @impl Samly.State.Store
  def delete_assertion(conn, _assertion_key, opts) do
    %{key: key} = opts
    Conn.delete_session(conn, key)
  end
end
