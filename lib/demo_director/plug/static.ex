defmodule DemoDirector.Plug.Static do
  @moduledoc """
  Mounted at the package's mount path by
  `DemoDirector.Router.demo_director/1`. Routes:

    * `GET demo_director.css` / `GET demo_director.js` — static
      assets, served from `priv/static/`.
    * `GET demos` — HTML listing of saved demos with a Play button per
      row (delegates to `DemoDirector.Plug.Index`).
    * `GET demos/<name>.js` — JSON wrapper around a demo's emitted JS,
      used by the listing page's Play buttons.
    * `POST play` — broadcasts the request body as a playback JS
      payload (delegates to `DemoDirector.Plug.Play`).

  Anything else returns 404.
  """

  @behaviour Plug

  @impl Plug
  def init(opts) do
    %{
      static:
        Plug.Static.init(
          Keyword.merge(
            [
              at: "/",
              from: {:demo_director, "priv/static"},
              gzip: false,
              only: ~w(demo_director.css demo_director.js)
            ],
            opts
          )
        ),
      play: DemoDirector.Plug.Play.init([]),
      index: DemoDirector.Plug.Index.init([])
    }
  end

  @impl Plug
  def call(%Plug.Conn{path_info: ["play"]} = conn, %{play: opts}) do
    DemoDirector.Plug.Play.call(conn, opts)
  end

  def call(%Plug.Conn{path_info: ["demos" | _]} = conn, %{index: opts}) do
    DemoDirector.Plug.Index.call(conn, opts)
  end

  def call(conn, %{static: opts}) do
    case Plug.Static.call(conn, opts) do
      %Plug.Conn{state: :unset} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(404, "not found")

      conn ->
        conn
    end
  end
end
