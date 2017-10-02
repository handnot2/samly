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

  config :samly, Samly.Provider,
    base_url: "http://samly.howto:4003/sso",
    #entity_id: "urn:myapp-host:my-id",
    #pre_session_create_pipeline: MySamlyPipeline,
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
  alias Samly.{Esaml, Helper, State}

  @certfile_opt :certfile
  @keyfile_opt :keyfile
  @idp_metadata_file_opt :idp_metadata_file
  @entity_id_opt :entity_id
  @base_url_opt :base_url
  @pre_session_create_pipeline_opt :pre_session_create_pipeline
  @sign_requests_opt :sign_requests
  @sign_metadata_opt :sign_metadata
  @signed_envelopes_in_idp_resp_opt :signed_envelopes_in_idp_resp
  @signed_assertion_in_idp_resp_opt :signed_assertion_in_idp_resp

  @opt_keys [
    @certfile_opt, @keyfile_opt, @idp_metadata_file_opt, @base_url_opt,
    @sign_requests_opt, @sign_metadata_opt,
    @signed_envelopes_in_idp_resp_opt, @signed_assertion_in_idp_resp_opt,
    @entity_id_opt, @pre_session_create_pipeline_opt
  ]

  @doc false
  def start_link(gs_opts \\ []) do
    GenServer.start_link(__MODULE__, [], gs_opts)
  end

  @doc false
  def init([]) do
    State.init()
    opts = Application.get_env(:samly, Samly.Provider, [])
    case load_sp_idp_rec(opts) do
      {:ok, sp_rec, idp_rec} ->
        Application.put_env(:samly, :sp, sp_rec)
        Application.put_env(:samly, :idp_metadata, idp_rec)
        if opts[@pre_session_create_pipeline_opt] do
          Application.put_env(:samly,
            :pre_session_create_pipeline,
            opts[@pre_session_create_pipeline_opt])
        end
      error -> error
    end
    {:ok, %{}}
  end

  @doc false
  def load_sp_idp_rec(opts) do
    opts = opts |> handle_defaults()
    with  {:ok, idp_metadata} <- init_idp_rec(opts),
          trusted_fingerprints = idp_cert_fingerprints(idp_metadata),
          {:ok, sp_rec} <- init_sp_rec(opts, trusted_fingerprints)
    do
      {:ok, sp_rec, idp_metadata}
    else
      error -> error
    end
  end

  defp handle_defaults(opts) do
    get_opt_value = fn k ->
      case opts[k] do
        nil ->
          v = use_env(k) # value can be false, use explicity nil check
          v = if v != nil, do: v, else: use_default(k)
          {k, v}
        v   -> {k, v}
      end
    end

    Enum.map(@opt_keys, get_opt_value)
  end

  defp use_env(@pre_session_create_pipeline_opt), do: nil
  defp use_env(@entity_id_opt), do: nil
  defp use_env(@certfile_opt), do: System.get_env("SAMLY_CERTFILE")
  defp use_env(@keyfile_opt), do: System.get_env("SAMLY_KEYFILE")
  defp use_env(@idp_metadata_file_opt), do: System.get_env("SAMLY_IDP_METADATA_FILE")
  defp use_env(@base_url_opt), do: System.get_env("SAMLY_BASE_URL")
  defp use_env(@sign_requests_opt), do: truthy_env("SAMLY_SIGN_REQUESTS")
  defp use_env(@sign_metadata_opt), do: truthy_env("SAMLY_SIGN_METADATA")
  defp use_env(@signed_envelopes_in_idp_resp_opt), do: truthy_env("SAMLY_SIGNED_ENVELOPES_IN_IDP_RESP")
  defp use_env(@signed_assertion_in_idp_resp_opt), do: truthy_env("SAMLY_SIGNED_ASSERTION_IN_IDP_RESP")

  defp truthy_env(name) do
    value = System.get_env(name)
    value = value && String.downcase(value)
    case value do
      nil -> nil
      "true" -> true
      "false" -> false
      _ ->
        Logger.warn("Samly.Provider: Ignoring #{name}=#{value}")
        nil
    end
  end

  defp use_default(@pre_session_create_pipeline_opt), do: nil
  defp use_default(@entity_id_opt), do: :undefined
  defp use_default(k) when k in [
      @sign_requests_opt, @sign_metadata_opt,
      @signed_envelopes_in_idp_resp_opt, @signed_assertion_in_idp_resp_opt] do
    true
  end
  defp use_default(opt) do
    Logger.warn("Samly.Provider: option :#{opt} not set")

    case opt do
      @certfile_opt -> "samly.crt"
      @keyfile_opt -> "samly.pem"
      @idp_metadata_file_opt -> "idp_metadata.xml"
      @base_url_opt -> ""
    end
  end

  defp init_idp_rec(opts) do
    mdtfile = opts[@idp_metadata_file_opt]
    with  {:reading, {:ok, xml}} <- {:reading, File.read(mdtfile)},
          {:parsing, {:ok, mdt}} <- {:parsing, idp_metadata_from_xml(xml)}
    do
      {:ok, mdt}
    else
      {:reading, {:error, reason}} ->
        Logger.error("[Samly] Failed to read: #{mdtfile}")
        Logger.error("[Samly] Error: #{inspect reason}")
        :error
      {:parsing, {:error, reason}} ->
        Logger.error("[Samly] Invalid content: #{mdtfile}")
        Logger.error("[Samly] Error: #{inspect reason}")
        :error
    end
  end

  defp idp_metadata_from_xml(metadata_xml) when is_binary(metadata_xml) do
    try do
      {xml, _} = metadata_xml
      |>  String.to_charlist()
      |>  :xmerl_scan.string(namespace_conformant: true)
      :esaml.decode_idp_metadata(xml)
    rescue
      _ -> {:error, :invalid_metadata_xml}
    end
  end

  defp idp_cert_fingerprints(idp_metadata) do
    fingerprint = idp_metadata
    |>  Esaml.esaml_idp_metadata(:certificate)
    |>  cert_fingerprint()
    |>  String.to_charlist()

    [fingerprint] |> :esaml_util.convert_fingerprints()
  end

  defp cert_fingerprint(dercert) do
    "sha256:" <> (:sha256 |> :crypto.hash(dercert) |> Base.encode64())
  end

  defp init_sp_rec(opts, trusted_fingerprints) do
    base_url = opts[@base_url_opt] |> String.to_charlist()
    keyfile  = opts[@keyfile_opt] |> String.to_charlist()
    crtfile  = opts[@certfile_opt] |> String.to_charlist()
    entity_id = case opts[@entity_id_opt] do
      :undefined -> :undefined
      id -> String.to_charlist(id)
    end

    try do
      cert = load_sp_cert(crtfile)
      key  = load_sp_priv_key(keyfile)

      sp_rec = Esaml.esaml_sp(
        key: key,
        certificate: cert,
        sp_sign_requests: opts[@sign_requests_opt],
        sp_sign_metadata: opts[@sign_metadata_opt],
        idp_signs_envelopes: opts[@signed_envelopes_in_idp_resp_opt],
        idp_signs_assertions: opts[@signed_assertion_in_idp_resp_opt],
        trusted_fingerprints: trusted_fingerprints,
        metadata_uri: Helper.get_metadata_uri(base_url),
        consume_uri: Helper.get_consume_uri(base_url),
        logout_uri: Helper.get_logout_uri(base_url),
        entity_id: entity_id,
        # TODO: get this from config
        org: Esaml.esaml_org(
          name: 'Samly SP',
          displayname: 'Samly SP',
          url: base_url
        ),
        tech: Esaml.esaml_contact(
          name: 'Samly SP Admin',
          email: 'admin@samly'
        )
      )

      {:ok, sp_rec}
    rescue
      error ->
        Logger.error("[Samly] Failed to initialize SP")
        Logger.error("[Samly] Error: #{inspect error}")
        :error
    end
  end

  defp load_sp_priv_key(file) do
    file |> :esaml_util.load_private_key()
  end

  defp load_sp_cert(file) do
    file |> :esaml_util.load_certificate()
  end
end
