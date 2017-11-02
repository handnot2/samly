defmodule Samly.IdpData do
  require Logger
  alias Samly.IdpData
  alias Samly.SpData
  alias Samly.ConfigError

  require Samly.Esaml
  alias Samly.{Esaml, Helper}

  @boolean_attrs [
    :use_redirect_for_req,
    :sign_requests,
    :sign_metadata,
    :signed_assertion_in_resp,
    :signed_envelopes_in_resp
  ]

  defstruct [
    id: nil,
    sp_id: nil,
    base_url: nil,
    metadata_file: nil,
    pre_session_create_pipeline: nil,
    use_redirect_for_req: false,
    sign_requests: true,
    sign_metadata: true,
    signed_assertion_in_resp: true,
    signed_envelopes_in_resp: true,
    fingerprints: [],
    esaml_idp_rec: nil,
    esaml_sp_rec: nil
  ]

  @type t :: %__MODULE__{
    id: nil | String.t,
    sp_id: nil | String.t,
    base_url: nil | String.t,
    metadata_file: nil | String.t,
    pre_session_create_pipeline: nil | module,
    use_redirect_for_req: boolean,
    sign_requests: boolean,
    sign_metadata: boolean,
    signed_assertion_in_resp: boolean,
    signed_envelopes_in_resp: boolean,
    fingerprints: keyword(binary),
    esaml_idp_rec: nil | tuple,
    esaml_sp_rec: nil | tuple
  }

  @type id :: String.t

  @spec load_identity_providers(list(map), %{required(id) => SpData.t}, binary)
    :: %{required(id) => t}
  def load_identity_providers(prov_config, service_providers, base_url) do
    prov_config
    |> Enum.map(fn idp -> load_idp_data(idp, service_providers, base_url) end)
    |> Enum.into(%{})
  end

  @default_idp_metadata_file "idp_metadata.xml"

  @spec load_idp_data(map, %{required(id) => SpData.t}, binary)
    :: {id, IdpData.t} | no_return
  defp load_idp_data(%{} = idp_entry, service_providers, default_base_url) do
    with  idp_id when idp_id != nil <- Map.get(idp_entry, :id),
          base_url when (base_url == nil or is_binary(base_url)) <-
            Map.get(idp_entry, :base_url, default_base_url),
          metadata_file when metadata_file != nil <-
            Map.get(idp_entry, :metadata_file, @default_idp_metadata_file),
          pl when (pl == nil or is_atom(pl)) <- Map.get(idp_entry, :pre_session_create_pipeline),
          {:reading, {:ok, xml}} <- {:reading, File.read(metadata_file)},
          {:parsing, {:ok, mdt}} <- {:parsing, idp_metadata_from_xml(xml)},
          sp_id when sp_id != nil <- Map.get(idp_entry, :sp_id, nil),
          sp when sp != nil <- Map.get(service_providers, sp_id, nil)
    do
      idp =
        @boolean_attrs
        |> Enum.reduce(%__MODULE__{}, fn attr, idp ->
             v = Map.get(idp_entry, attr)
             if is_boolean(v), do: Map.put(idp, attr, v), else: idp
           end)

      idp = %__MODULE__{idp
        | id: idp_id,
          sp_id: sp_id,
          base_url: base_url,
          metadata_file: metadata_file,
          pre_session_create_pipeline: pl,
          fingerprints: idp_cert_fingerprints(mdt),
          esaml_idp_rec: mdt,
      }

      {idp.id, %__MODULE__{idp | esaml_sp_rec: get_esaml_sp_rec(sp, idp, base_url)}}
    else
      {:reading, {:error, reason}} ->
        Logger.error("[Samly] Failed to read metadata_file: #{inspect reason}")
        raise ConfigError, idp_entry
      {:parsing, {:error, reason}} ->
        Logger.error("[Samly] Invalid metadata_file content: #{inspect reason}")
        raise ConfigError, idp_entry
      _ ->
        raise ConfigError, idp_entry
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

  def get_esaml_sp_rec(%SpData{} = sp, %IdpData{} = idp, base_url) do
    entity_id = case sp.entity_id do
      nil -> :undefined
      :undefined -> :undefined
      id -> String.to_charlist(id)
    end

    idp_id_from = Application.get_env(:samly, :idp_id_from)
    path_segment_idp_id = if idp_id_from == :subdomain, do: nil, else: idp.id

    sp_rec = Esaml.esaml_sp(
      key: sp.key,
      certificate: sp.cert,
      sp_sign_requests: idp.sign_requests,
      sp_sign_metadata: idp.sign_metadata,
      idp_signs_envelopes: idp.signed_envelopes_in_resp,
      idp_signs_assertions: idp.signed_assertion_in_resp,
      trusted_fingerprints: idp.fingerprints,
      metadata_uri: Helper.get_metadata_uri(base_url, path_segment_idp_id),
      consume_uri: Helper.get_consume_uri(base_url, path_segment_idp_id),
      logout_uri: Helper.get_logout_uri(base_url, path_segment_idp_id),
      entity_id: entity_id,
      org: Esaml.esaml_org(
        name: String.to_charlist(sp.org_name),
        displayname: String.to_charlist(sp.org_displayname),
        url: String.to_charlist(sp.org_url)),
      tech: Esaml.esaml_contact(
        name: String.to_charlist(sp.contact_name),
        email: String.to_charlist(sp.contact_email))
    )

    sp_rec
  end
end
