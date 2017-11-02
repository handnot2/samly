defmodule Samly.Router do
  @moduledoc false

  use Plug.Router

  plug :secure_samly
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
end
