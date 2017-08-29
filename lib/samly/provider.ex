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

    sp_certfile = System.get_env("SAML_SP_CERTFILE") || "ssl/server.crt"
    sp_keyfile  = System.get_env("SAML_SP_KEYFILE")  || "ssl/server.pem"
    sp_base_url = System.get_env("SAML_SP_BASE_URL")

    idp_metadata_xml = System.get_env("SAML_IDP_METADATA_FILE") |> load_metadata()
    {:ok, idp_metadata} = idp_metadata_from_xml(idp_metadata_xml)

    trusted_fingerprints = idp_cert_fingerprints(idp_metadata)
    {:ok, sp} = create_sp(sp_certfile, sp_keyfile, sp_base_url, trusted_fingerprints)

    Application.put_env(:samly, :sp, sp)
    Application.put_env(:samly, :idp_metadata, idp_metadata)

    {:ok, %{}}
  end

  defp load_metadata(file) do
    File.read!(file)
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
      consume_uri: sp_base_url ++ '/consume',
      metadata_uri: sp_base_url ++ '/metadata',
      logout_uri: sp_base_url ++ '/logout',
      org: Esaml.esaml_org(
        name: 'Noa Cara',
        displayname: 'Noa Cara',
        url: sp_base_url
      ),
      tech: Esaml.esaml_contact(
        name: 'Noa Cara Admin',
        email: 'admin@cara.my.noa'
      )
    )

    {:ok, sp_rec |> :esaml_sp.setup()}
  end

  def idp_metadata_from_xml(metadata_xml) when is_binary(metadata_xml) do
    {xml, _} = metadata_xml
    |>  String.to_charlist()
    |>  :xmerl_scan.string(namespace_conformant: true)
    :esaml.decode_idp_metadata(xml)
  end

  def idp_cert_fingerprints(idp_metadata) do
    fingerprint = idp_metadata
    |>  Esaml.esaml_idp_metadata(:certificate)
    |>  cert_fingerprint()
    |>  String.to_charlist()
    [fingerprint]
  end

  defp cert_fingerprint(dercert) do
    "sha256:" <> (:crypto.hash(:sha256, dercert) |> Base.encode64())
  end
end
