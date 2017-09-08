defmodule Samly.Helper do
  @moduledoc false

  import Application, only: [get_env: 2]

  require Samly.Esaml
  alias Samly.{Assertion, Esaml}

  def get_sp() do
    get_env(:samly, :sp)
  end

  def get_idp_metadata() do
    get_env(:samly, :idp_metadata)
  end

  def sp_metadata(sp) do
    :xmerl.export([:esaml_sp.generate_metadata(sp)], :xmerl_xml)
  end

  def gen_idp_signin_req(sp, idp_metadata) do
    idp_signin_url = Esaml.esaml_idp_metadata(idp_metadata, :login_location)
    xml_frag = :esaml_sp.generate_authn_request(idp_signin_url, sp)
    {idp_signin_url, xml_frag}
  end

  def gen_idp_signout_req(sp, idp_metadata, nameid) do
    idp_signout_url = Esaml.esaml_idp_metadata(idp_metadata, :logout_location)
    xml_frag = :esaml_sp.generate_logout_request(idp_signout_url, nameid, sp)
    {idp_signout_url, xml_frag}
  end

  def gen_idp_signout_resp(sp, idp_metadata, signout_status) do
    idp_signout_url = Esaml.esaml_idp_metadata(idp_metadata, :logout_location)
    xml_frag = :esaml_sp.generate_logout_response(idp_signout_url, signout_status, sp)
    {idp_signout_url, xml_frag}
  end

  def decode_idp_auth_resp(sp, saml_encoding, saml_response) do
    with  {:ok, xml_frag} <- decode_saml_payload(saml_encoding, saml_response),
          {:ok, assertion_rec} <- :esaml_sp.validate_assertion(xml_frag, sp)
    do
      {:ok, Assertion.from_rec(assertion_rec)}
    else
      error -> {:error, {:invalid_request, "#{inspect error}"}}
    end
  end

  def decode_idp_signout_resp(sp, saml_encoding, saml_response) do
    resp_ns = [
      {'samlp', 'urn:oasis:names:tc:SAML:2.0:protocol'},
      {'saml',  'urn:oasis:names:tc:SAML:2.0:assertion'},
      {'ds', 'http://www.w3.org/2000/09/xmldsig#'}
    ]

    with  {:ok, xml_frag} <- decode_saml_payload(saml_encoding, saml_response),
          nodes when is_list(nodes) and length(nodes) == 1 <-
            :xmerl_xpath.string('/samlp:LogoutResponse', xml_frag, [{:namespace, resp_ns}])
    do
      :esaml_sp.validate_logout_response(xml_frag, sp)
    else
      _ -> {:error, :invalid_request}
    end
  end

  def decode_idp_signout_req(sp, saml_encoding, saml_request) do
    req_ns = [
      {'samlp', 'urn:oasis:names:tc:SAML:2.0:protocol'},
      {'saml',  'urn:oasis:names:tc:SAML:2.0:assertion'}
    ]

    with  {:ok, xml_frag} <- decode_saml_payload(saml_encoding, saml_request),
          nodes when is_list(nodes) and length(nodes) == 1 <-
            :xmerl_xpath.string('/samlp:LogoutRequest', xml_frag, [{:namespace, req_ns}])
    do
      :esaml_sp.validate_logout_request(xml_frag, sp)
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp decode_saml_payload(saml_encoding, saml_payload) do
    try do
      xml = :esaml_binding.decode_response(saml_encoding, saml_payload)
      {:ok, xml}
    rescue
      error -> {:error, {:invalid_response, "#{inspect error}"}}
    end
  end
end
