defmodule Samly.State.Ets do
  @moduledoc false

  def init() do
    if :ets.info(:esaml_nameids) == :undefined do
      :ets.new(:esaml_nameids, [:set, :public, :named_table])
    end
  end

  def gen_id() do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
  end

  def get_by_nameid(nameid) do
    case :ets.lookup(:esaml_nameids, nameid) do
      [{_nameid, _saml_assertion} = rec] -> rec
      _ -> nil
    end
  end

  def put(nameid, saml_assertion) do
    :ets.insert(:esaml_nameids, {nameid, saml_assertion})
  end

  def delete(nameid) do
    :ets.delete(:esaml_nameids, nameid)
  end
end
