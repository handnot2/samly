defmodule Samly.IdpDataStore.Config do
  @moduledoc """
  Reads identity providers data from Application environment (config files).

  This is the default behaviour. To change it, set the following config:

    config :samly, Samly.Provider,
      idp_data_store: MyApp.IdpStore

  This implementation only provides `init/2` and `get/1`.any()
  `delete/1` and `put/2` will return `:unsupported`.
  """

  @behaviour Samly.IdpDataStore.Store

  @impl true
  def init(opts, service_providers) do
    identity_providers =
      Samly.IdpData.load_providers(opts || [], service_providers)

    Application.put_env(:samly, :identity_providers, identity_providers)
  end

  @impl true
  def get(idp_id) do
    idps = Application.get_env(:samly, :identity_providers, %{})
    Map.get(idps, idp_id)
  end

  @impl true
  def put(_idp_id, _idp_data), do: :unsupported

  @impl true
  def delete(_idp_id), do: :unsupported
end
