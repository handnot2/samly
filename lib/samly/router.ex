defmodule Samly.Router do
  @moduledoc false

  use Plug.Router

  plug :secure_samly
  plug :match
  plug :dispatch

  forward("/auth", to: Samly.AuthRouter)
  forward("/sp", to: Samly.SPRouter)

  match _ do
    conn |> send_resp(404, "not_found")
  end

  defp secure_samly(conn, _opts) do
    conn
    |> register_before_send(fn connection ->
      connection
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("pragma", "no-cache")
      |> put_resp_header("x-frame-options", "SAMEORIGIN")
      |> put_resp_header("x-xss-protection", "1; mode=block")
      |> put_resp_header("x-content-type-options", "nosniff")
    end)
  end
end
