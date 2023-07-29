defmodule Emulsion.Exporter do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, %{directory: nil}}
  end

  def get_directory() do
    GenServer.call(__MODULE__, :get_directory)
  end

  def set_directory(directory) do
    GenServer.call(__MODULE__, {:set_directory, directory})
  end

  def export_playgraph(playgraph) do
    GenServer.call(__MODULE__, {:export_playgraph, playgraph})
  end

  def handle_call(:get_directory, _from, state) do
    {:reply, state.directory, state}
  end

  def handle_call({:set_directory, directory}, _from, state) do
    {:reply, :ok, Map.put(state, :directory, directory)}
  end

  def handle_call({:export_playgraph, playgraph}, _from, state) do
    File.mkdir_p!("#{state.directory}/main")

    normalized_playgraph = normalize_playgraph_paths(playgraph, "#{state.directory}/main")

    File.write!("#{state.directory}/playgraph.playgraph", Jason.encode!(normalized_playgraph))
    Enum.each(normalized_playgraph["nodes"], fn node ->
      Enum.each(node["edges"], fn edge ->
        File.cp!(edge["path"], "#{state.directory}/main/#{Path.basename(edge["path"])}")
      end)
    end)

    {:reply, :ok, state}
  end

  defp normalize_playgraph_paths(playgraph, new_directory) do
    nodes = Enum.map(playgraph["nodes"], fn node ->
      Map.put(node, "edges", Enum.map(node["edges"], &normalize_edge_path(&1, new_directory)))
    end)

    %{"nodes" => nodes}
  end

  defp normalize_edge_path(edge, new_directory) do
    Map.put(edge, "path", Path.relative_to(edge["path"], new_directory))
  end
end
