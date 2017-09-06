defmodule Samly.State do
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
      [{nameid, assertions}] -> {nameid, assertions}
      _ -> nil
    end
  end

  def put(nameid, assertions) do
    :ets.insert(:esaml_nameids, {nameid, assertions})
  end

  def delete(nameid) do
    :ets.delete(:esaml_nameids, nameid)
  end
end
