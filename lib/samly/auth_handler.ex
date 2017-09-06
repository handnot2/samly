defmodule Samly.AuthHandler do
  @moduledoc false

  import Plug.Conn
  alias Samly.Helper
  alias Samly.State

  import Samly.RouterUtil, only: [send_saml_request: 4, redirect: 3]

  @sso_init_resp_template """
  <body onload=\"document.forms[0].submit()\">
    <noscript>
      <p><strong>Note:</strong>
        Since your browser does not support JavaScript, you must press
        the button below once to proceed.
      </p>
    </noscript>
    <form method=\"post\" action=\"<%= action %>\">
      <%= if target_url do %>
      <input type=\"hidden\" name=\"target_url\" value=\"<%= target_url %>\" />
      <% end %>
      <input type=\"hidden\" name=\"_csrf_token\" value=\"<%= csrf_token %>\" />
      <noscript><input type=\"submit\" value=\"Submit\" /></noscript>
    </form>
  </body>
  """

  def valid_referer?(conn) do
    referer = case conn |> get_req_header("referer") do
      [uri] -> URI.parse(uri)
      _ -> %URI{}
    end

    [request_authority] = conn |> get_req_header("host")
    request_authority == referer.authority && referer.scheme == Atom.to_string(conn.scheme)
  end

  def initiate_sso_req(conn) do
    import Plug.CSRFProtection, only: [get_csrf_token: 0]

    if valid_referer?(conn) do
      target_url = if conn.params["target_url"] do
        conn.params["target_url"]
        |>  URI.decode_www_form()
        |>  URI.encode_www_form()
      else
        nil
      end

      opts = [
        action: conn.request_path,
        target_url: target_url,
        csrf_token: get_csrf_token()
      ]

      conn
      |>  put_resp_header("Content-Type", "text/html")
      |>  send_resp(200, EEx.eval_string(@sso_init_resp_template, opts))
    else
      conn
      |>  send_resp(403, "invalid_request")
    end
  end

  def send_signin_req(conn) do
    sp = Helper.get_sp()
    idp_metadata = Helper.get_idp_metadata()

    target_url = conn.params["target_url"] || "/"
    |>  URI.decode_www_form()

    nameid = get_session(conn, "samly_nameid")
    case State.get_by_nameid(nameid) do
      {^nameid, _assertions} ->
        conn
        |>  redirect(302, target_url)
      _ ->
        relay_state = State.gen_id()
        {idp_signin_url, req_xml_frag} = Helper.gen_idp_signin_req(sp, idp_metadata)

        conn
        |>  configure_session(renew: true)
        |>  put_session("relay_state", relay_state)
        |>  put_session("target_url", target_url)
        |>  send_saml_request(idp_signin_url, req_xml_frag, relay_state)
    end
  end

  def send_signout_req(conn) do
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
end
