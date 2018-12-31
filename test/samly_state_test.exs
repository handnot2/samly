defmodule Samly.StateTest do
  use ExUnit.Case, async: true
  use Plug.Test

  setup do
    opts =
      Plug.Session.init(
        store: :cookie,
        key: "_samly_state_test_session",
        encryption_salt: "salty enc",
        signing_salt: "salty signing",
        key_length: 64
      )

    Samly.State.init(Samly.State.Session)

    conn =
      conn(:get, "/")
      |> Plug.Session.call(opts)
      |> fetch_session()

    [conn: conn]
  end

  test "put/get assertion", %{conn: conn} do
    assertion = %Samly.Assertion{}
    assertion_key = {"idp1", "name1"}
    conn = Samly.State.put_assertion(conn, assertion_key, assertion)
    assert assertion == Samly.State.get_assertion(conn, assertion_key)
  end

  test "get failure for unknown assertion key", %{conn: conn} do
    assertion = %Samly.Assertion{}
    assertion_key = {"idp1", "name1"}
    conn = Samly.State.put_assertion(conn, assertion_key, assertion)
    assert nil == Samly.State.get_assertion(conn, {"idp1", "name2"})
  end

  test "delete assertion", %{conn: conn} do
    assertion = %Samly.Assertion{}
    assertion_key = {"idp1", "name1"}
    conn = Samly.State.put_assertion(conn, assertion_key, assertion)
    assert assertion == Samly.State.get_assertion(conn, assertion_key)
    conn = Samly.State.delete_assertion(conn, assertion_key)
    assert nil == Samly.State.get_assertion(conn, assertion_key)
  end
end
