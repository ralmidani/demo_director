defmodule DemoDirector.Plug.Play do
  @moduledoc """
  Receives a POST containing JavaScript and broadcasts it on the
  `demo_director:playback` PubSub topic so connected overlays can
  eval it.

  Mounted by `DemoDirector.Router.demo_director/1` at
  `<mount_path>/play`. Restricted to localhost — playback requests
  from outside the host are rejected.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "POST"} = conn, _opts) do
    if local_remote_ip?(conn) do
      conn = read_full_body(conn)

      case conn.assigns[:tw_body] do
        body when is_binary(body) and byte_size(body) > 0 ->
          DemoDirector.Playback.play!(body)

          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, "ok")

        _ ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(400, "empty body")
      end
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(403, "forbidden")
    end
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(405, "method not allowed")
  end

  defp read_full_body(conn, acc \\ []) do
    case read_body(conn, length: 5_000_000) do
      {:ok, body, conn} ->
        assign(conn, :tw_body, IO.iodata_to_binary([acc, body]))

      {:more, body, conn} ->
        read_full_body(conn, [acc, body])

      {:error, _reason} ->
        assign(conn, :tw_body, nil)
    end
  end

  defp local_remote_ip?(%Plug.Conn{remote_ip: ip}) do
    case ip do
      {127, _, _, _} -> true
      {0, 0, 0, 0, 0, 0, 0, 1} -> true
      _ -> false
    end
  end
end
