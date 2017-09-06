defmodule Samly.RouterUtil do
  @moduledoc false

  alias Plug.Conn

  def send_saml_request(conn, idp_url, signed_xml_payload, relay_state) do
    import :esaml_binding, only: [encode_http_redirect: 4, encode_http_post: 3]

    ie? = Conn.get_req_header(conn, "user-agent") == ["MSIE"]

    saml_url = encode_http_redirect(idp_url, signed_xml_payload, "n/a", relay_state)
    if ie? && byte_size(saml_url) > 2042 do
      resp_body = encode_http_post(idp_url, signed_xml_payload, relay_state)
      conn |> Conn.send_resp(200, resp_body)
    else
      conn |> redirect(302, saml_url)
    end
  end

  def redirect(conn, status_code, dest) do
    conn
    |>  Conn.put_resp_header("Location", dest)
    |>  Conn.send_resp(status_code, "")
    |>  Conn.halt()
  end
end
