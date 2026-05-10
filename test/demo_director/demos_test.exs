defmodule DemoDirector.DemosTest do
  use ExUnit.Case, async: true

  alias DemoDirector.Demos

  describe "parse_metadata/1" do
    test "extracts title from a `# Demo:` line" do
      contents = """
      # Demo: compose a post.
      #
      # Walks through the composer.

      alias DemoDirector, as: TD
      """

      assert Demos.parse_metadata(contents) == {"compose a post.", nil}
    end

    test "extracts start_at from `# @start_at \"/path\"`" do
      contents = """
      # Demo: open a post.
      # @start_at "/posts/123"
      """

      assert Demos.parse_metadata(contents) == {"open a post.", "/posts/123"}
    end

    test "title and start_at can appear in either order" do
      contents = """
      # @start_at "/"
      # Demo: list posts.
      """

      assert Demos.parse_metadata(contents) == {"list posts.", "/"}
    end

    test "returns {nil, nil} when neither header is present" do
      contents = """
      # A regular comment.
      # Nothing demo-related.

      alias DemoDirector, as: TD
      """

      assert Demos.parse_metadata(contents) == {nil, nil}
    end

    test "returns nil for start_at when @start_at is malformed (no quotes)" do
      contents = """
      # Demo: bad header.
      # @start_at /no-quotes
      """

      assert Demos.parse_metadata(contents) == {"bad header.", nil}
    end

    test "stops scanning at the first non-comment, non-blank line" do
      contents = """
      # Demo: real title.

      alias DemoDirector, as: TD

      # @start_at "/" — this is past the leading block, ignored.
      """

      assert Demos.parse_metadata(contents) == {"real title.", nil}
    end

    test "blank lines inside the leading comment block are tolerated" do
      contents = """
      # Demo: with blanks.
      #

      # @start_at "/somewhere"
      """

      assert Demos.parse_metadata(contents) == {"with blanks.", "/somewhere"}
    end

    test "trims whitespace around the title" do
      contents = "# Demo:    plenty of leading space   \n"
      assert Demos.parse_metadata(contents) == {"plenty of leading space", nil}
    end

    test "first matching `# Demo:` wins when multiple are present" do
      contents = """
      # Demo: first one.
      # Demo: second one.
      """

      assert Demos.parse_metadata(contents) == {"first one.", nil}
    end
  end
end
