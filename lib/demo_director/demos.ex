defmodule DemoDirector.Demos do
  @moduledoc """
  Discovers and parses metadata from saved demo scripts.

  Demos are `.exs` files in `priv/demos/` (host-app demos) or
  `dev/priv/demos/` (this package's own demos). Each file's leading
  comment block is parsed for two pieces of metadata:

    * the first `# Demo: …` comment becomes the demo's title
    * an optional `# @start_at "/path"` comment declares which route
      the demo expects the user to be on before it runs

  Anything past the leading comment block is the script body that
  emits JS via `IO.puts`.
  """

  defstruct [:name, :path, :title, :start_at]

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t(),
          title: String.t(),
          start_at: String.t() | nil
        }

  @doc """
  Lists every saved demo discoverable from the current working
  directory, sorted by name.
  """
  @spec list() :: [t()]
  def list do
    paths()
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "*.exs")))
    |> Enum.uniq_by(&Path.basename/1)
    |> Enum.map(&parse/1)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Loads a single demo by name, returning `{:ok, demo}` or `:error`.
  """
  @spec fetch(String.t()) :: {:ok, t()} | :error
  def fetch(name) when is_binary(name) do
    case Enum.find(list(), &(&1.name == name)) do
      nil -> :error
      demo -> {:ok, demo}
    end
  end

  @doc """
  Loads a demo's emitted JS by evaluating its `.exs` file with stdout
  captured. Returns the JS as a string.
  """
  @spec load_js(t()) :: String.t()
  def load_js(%__MODULE__{path: path}) do
    capture_io(fn -> Code.eval_file(path) end)
  end

  defp paths do
    [Path.join(["priv", "demos"]), Path.join(["dev", "priv", "demos"])]
  end

  @doc """
  Extracts `{title, start_at}` from the leading comment block of a
  demo script's contents. Returns `{nil, nil}` if neither is present.
  Public for testability.
  """
  @spec parse_metadata(String.t()) :: {String.t() | nil, String.t() | nil}
  def parse_metadata(contents) when is_binary(contents) do
    lines = leading_comment_lines(contents)
    {extract_title(lines), extract_start_at(lines)}
  end

  defp parse(path) do
    contents = File.read!(path)
    name = Path.basename(path, ".exs")
    {title, start_at} = parse_metadata(contents)

    %__MODULE__{
      name: name,
      path: path,
      title: title || name,
      start_at: start_at
    }
  end

  defp extract_title(lines) do
    Enum.find_value(lines, fn line ->
      case Regex.run(~r/^#\s*Demo:\s*(.+)$/, line) do
        [_, title] -> String.trim(title)
        _ -> nil
      end
    end)
  end

  defp extract_start_at(lines) do
    Enum.find_value(lines, fn line ->
      case Regex.run(~r/^#\s*@start_at\s+"([^"]+)"\s*$/, line) do
        [_, path] -> path
        _ -> nil
      end
    end)
  end

  defp leading_comment_lines(contents) do
    contents
    |> String.split("\n")
    |> Enum.take_while(fn line -> String.starts_with?(line, "#") or line == "" end)
  end

  defp capture_io(fun) do
    {:ok, capture_pid} = StringIO.open("")
    original_gl = Process.group_leader()
    Process.group_leader(self(), capture_pid)

    try do
      fun.()
    after
      Process.group_leader(self(), original_gl)
    end

    {:ok, {_in, out}} = StringIO.close(capture_pid)
    out
  end
end
