defmodule Samly.SPHandler do
  @moduledoc false

  import Plug.Conn
  alias Samly.Helper
  alias Samly.State

  import Samly.RouterUtil, only: [send_saml_request: 4, redirect: 3]

  require Samly.Esaml
  alias Samly.Esaml

  def send_metadata(conn) do
    metadata = Helper.get_sp() |> Helper.sp_metadata()
    conn
    |>  put_resp_header("Content-Type", "text/xml")
    |>  send_resp(200, metadata)
  end

  def consume_signin_response(conn) do
    sp = Helper.get_sp()

    saml_encoding = conn.body_params["SAMLEncoding"]
    saml_response = conn.body_params["SAMLResponse"]
    relay_state   = conn.body_params["RelayState"]

    with  ^relay_state when relay_state != nil <- get_session(conn, "relay_state"),
          target_url when target_url != nil <- get_session(conn, "target_url"),
          {:ok, resp} <- Helper.decode_idp_auth_resp(sp, saml_encoding, saml_response)
    do
      %{nameid: nameid, attributes: assertions} = resp
      State.put(nameid, assertions)

      conn
      |>  configure_session(renew: true)
      |>  put_session("samly_nameid", nameid)
      |>  redirect(302, target_url)
    else
      {:error, reason} ->
        conn
        |>  send_resp(403, "access_denied #{inspect reason}")
      _ ->
        conn
        |>  send_resp(403, "access_denied")
    end
  end

  def handle_logout_response(conn) do
    sp = Helper.get_sp()

    saml_encoding = conn.body_params["SAMLEncoding"]
    saml_response = conn.body_params["SAMLResponse"]
    relay_state   = conn.body_params["RelayState"]

    with  {:ok, _payload} <- Helper.decode_idp_signout_resp(sp, saml_encoding, saml_response),
          ^relay_state when relay_state != nil <- get_session(conn, "relay_state"),
          target_url when target_url != nil <- get_session(conn, "target_url")
    do
      conn
      |>  configure_session(drop: true)
      |>  redirect(302, target_url)
    else
      error ->
        conn
        |> send_resp(403, "invalid_request #{inspect error}")
    end
  end

  # non-ui logout request from IDP
  def handle_logout_request(conn) do
    sp = Helper.get_sp()
    idp_metadata = Helper.get_idp_metadata()

    saml_encoding = conn.body_params["SAMLEncoding"]
    saml_request  = conn.body_params["SAMLRequest"]
    relay_state   = conn.body_params["RelayState"]

    with {:ok, payload} <- Helper.decode_idp_signout_req(sp, saml_encoding, saml_request)
    do
      nameid = Esaml.esaml_logoutreq(payload, :name)
      case State.get_by_nameid(nameid) do
        {^nameid, _assertions} ->
          State.delete(nameid)
        _ -> :ok
      end
      {idp_signout_url, resp_xml_frag} = Helper.gen_idp_signout_resp(sp, idp_metadata, :success)

      conn
      |>  configure_session(drop: true)
      |>  send_saml_request(idp_signout_url, resp_xml_frag, relay_state)
    else
      _error ->
        {idp_signout_url, resp_xml_frag} = Helper.gen_idp_signout_resp(sp, idp_metadata, :denied)
        conn
        |>  send_saml_request(idp_signout_url, resp_xml_frag, relay_state)
    end
  end
end
