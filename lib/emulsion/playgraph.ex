defmodule Emulsion.Playgraph do
  use GenServer

  # Client API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{"nodes" => []}, name: __MODULE__)
  end

  def handle_call({:add_node, frame_path}, _from, state) do
    # Check if the node already exists
    if Enum.any?(state["nodes"], fn node -> node["id"] == frame_path end) do
      {:reply, :ok, state}
    else
      node = %{
        "id" => frame_path,
        "label" => frame_path |> Path.basename,
        "name" => frame_path,
        "edges" => []
      }
      {:reply, :ok, Map.put(state, "nodes", [node | state["nodes"]])}
    end
  end

  def add_node(frame) do
    GenServer.call(__MODULE__, {:add_node, frame})
  end

  def add_edge(src_node_name, destination_node_name, edge_id, path_to_video) do
    GenServer.call(__MODULE__, {:add_edge, src_node_name, destination_node_name, edge_id, path_to_video})
  end

  def delete_edge(edge_id) do
    GenServer.call(__MODULE__, {:delete_edge, edge_id})
  end

  def handle_call({:get_nodes}, _from, state) do
    {:reply, state["nodes"], state}
  end

  def handle_call({:get_edges}, _from, state) do
    edges = state["nodes"]
             |> Enum.map(& &1["edges"])
             |> List.flatten()

    {:reply, edges, state}
  end

  # GenServer Callbacks


  def handle_call({:add_edge, src_node_name, destination_node_name, edge_id, path_to_video}, _from, state) do
    nodes = Enum.map(state["nodes"], fn node ->
      if node["name"] == src_node_name do
        edge = %{
          "id" => edge_id,
          "from" => src_node_name,
          "to" => destination_node_name,
          "destination" => destination_node_name,
          "path" => path_to_video
        }

        Map.put(node, "edges", [edge | node["edges"]])
      else
        node
      end
    end)

    {:reply, :ok, Map.put(state, "nodes", nodes)}
  end

  def handle_call({:delete_edge, node_name, edge_id}, _from, state) do
    nodes = Enum.map(state["nodes"], fn node ->
      if node["name"] == node_name do
        edges = Enum.filter(node["edges"], fn edge -> edge["id"] != edge_id end)

        Map.put(node, "edges", edges)
      else
        node
      end
    end)

    {:reply, :ok, Map.put(state, "nodes", nodes)}
  end
end
