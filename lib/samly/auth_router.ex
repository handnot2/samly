defmodule Samly.AuthRouter do
  @moduledoc false

  use Plug.Router
  import Plug.Conn

  plug :fetch_session
  plug Plug.CSRFProtection
  plug :match
  plug :dispatch

  get "/signin" do
    Samly.AuthHandler.initiate_sso_req(conn)
  end

  post "/signin" do
    Samly.AuthHandler.send_signin_req(conn)
  end

  get "/signout" do
    Samly.AuthHandler.initiate_sso_req(conn)
  end

  post "/signout" do
    Samly.AuthHandler.send_signout_req(conn)
  end

  match _ do
    conn |> send_resp(404, "not_found")
  end
end
