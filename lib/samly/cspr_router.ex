defmodule Samly.CsprRouter do
  @moduledoc false

  use Plug.Router
  import Plug.Conn

  require Logger

  plug :match
  plug :dispatch

  match _ do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Logger.error(body)
    conn |> send_resp(200, "OK")
  end
end
