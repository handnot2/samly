defmodule Samly.SPHandler do
  @moduledoc false

  require Logger
  import Plug.Conn
  alias Plug.Conn
  require Samly.Esaml
  alias Samly.{Assertion, Esaml, Helper, State}

  import Samly.RouterUtil, only: [send_saml_request: 5, redirect: 3]

  def send_metadata(conn) do
    metadata = Helper.get_sp()
    |>  Helper.ensure_sp_uris_set(conn)
    |>  Helper.sp_metadata()

    conn
    |>  put_resp_header("Content-Type", "text/xml")
    |>  send_resp(200, metadata)
  rescue
    error ->
      Logger.error("#{inspect error}")
      conn |> send_resp(500, "request_failed")
  end

  def consume_signin_response(conn) do
    sp = Helper.get_sp() |> Helper.ensure_sp_uris_set(conn)

    saml_encoding = conn.body_params["SAMLEncoding"]
    saml_response = conn.body_params["SAMLResponse"]
    relay_state   = conn.body_params["RelayState"] |> URI.decode_www_form()

    pipeline = Application.get_env(:samly, :pre_session_create_pipeline)

    with  ^relay_state when relay_state != nil <- get_session(conn, "relay_state"),
          target_url when target_url != nil <- get_session(conn, "target_url"),
          {:ok, assertion} <- Helper.decode_idp_auth_resp(sp, saml_encoding, saml_response),
          conn = conn |> put_private(:samly_assertion, assertion),
          {:halted, %Conn{halted: false} = conn} <-
            {:halted, pipethrough(conn, pipeline)}
    do
      updated_assertion = conn.private[:samly_assertion]
      computed = updated_assertion.computed
      assertion = %Assertion{assertion | computed: computed}

      nameid = assertion.subject.name
      State.put(nameid, assertion)

      conn
      |>  configure_session(renew: true)
      |>  put_session("samly_nameid", nameid)
      |>  redirect(302, target_url |> URI.decode_www_form())
    else
      {:halted, conn} -> conn
      {:error, reason} ->
        conn
        |>  send_resp(403, "access_denied #{inspect reason}")
      _ ->
        conn
        |>  send_resp(403, "access_denied")
    end
  rescue
    error ->
      Logger.error("#{inspect error}")
      conn |> send_resp(500, "request_failed")
  end

  defp pipethrough(conn, nil), do: conn
  defp pipethrough(conn, pipeline) do
    pipeline.call(conn, [])
  end

  def handle_logout_response(conn) do
    sp = Helper.get_sp() |> Helper.ensure_sp_uris_set(conn)

    saml_encoding = conn.body_params["SAMLEncoding"]
    saml_response = conn.body_params["SAMLResponse"]
    relay_state   = conn.body_params["RelayState"] |> URI.decode_www_form()

    with  {:ok, _payload} <- Helper.decode_idp_signout_resp(sp, saml_encoding, saml_response),
          ^relay_state when relay_state != nil <- get_session(conn, "relay_state"),
          target_url when target_url != nil <- get_session(conn, "target_url")
    do
      conn
      |>  configure_session(drop: true)
      |>  redirect(302, target_url |> URI.decode_www_form())
    else
      error ->
        conn
        |> send_resp(403, "invalid_request #{inspect error}")
    end
  rescue
    error ->
      Logger.error("#{inspect error}")
      conn |> send_resp(500, "request_failed")
  end

  # non-ui logout request from IDP
  def handle_logout_request(conn) do
    sp = Helper.get_sp() |> Helper.ensure_sp_uris_set(conn)
    idp_metadata = Helper.get_idp_metadata()

    saml_encoding = conn.body_params["SAMLEncoding"]
    saml_request  = conn.body_params["SAMLRequest"]
    relay_state   = conn.body_params["RelayState"]

    with {:ok, payload} <- Helper.decode_idp_signout_req(sp, saml_encoding, saml_request)
    do
      nameid = Esaml.esaml_logoutreq(payload, :name)
      case State.get_by_nameid(nameid) do
        {^nameid, _saml_assertion} ->
          State.delete(nameid)
        _ -> :ok
      end
      {idp_signout_url, resp_xml_frag} = Helper.gen_idp_signout_resp(sp, idp_metadata, :success)

      conn
      |>  configure_session(drop: true)
      |>  send_saml_request(idp_signout_url, Helper.use_redirect_for_idp_req(),
            resp_xml_frag, relay_state)
    else
      _error ->
        {idp_signout_url, resp_xml_frag} = Helper.gen_idp_signout_resp(sp, idp_metadata, :denied)
        conn
        |>  send_saml_request(idp_signout_url, Helper.use_redirect_for_idp_req(),
              resp_xml_frag, relay_state)
    end
  rescue
    error ->
      Logger.error("#{inspect error}")
      conn |> send_resp(500, "request_failed")
  end
end
