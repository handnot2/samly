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

  @genserver_options ~W(name timeout debug spawn_opts hibernate_after)a

  @doc false
  def start_link(opts \\ []) do
    {gs_opts, init_args} = Keyword.split(opts, @genserver_options)
    GenServer.start_link(__MODULE__, init_args, gs_opts)
  end

  @doc false
  def init(opts) do
    otp_app = Keyword.get(opts, :otp_app, :samly)

    store_env = Application.get_env(otp_app, Samly.State, [])
    store_provider = store_env[:store] || Samly.State.ETS
    store_opts = store_env[:opts] || []
    State.init(otp_app, store_provider, store_opts)

    opts = Application.get_env(otp_app, Samly.Provider, [])

    # must be done prior to loading the providers
    idp_id_from =
      case opts[:idp_id_from] do
        nil ->
          :path_segment

        value when value in [:subdomain, :path_segment] ->
          value

        unknown ->
          Logger.warn(
            "[Samly] invalid_data idp_id_from: #{inspect(unknown)}. Using :path_segment"
          )

          :path_segment
      end

    new_config =
      Application.get_env(otp_app, Samly.Config, %{})
      |> Map.put(:idp_id_from, idp_id_from)

    Application.put_env(otp_app, Samly.Config, new_config)

    service_providers = Samly.SpData.load_providers(opts[:service_providers] || [])

    identity_providers =
      Samly.IdpData.load_providers(opts[:identity_providers] || [], service_providers, new_config)

    Application.put_env(otp_app, Samly.ServiceProviders, service_providers)
    Application.put_env(otp_app, Samly.IdentityProviders, identity_providers)

    {:ok, %{}}
  end
end
