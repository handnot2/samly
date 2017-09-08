defmodule Samly.Provider do
  @moduledoc false

  use GenServer
  require Logger

  alias Samly.State
  require Samly.Esaml
  alias Samly.Esaml

  def start_link(gs_opts \\ []) do
    GenServer.start_link(__MODULE__, [], gs_opts)
  end

  def init([]) do
    opts = Application.get_env(:samly, Samly.Provider, [])
    pipeline = opts[:assertion_pipeline]
    sp_certfile = get_opt(opts, :certfile, "SAMLY_CERTFILE", "samly.crt")
    sp_keyfile  = get_opt(opts, :keyfile, "SAMLY_KEYFILE", "samly.pem")
    idp_metadata_file = get_opt(opts, :idp_metadata_file,
      "SAMLY_IDP_METADATA_FILE", "idp_metadata.xml")
    sp_base_url = get_opt(opts, :base_url,
      "SAMLY_BASE_URL", "http://localhost:4000/sso")

    State.init()

    with  {:idp_metadata_file, {:ok, metadata_xml}} <-
            {:idp_metadata_file, File.read(idp_metadata_file)},
          {:idp_metadata_parsing, {:ok, idp_metadata}} <-
            {:idp_metadata_parsing, idp_metadata_from_xml(metadata_xml)},
          trusted_fingerprints = idp_cert_fingerprints(idp_metadata),
          {:ok, sp} <- create_sp(sp_certfile, sp_keyfile, sp_base_url, trusted_fingerprints)
    do
      Application.put_env(:samly, :sp, sp)
      Application.put_env(:samly, :idp_metadata, idp_metadata)
      if pipeline do
        Application.put_env(:samly, :assertion_pipeline, pipeline)
      end
    else
      {:idp_metadata_file, {:error, reason}} ->
        Logger.error("Failed to read IDP metadata XML file: #{reason}")
      {:idp_metadata_parsing, {:error, reason}} ->
        Logger.error("Invalid IDP metadata XML: #{reason}")
      error ->
        Logger.error("Failed in Samly.Provider: #{error}")
    end

    {:ok, %{}}
  end

  defp get_opt(opts, attr, env_var, default) do
    value = Keyword.get(opts, attr) || System.get_env(env_var)
    if value do
      value
    else
      Logger.error("#{env_var} undefined. Using: #{default}")
      default
    end
  end

  defp load_sp_priv_key(file) do
    file |> :esaml_util.load_private_key()
  end

  defp load_sp_cert(file) do
    file |> :esaml_util.load_certificate()
  end

  defp create_sp(certfile, keyfile, sp_base_url, trusted_fingerprints) do
    certfile = String.to_charlist(certfile)
    keyfile  = String.to_charlist(keyfile)
    sp_base_url = String.to_charlist(sp_base_url)

    cert = load_sp_cert(certfile)
    key  = load_sp_priv_key(keyfile)

    sp_rec = Esaml.esaml_sp(
      key: key,
      certificate: cert,
      sp_sign_requests: true,
      sp_sign_metadata: true,
      trusted_fingerprints: trusted_fingerprints,
      consume_uri: sp_base_url ++ '/sp/consume',
      metadata_uri: sp_base_url ++ '/sp/metadata',
      logout_uri: sp_base_url ++ '/sp/logout',
      # TODO: get this from config
      org: Esaml.esaml_org(
        name: 'Samly SP',
        displayname: 'Samly SP',
        url: sp_base_url
      ),
      tech: Esaml.esaml_contact(
        name: 'Samly SP Admin',
        email: 'admin@samly'
      )
    )

    {:ok, sp_rec |> :esaml_sp.setup()}
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
    [fingerprint]
  end

  defp cert_fingerprint(dercert) do
    "sha256:" <> (:sha256 |> :crypto.hash(dercert) |> Base.encode64())
  end
end
