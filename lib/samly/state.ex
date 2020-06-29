defmodule Samly.State do
  @moduledoc false

  def init(otp_app, store_provider), do: init(otp_app, store_provider, [])

  def init(otp_app, store_provider, opts) do
    opts = store_provider.init(opts)
    set_state_store(otp_app, %{provider: store_provider, opts: opts})
  end

  def get_assertion(conn, assertion_key) do
    %{provider: store_provider, opts: opts} = state_store_from(conn)
    store_provider.get_assertion(conn, assertion_key, opts)
  end

  def put_assertion(conn, assertion_key, assertion) do
    %{provider: store_provider, opts: opts} = state_store_from(conn)
    store_provider.put_assertion(conn, assertion_key, assertion, opts)
  end

  def delete_assertion(conn, assertion_key) do
    %{provider: store_provider, opts: opts} = state_store_from(conn)
    store_provider.delete_assertion(conn, assertion_key, opts)
  end

  def gen_id() do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
  end

  defp state_store_from(conn) do
    otp_app = conn.private[:samly_config][:otp_app]
    Application.get_env(otp_app, Samly.Config).state_store
  end

  def set_state_store(otp_app, value) do
    new_config =
      Application.get_env(otp_app, Samly.Config, %{})
      |> Map.put(:state_store, value)

    Application.put_env(otp_app, Samly.Config, new_config)
  end
end
