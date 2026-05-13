defmodule Mix.Tasks.DemoDirector.PlayTest do
  use ExUnit.Case, async: true

  # The Mix task probes a small list of conventional mount paths before
  # falling back to a default. Drift in the candidate list is exactly
  # what shipped a real bug in 0.1.5: the list missed `/dev/demo-director`
  # (the installer's default), so against a stock install every probe
  # 404'd and the fallback printed an un-mountable URL. These tests pin
  # the contract so the same kind of drift can't slip through silently
  # again.

  alias Mix.Tasks.DemoDirector.Play

  describe "candidate mount paths" do
    test "includes the installer's default first" do
      paths = Play.__candidate_mount_paths__()
      assert List.first(paths) == "/dev/demo-director"
    end

    test "includes the bare mount path as a fallback" do
      paths = Play.__candidate_mount_paths__()
      assert "/demo-director" in paths
    end

    test "does not include legacy /director or /dev/director paths" do
      # These were removed in 0.1.6. Older README versions documented
      # `/director` as the manual wire-up path; 0.1.3 aligned the docs
      # to `/demo-director`. Probing legacy paths would resolve against
      # stale routes in older installs but would never be what a new
      # install produces, so they're dropped.
      paths = Play.__candidate_mount_paths__()
      refute "/director" in paths
      refute "/dev/director" in paths
    end

    test "every candidate path starts with a leading slash" do
      paths = Play.__candidate_mount_paths__()

      assert Enum.all?(paths, fn p -> String.starts_with?(p, "/") end),
             "candidate paths must be absolute: got #{inspect(paths)}"
    end

    test "no candidate path has a trailing slash" do
      paths = Play.__candidate_mount_paths__()

      assert Enum.all?(paths, fn p -> not String.ends_with?(p, "/") end),
             "candidate paths must not have a trailing slash: got #{inspect(paths)}"
    end
  end

  describe "play URL resolution" do
    test "returns the installer-default URL with :down when all probes miss" do
      always_miss = fn _host, _mount_path, _name -> nil end

      {url, status} =
        Play.__resolve_play_url__("drug_safety", "http://localhost:4000", always_miss)

      assert status == :down

      assert url == "http://localhost:4000/dev/demo-director/demos/drug_safety/play",
             "fallback must use the installer's default mount path"
    end

    test "returns a probed URL with :up when the first candidate succeeds" do
      # Simulate a server that 200s only on /dev/demo-director (the
      # installer's default and the first probe candidate).
      probe = fn host, mount_path, name ->
        if mount_path == "/dev/demo-director" do
          host <> mount_path <> "/demos/" <> name <> "/play"
        end
      end

      {url, status} = Play.__resolve_play_url__("drug_safety", "http://localhost:4000", probe)

      assert status == :up
      assert url == "http://localhost:4000/dev/demo-director/demos/drug_safety/play"
    end
  end
end
