defmodule Samly.SPRouter do
  @moduledoc false

  use Plug.Router
  import Plug.Conn

  plug :fetch_session
  plug :match
  plug :dispatch

  get "/metadata" do
    # TODO: Make a release task to generate SP metadata
    Samly.SPHandler.send_metadata(conn)
  end

  post "/consume" do
    Samly.SPHandler.consume_signin_response(conn)
  end

  post "/logout" do
    cond do
      conn.params["SAMLResponse"] != nil ->
        Samly.SPHandler.handle_logout_response(conn)
      conn.params["SAMLRequest"] != nil ->
        Samly.SPHandler.handle_logout_request(conn)
      true ->
        conn |> send_resp(403, "invalid_request")
    end
  end

  match _ do
    conn |> send_resp(404, "not_found")
  end
end
