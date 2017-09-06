defmodule Samly.Router do
  @moduledoc false

  use Plug.Router
  alias Samly.Helper

  plug :secure_samly
  plug :check_provider_state
  plug :match
  plug :dispatch

  forward "/auth", to: Samly.AuthRouter
  forward "/sp", to: Samly.SPRouter

  match _ do
    conn |> send_resp(404, "not_found")
  end

  defp secure_samly(conn, _opts) do
    conn
    |>  register_before_send(fn connection ->
          connection
          |>  put_resp_header("Cache-Control", "no-cache")
          |>  put_resp_header("Pragma", "no-cache")
          |>  put_resp_header("X-Frame-Options", "SAMEORIGIN")
          |>  put_resp_header("X-XSS-Protection", "1; mode=block")
          |>  put_resp_header("X-Content-Type-Options", "nosniff")
        end)
  end

  defp check_provider_state(conn, _opts) do
    sp = Helper.get_sp()
    idp_metadata = Helper.get_idp_metadata()

    if sp == nil || idp_metadata == nil do
      conn
      |>  send_resp(500, "Samly Provider not initialized")
      |>  halt()
    else
      conn
    end
  end
end
