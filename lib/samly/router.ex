defmodule Samly.Router do
  @moduledoc false

  use Plug.Router

  require Samly.Esaml
  alias Samly.Esaml

  alias Samly.Helper
  alias Samly.State

  plug :no_cache
  plug :match
  plug :dispatch

  get "/metadata" do
    metadata = Helper.get_sp() |> Helper.sp_metadata()
    conn
    |>  put_resp_header("Content-Type", "text/xml")
    |>  send_resp(200, metadata)
  end

  get "/auth" do
    sp = Helper.get_sp()
    idp_metadata = Helper.get_idp_metadata()

    target_url = conn.params["target_url"] || "/"
    nameid = get_session(conn, "samly_nameid")
    case State.get_by_nameid(nameid) do
      {^nameid, _assertions} ->
        conn
        |>  redirect(302, target_url)
      _ ->
        relay_state = State.gen_id()
        {idp_signon_url, req_xml_frag} = Helper.gen_idp_signon_req(sp, idp_metadata)

        conn
        |>  configure_session(renew: true)
        |>  put_session("relay_state", relay_state)
        |>  put_session("target_url", target_url)
        |>  send_saml_request(idp_signon_url, req_xml_frag, relay_state)
    end
  end

  get "/deauth" do
    sp = Helper.get_sp()
    idp_metadata = Helper.get_idp_metadata()
    target_url = conn.params["target_url"] || "/"
    nameid = get_session(conn, "samly_nameid")

    case State.get_by_nameid(nameid) do
      {^nameid, _assertions} ->
        {idp_signout_url, req_xml_frag} = Helper.gen_idp_signout_req(sp, idp_metadata, nameid)

        State.delete(nameid)
        relay_state = State.gen_id()

        conn
        |>  put_session("target_url", target_url)
        |>  put_session("relay_state", relay_state)
        |>  delete_session("samly_nameid")
        |>  send_saml_request(idp_signout_url, req_xml_frag, relay_state)
      _ ->
        conn
        |>  send_resp(403, "access_denied")
    end
  end

  post "/consume" do
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

  post "/logout" do
    cond do
      conn.params["SAMLResponse"] != nil -> handle_logout_response(conn)
      conn.params["SAMLRequest"] != nil ->  handle_logout_request(conn)
      true ->
        conn |> send_resp(403, "invalid_request")
    end
  end

  get "/" do
    path = conn.request_path |> String.trim_trailing("/")
    conn |> redirect(301, path <> "/metadata")
  end

  match _ do
    conn |> send_resp(404, "Samly: not_found")
  end


  defp handle_logout_response(conn) do
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
  defp handle_logout_request(conn) do
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

  defp send_saml_request(conn, idp_url, signed_xml_payload, relay_state) do
    import :esaml_binding, only: [encode_http_redirect: 4, encode_http_post: 3]

    ie? = get_req_header(conn, "user-agent") == ["MSIE"]

    saml_url = encode_http_redirect(idp_url, signed_xml_payload, "n/a", relay_state)
    if ie? && byte_size(saml_url) > 2042 do
      resp_body = encode_http_post(idp_url, signed_xml_payload, relay_state)
      conn |> send_resp(200, resp_body)
    else
      conn |> redirect(302, saml_url)
    end
  end

  defp redirect(conn, status_code, dest) do
    conn
    |>  put_resp_header("Location", dest)
    |>  send_resp(status_code, "")
    |>  halt()
  end

  defp no_cache(conn, _opts) do
    conn
    |>  register_before_send(fn connection ->
          connection
          |>  put_resp_header("Cache-Control", "no-cache")
          |>  put_resp_header("Pragma", "no-cache")
        end)
  end
end
