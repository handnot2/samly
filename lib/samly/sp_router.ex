defmodule Samly.SPRouter do
  @moduledoc false

  use Plug.Router
  import Plug.Conn
  import Samly.RouterUtil, only: [check_idp_id: 2]

  plug :fetch_session
  plug :match
  plug :check_idp_id
  plug :dispatch

  get "/metadata/*idp_id_seg" do
    # TODO: Make a release task to generate SP metadata
    conn |> Samly.SPHandler.send_metadata()
  end

  post "/consume/*idp_id_seg" do
    conn |> Samly.SPHandler.consume_signin_response()
  end

  post "/logout/*idp_id_seg" do
    cond do
      conn.params["SAMLResponse"] != nil -> Samly.SPHandler.handle_logout_response(conn)
      conn.params["SAMLRequest"] != nil -> Samly.SPHandler.handle_logout_request(conn)
      true -> conn |> send_resp(403, "invalid_request")
    end
  end

  match _ do
    conn |> send_resp(404, "not_found")
  end
end
