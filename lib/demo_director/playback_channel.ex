defmodule DemoDirector.PlaybackChannel do
  @moduledoc """
  Phoenix channel that relays playback JS from the server to every
  connected overlay.

  When the channel joins it subscribes to the
  `"demo_director:playback"` PubSub topic on the host app's
  configured pubsub server. The `mix demo_director.play` task
  broadcasts on that topic; this channel pushes each broadcast to the
  joined client.
  """

  use Phoenix.Channel

  @topic "demo_director:playback"

  @impl true
  def join(@topic, _payload, socket) do
    pubsub = Application.fetch_env!(:demo_director, :pubsub)
    Phoenix.PubSub.subscribe(pubsub, @topic)
    {:ok, socket}
  end

  @impl true
  def handle_info({:play, js}, socket) when is_binary(js) do
    push(socket, "play", %{js: js})
    {:noreply, socket}
  end
end
