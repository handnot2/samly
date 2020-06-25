defmodule Samly.AuthRouter do
  @moduledoc false

  use Plug.Router
  import Plug.Conn
  import Samly.RouterUtil, only: [check_idp_id: 2, check_target_url: 2]

  plug :fetch_session
  # plug Plug.CSRFProtection
  plug :match
  plug :check_idp_id
  plug :check_target_url
  plug :dispatch

  get "/signin/*idp_id_seg" do
    conn |> Samly.AuthHandler.initiate_sso_req()
  end

  post "/signin/*idp_id_seg" do
    conn |> Samly.AuthHandler.send_signin_req()
  end

  get "/signout/*idp_id_seg" do
    conn |> Samly.AuthHandler.initiate_sso_req()
  end

  post "/signout/*idp_id_seg" do
    conn |> Samly.AuthHandler.send_signout_req()
  end

  match _ do
    conn |> send_resp(404, "not_found")
  end
end
