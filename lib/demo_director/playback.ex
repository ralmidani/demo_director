defmodule DemoDirector.Playback do
  @moduledoc """
  Server-side entry point for pushing playback JS to every connected
  overlay.

  Used by `mix demo_director.play` to broadcast a saved demo's JS
  to whichever browser tab(s) currently have the overlay loaded.
  """

  @topic "demo_director:playback"

  @doc """
  Broadcasts the given JS string to every joined overlay.

  Reads the host app's pubsub server name from
  `Application.fetch_env!(:demo_director, :pubsub)`. Raises if the
  pubsub server has not been configured (the install task or manual
  wiring should set it).
  """
  @spec play!(String.t()) :: :ok
  def play!(js) when is_binary(js) do
    pubsub = Application.fetch_env!(:demo_director, :pubsub)
    Phoenix.PubSub.broadcast!(pubsub, @topic, {:play, js})
    :ok
  end
end
