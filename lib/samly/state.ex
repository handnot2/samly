defmodule Samly.State do
  @moduledoc false

  @adapter Application.get_env(:samly, Samly.Provider)[:state_adapter] || Samly.State.Ets

  def gen_id() do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
  end

  def init(), do: @adapter.init()

  def get_by_nameid(nameid), do: @adapter.get_by_nameid(nameid)

  def put(nameid, saml_assertion), do: @adapter.put(nameid, saml_assertion)

  def delete(nameid), do: @adapter.delete(nameid)
end
