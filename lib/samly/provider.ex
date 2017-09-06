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
    State.init()

    sp_base_url = System.get_env("SAML_SP_BASE_URL")
    sp_certfile = System.get_env("SAML_SP_CERTFILE") || "samly.crt"
    sp_keyfile  = System.get_env("SAML_SP_KEYFILE")  || "samly.pem"
    idp_metadatafile = System.get_env("SAML_IDP_METADATA_FILE") || "idp_metadata.xml"

    with  {:idp_metadata_file, {:ok, metadata_xml}} <-
            {:idp_metadata_file, File.read(idp_metadatafile)},
          {:idp_metadata_parsing, {:ok, idp_metadata}} <-
            {:idp_metadata_parsing, idp_metadata_from_xml(metadata_xml)},
          trusted_fingerprints = idp_cert_fingerprints(idp_metadata),
          {:ok, sp} <- create_sp(sp_certfile, sp_keyfile, sp_base_url, trusted_fingerprints)
    do
      Application.put_env(:samly, :sp, sp)
      Application.put_env(:samly, :idp_metadata, idp_metadata)
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

  def load_sp_priv_key(file) do
    file |> :esaml_util.load_private_key()
  end

  def load_sp_cert(file) do
    file |> :esaml_util.load_certificate()
  end

  def create_sp(certfile, keyfile, sp_base_url, trusted_fingerprints) do
    certfile = String.to_charlist(certfile)
    keyfile  = String.to_charlist(keyfile)
    sp_base_url = String.to_charlist(sp_base_url)

    cert = load_sp_cert(certfile)
    key  = load_sp_priv_key(keyfile)

    sp_rec = Esaml.esaml_sp(
      key: key,
      certificate: cert,
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

  def idp_metadata_from_xml(metadata_xml) when is_binary(metadata_xml) do
    try do
      {xml, _} = metadata_xml
      |>  String.to_charlist()
      |>  :xmerl_scan.string(namespace_conformant: true)
      :esaml.decode_idp_metadata(xml)
    rescue
      _ -> {:error, :invalid_metadata_xml}
    end
  end

  def idp_cert_fingerprints(idp_metadata) do
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
