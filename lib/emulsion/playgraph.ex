defmodule Emulsion.Playgraph do
  use GenServer

  # Client API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{"nodes" => []}, name: __MODULE__)
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def save(filename) do
    GenServer.call(__MODULE__, {:save, filename})
  end

  def load(filename) do
    GenServer.call(__MODULE__, {:load, filename})
  end

  def add_node(frame) do
    GenServer.call(__MODULE__, {:add_node, frame})
  end

  def get_nodes() do
    GenServer.call(__MODULE__, {:get_nodes})
  end

  def get_edges() do
    GenServer.call(__MODULE__, {:get_edges})
  end

  def add_edge(src_node_name, destination_node_name, edge_id, path_to_video) do
    GenServer.call(__MODULE__, {:add_edge, src_node_name, destination_node_name, edge_id, path_to_video})
  end

  def delete_edge(edge_id) do
    GenServer.call(__MODULE__, {:delete_edge, edge_id})
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{"nodes" => []}}
  end

  def handle_call({:save, filename}, _from, state) do
    # Convert the state to a JSON string
    json_string =
      state
      |> Jason.encode!()  # Convert to JSON

    # Write the JSON string to a file
    case File.write(filename, json_string) do
      :ok ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:load, filename}, _from, state) do
    # Read the file
    case File.read(filename) do
      {:ok, json_string} ->
        # Decode the JSON string
        new_state =
          json_string
          |> Jason.decode!()  # Decode the JSON
          # |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)  # Convert keys to atoms

        # Return the new state
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
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

  def handle_call({:add_edge, src_node_name, destination_node_name, edge_id, path_to_video}, _from, state) do
    nodes = Enum.map(state["nodes"], fn node ->
      if node["name"] == src_node_name do
        edge = %{
          "from" => src_node_name,
          "to" => destination_node_name,
          "id" => edge_id,
          "destination" => destination_node_name,
          "fromPath" => GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, src_node_name}),
          "toPath" => GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, destination_node_name}),
          "path" => GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, path_to_video})
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
