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
    #pre_session_create_pipeline: MySamlyPipeline,
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

  """

  use GenServer
  require Logger

  require Samly.Esaml
  alias Samly.{Esaml, Helper, State}

  @crt_opt :certfile
  @key_opt :keyfile
  @mtd_opt :idp_metadata_file
  @url_opt :base_url
  @pipeline_opt :pre_session_create_pipeline

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
        if opts[@pipeline_opt] do
          Application.put_env(:samly, :pre_session_create_pipeline, opts[@pipeline_opt])
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

  @opt_keys [:pre_session_create_pipeline, :certfile, :keyfile, :idp_metadata_file, :base_url]
  defp handle_defaults(opts) do
    get_opt_value = fn k ->
      case opts[k] do
        nil -> {k, use_env(k) || use_default(k)}
        v   -> {k, v}
      end
    end

    Enum.map(@opt_keys, get_opt_value)
  end

  defp use_env(@pipeline_opt), do: nil
  defp use_env(@crt_opt), do: System.get_env("SAMLY_CERTFILE")
  defp use_env(@key_opt), do: System.get_env("SAMLY_KEYFILE")
  defp use_env(@mtd_opt), do: System.get_env("SAMLY_IDP_METADATA_FILE")
  defp use_env(@url_opt), do: System.get_env("SAMLY_BASE_URL")

  defp use_default(@pipeline_opt), do: nil
  defp use_default(opt) do
    Logger.warn("Samly.Provider: option :#{opt} not set")

    case opt do
      @pipeline_opt -> nil
      @crt_opt -> "samly.crt"
      @key_opt -> "samly.pem"
      @mtd_opt -> "idp_metadata.xml"
      @url_opt -> ""
    end
  end

  defp init_idp_rec(opts) do
    mdtfile = opts[@mtd_opt]
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
    base_url = opts[@url_opt] |> String.to_charlist()
    keyfile  = opts[@key_opt] |> String.to_charlist()
    crtfile  = opts[@crt_opt] |> String.to_charlist()
    try do
      cert = load_sp_cert(crtfile)
      key  = load_sp_priv_key(keyfile)

      sp_rec = Esaml.esaml_sp(
        key: key,
        certificate: cert,
        sp_sign_requests: true,
        sp_sign_metadata: true,
        trusted_fingerprints: trusted_fingerprints,
        metadata_uri: Helper.get_metadata_uri(base_url),
        consume_uri: Helper.get_consume_uri(base_url),
        logout_uri: Helper.get_logout_uri(base_url),
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
