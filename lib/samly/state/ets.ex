defmodule Samly.State.Ets do
  @moduledoc false

  def init() do
    if :ets.info(:esaml_nameids) == :undefined do
      :ets.new(:esaml_nameids, [:set, :public, :named_table])
    end
  end

  def get_by_nameid(_, nameid) do
    case :ets.lookup(:esaml_nameids, nameid) do
      [{_nameid, _saml_assertion} = rec] -> rec
      _ -> nil
    end
  end

  def put(_, nameid, saml_assertion) do
    :ets.insert(:esaml_nameids, {nameid, saml_assertion})
  end

  def delete(_, nameid) do
    :ets.delete(:esaml_nameids, nameid)
  end
end
