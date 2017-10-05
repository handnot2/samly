defmodule Samly.RouterUtil do
  @moduledoc false

  alias Plug.Conn

  def send_saml_request(conn, idp_url, use_redirect?, signed_xml_payload, relay_state) do
    if use_redirect? do
      url = :esaml_binding.encode_http_redirect(idp_url, signed_xml_payload, :undefined, relay_state)
      conn |> redirect(302, url)
    else
      resp_body = :esaml_binding.encode_http_post(idp_url, signed_xml_payload, relay_state)
      conn
      |>  Conn.put_resp_header("Content-Type", "text/html")
      |>  Conn.send_resp(200, resp_body)
    end
  end

  def redirect(conn, status_code, dest) do
    conn
    |>  Conn.put_resp_header("Location", dest)
    |>  Conn.send_resp(status_code, "")
    |>  Conn.halt()
  end
end
