defmodule Samly.RouterUtil do
  @moduledoc false

  alias Plug.Conn

  def send_saml_request(conn, idp_url, signed_xml_payload, relay_state) do
    import :esaml_binding, only: [encode_http_post: 3]

    resp_body = encode_http_post(idp_url, signed_xml_payload, relay_state)
    conn
    |>  Conn.put_resp_header("Content-Type", "text/html")
    |>  Conn.send_resp(200, resp_body)
  end

  def redirect(conn, status_code, dest) do
    conn
    |>  Conn.put_resp_header("Location", dest)
    |>  Conn.send_resp(status_code, "")
    |>  Conn.halt()
  end
end
