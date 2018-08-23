defmodule Samly.State do
  @moduledoc false

  @adapter Application.get_env(:samly, Samly.Provider)[:state_adapter] || Samly.State.Ets

  def gen_id() do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
  end

  def init(), do: @adapter.init()

  def get_by_nameid(idp_id, nameid), do: @adapter.get_by_nameid(idp_id, nameid)

  def put(idp_id, nameid, saml_assertion), do: @adapter.put(idp_id, nameid, saml_assertion)

  def delete(idp_id, nameid), do: @adapter.delete(idp_id, nameid)
end
