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

  The configuration parameters are honored in the following order: `Application.get_env`,
  environment variables and finally hard defaultds.

  The configuration information needed for `Samly` can be specified as shown here:

  ```elixir
  # config/dev.exs
  # TODO: Update this

  config :samly, Samly.Provider,
    base_url: "http://samly.howto:4003/sso",
    #entity_id: "urn:myapp-host:my-id",
    #pre_session_create_pipeline: MySamlyPipeline,
    #use_redirect_for_idp_req: false,
    #sign_requests: true,
    #sign_metadata: true,
    #signed_envelopes_in_idp_resp: true,
    #signed_assertion_in_idp_resp: true,
    certfile: "path/to/service/provider/certificate/file",
    keyfile: "path/to/corresponding/private/key/file",
    idp_metadata_file: "path/to/idp/metadata/xml/file"
  ```

  `Samly` relies on environment variables for parameters missing from configuration.

  | Variable | Description  |
  |:-------------------- |:-------------------- |
  | SAMLY_CERTFILE | Path to the X509 certificate file. Defaults to `samly.crt` |
  | SAMLY_KEYFILE  | Path to the private key for the certificate. Defaults to `samly.pem` |
  | SAMLY_IDP_METADATA_FILE | Path to the SAML IDP metadata XML file. Defaults to `idp_metadata.xml` |
  | SAMLY_BASE_URL | Set this to the base URL for your application (include `/sso`) |
  | SAMLY_SIGN_REQUESTS | Set this to `false` if IdP is setup to receive unsigned requests |
  | SAMLY_SIGN_METADATA | Set this to `false` if the metadata response should be unsigned |
  | SAMLY_SIGNED_ENVELOPES_IN_IDP_RESP | Set this to `false` if IdP is sending unsigned response |
  | SAMLY_SIGNED_ASSERTION_IN_IDP_RESP | Set this to `false` if IdP is sending unsigned response |

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
    State.init()
    opts = Application.get_env(:samly, Samly.Provider, [])
    service_providers = Samly.SpData.load_service_providers(
      opts[:service_providers] || []
    )
    identity_providers = Samly.IdpData.load_identity_providers(
      opts[:identity_providers] || [],
      service_providers,
      opts[:base_url]
    )

    Application.put_env(:samly, :service_providers, service_providers)
    Application.put_env(:samly, :identity_providers, identity_providers)

    {:ok, %{}}
  end
end
