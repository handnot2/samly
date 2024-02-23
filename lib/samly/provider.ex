defmodule Samly.Provider do
  @moduledoc """
  SAML 2.0 Service Provider

  This should be added to the hosting Phoenix/Plug application's supervision tree.
  This GenServer initializes the SP configuration and loads the IDP medata XML
  containing information on how to communicate with the IDP.

  ```elixir
  # application.ex

    children = [
      # ...
      worker(Samly.Provider, []),
    ]
  ```

  Check README.md `Configuration` section.
  """

  use GenServer
  require Logger

  require Samly.Esaml
  alias Samly.{State}

  @doc false
  def start_link(gs_opts \\ []) do
    GenServer.start_link(__MODULE__, [], gs_opts)
  end

  @doc false
  def init([]) do
    store_env = Application.get_env(:samly, Samly.State, [])
    store_provider = store_env[:store] || Samly.State.ETS
    store_opts = store_env[:opts] || []
    State.init(store_provider, store_opts)

    opts = Application.get_env(:samly, Samly.Provider, [])

    # must be done prior to loading the providers
    idp_id_from =
      case opts[:idp_id_from] do
        nil ->
          :path_segment

        value when value in [:subdomain, :path_segment] ->
          value

        unknown ->
          Logger.warning(
            "[Samly] invalid_data idp_id_from: #{inspect(unknown)}. Using :path_segment"
          )

          :path_segment
      end

    Application.put_env(:samly, :idp_id_from, idp_id_from)

    service_providers = Samly.SpData.load_providers(opts[:service_providers] || [])

    identity_providers =
      Samly.IdpData.load_providers(opts[:identity_providers] || [], service_providers)

    Application.put_env(:samly, :service_providers, service_providers)
    Application.put_env(:samly, :identity_providers, identity_providers)

    {:ok, %{}}
  end
end
