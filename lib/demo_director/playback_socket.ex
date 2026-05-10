defmodule DemoDirector.PlaybackSocket do
  @moduledoc """
  Phoenix socket that the overlay JS connects to in order to receive
  playback messages from `mix demo_director.play`.

  Mounted on the host app's endpoint:

      socket "/director/socket", DemoDirector.PlaybackSocket,
        websocket: true,
        longpoll: false
  """

  use Phoenix.Socket

  channel "demo_director:playback", DemoDirector.PlaybackChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
