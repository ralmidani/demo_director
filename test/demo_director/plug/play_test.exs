defmodule DemoDirector.Plug.PlayTest do
  use ExUnit.Case, async: false

  alias DemoDirector.Plug.Play

  setup do
    # The plug calls Playback.play! which reads :pubsub from app env;
    # set it to a known PubSub started for the test.
    pubsub = Module.concat(__MODULE__, PubSub)
    {:ok, _} = start_supervised({Phoenix.PubSub, name: pubsub})
    Application.put_env(:demo_director, :pubsub, pubsub)

    on_exit(fn -> Application.delete_env(:demo_director, :pubsub) end)
    {:ok, pubsub: pubsub}
  end

  describe "method gating" do
    test "returns 405 on GET" do
      conn = conn_for(:get, "/play", "")
      conn = Play.call(conn, [])
      assert conn.status == 405
      assert conn.resp_body == "method not allowed"
    end

    test "returns 405 on PUT" do
      conn = conn_for(:put, "/play", "anything")
      conn = Play.call(conn, [])
      assert conn.status == 405
    end
  end

  describe "localhost gating" do
    test "rejects non-loopback IPv4 with 403" do
      conn =
        conn_for(:post, "/play", "window.alert(1)")
        |> Map.put(:remote_ip, {10, 0, 0, 1})

      conn = Play.call(conn, [])
      assert conn.status == 403
      assert conn.resp_body == "forbidden"
    end

    test "accepts 127.x.x.x" do
      Phoenix.PubSub.subscribe(pubsub_name(), "demo_director:playback")

      conn =
        conn_for(:post, "/play", "window.alert(1)")
        |> Map.put(:remote_ip, {127, 0, 0, 1})

      conn = Play.call(conn, [])
      assert conn.status == 200
      assert_receive {:play, "window.alert(1)"}, 500
    end

    test "accepts IPv6 loopback ::1" do
      Phoenix.PubSub.subscribe(pubsub_name(), "demo_director:playback")

      conn =
        conn_for(:post, "/play", "window.alert(1)")
        |> Map.put(:remote_ip, {0, 0, 0, 0, 0, 0, 0, 1})

      conn = Play.call(conn, [])
      assert conn.status == 200
      assert_receive {:play, _}, 500
    end
  end

  describe "body handling" do
    test "rejects empty body with 400" do
      conn =
        conn_for(:post, "/play", "")
        |> Map.put(:remote_ip, {127, 0, 0, 1})

      conn = Play.call(conn, [])
      assert conn.status == 400
      assert conn.resp_body == "empty body"
    end

    test "broadcasts the body verbatim on 200" do
      Phoenix.PubSub.subscribe(pubsub_name(), "demo_director:playback")

      js = "window.DemoDirector.subtitle(\"hi\");"

      conn =
        conn_for(:post, "/play", js)
        |> Map.put(:remote_ip, {127, 0, 0, 1})

      conn = Play.call(conn, [])
      assert conn.status == 200
      assert conn.resp_body == "ok"
      assert_receive {:play, ^js}, 500
    end
  end

  defp conn_for(method, path, body) do
    Plug.Test.conn(method, path, body)
  end

  defp pubsub_name do
    Application.fetch_env!(:demo_director, :pubsub)
  end
end
