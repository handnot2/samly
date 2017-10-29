defmodule Samly.Router do
  @moduledoc false

  use Plug.Router

  plug :secure_samly
  plug :match
  plug :check_provider_state
  plug :dispatch

  forward "/:idp_id/auth", to: Samly.AuthRouter
  forward "/:idp_id/sp", to: Samly.SPRouter

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
    identity_providers = Application.get_env(:samly, :identity_providers)
    idp = Map.get(identity_providers, conn.params["idp_id"])

    cond do
      Enum.empty?(identity_providers) ->
        conn |> send_resp(500, "Samly Provider not initialized") |> halt()
      idp == nil ->
        conn |> send_resp(403, "invalid_request unknown IdP") |> halt()
      true ->
        conn
    end
  end
end
