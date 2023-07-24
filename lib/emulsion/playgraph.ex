defmodule Emulsion.Playgraph do
  use GenServer

  # Client API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{"nodes" => []}, name: __MODULE__)
  end

  def export_playgraph(folder_path) do
    GenServer.call(__MODULE__, {:export_playgraph, folder_path})
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def save(filename) do
    GenServer.call(__MODULE__, {:save, filename})
  end

  def get_saved_playgraphs(path) do
    path
    |> Path.join("*.playgraph")
    |> Path.wildcard()
    |> Enum.map(&Path.basename/1)
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
    GenServer.call(
      __MODULE__,
      {:add_edge, src_node_name, destination_node_name, edge_id, path_to_video}
    )
  end

  def delete_edge(edge_id) do
    GenServer.call(__MODULE__, {:delete_edge, edge_id})
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{"nodes" => []}}
  end

  @doc """
  Export the playgraph and all of its assets to a folder
  """
  def handle_call({:export_playgraph, folder_path}, _from, state) do
    # Ensure the assets folder exists
    assets_path = Path.join(folder_path, "assets")
    File.mkdir_p(assets_path)

    # Adjust paths in the state and copy the assets
    new_state =
      state
      |> adjust_edge_paths_for_export(assets_path)
      |> copy_assets_to_export_folder(assets_path)

    # Save the adjusted playgraph to the indicated folder
    playgraph_path = Path.join(folder_path, "main.playgraph")
    save_to_file(playgraph_path, new_state)

    {:reply, :ok, state}
  end

  defp adjust_edge_paths_for_export(state, assets_path) do
    Map.update!(state, "nodes", fn nodes ->
      Enum.map(nodes, fn node ->
        Map.update!(node, "edges", fn edges ->
          Enum.map(edges, fn edge ->
            # Store original path
            Map.put(edge, "original_path", edge["path"])
            |> Map.update!("path", fn _old_path ->
              # Replace the old path with the new one in the assets folder
              Path.join(assets_path, Path.basename(edge["path"]))
            end)
          end)
        end)
      end)
    end)
  end

  defp copy_assets_to_export_folder(state, assets_path) do
    Enum.each(get_edges_from_state(state), fn edge ->
      if Path.extname(edge["original_path"]) == ".webm" do
        disk_path =
          GenServer.call(
            Emulsion.Files,
            {:convert_browser_path_to_disk_path, edge["original_path"]}
          )

        IO.puts("copying #{disk_path} to #{Path.join(assets_path, Path.basename(disk_path))}")
        res = File.cp(disk_path, Path.join(assets_path, Path.basename(disk_path)))
        IO.inspect(res)
      end
    end)

    state
  end

  def handle_call({:save, filename}, _from, state) do
    # add .playgraph if the filename doesn't end in it already:
    filename =
      if String.ends_with?(filename, ".playgraph") do
        filename
      else
        filename <> ".playgraph"
      end

    # Save the state to file
    case save_to_file(filename, state) do
      :ok ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  defp save_to_file(filename, state) do
    # Convert the state to a JSON string
    json_string =
      state
      # Convert to JSON
      |> Jason.encode!()

    # Write the JSON string to a file
    File.write(filename, json_string)
  end

  def handle_call({:load, filename}, _from, state) do
    # Read the file
    filename =
      if String.ends_with?(filename, ".playgraph") do
        filename
      else
        filename <> ".playgraph"
      end

    case File.read(filename) do
      {:ok, json_string} ->
        # Decode the JSON string
        new_state =
          json_string
          # Decode the JSON
          |> Jason.decode!()

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
    edges = get_edges_from_state(state)
    {:reply, edges, state}
  end

  defp get_edges_from_state(state) do
    state["nodes"]
    |> Enum.map(& &1["edges"])
    |> List.flatten()
  end

  def handle_call({:add_node, frame_path}, _from, state) do
    # Check if the node already exists
    if Enum.any?(state["nodes"], fn node -> node["id"] == frame_path end) do
      {:reply, :ok, state}
    else
      node = %{
        "id" => frame_path,
        "label" => frame_path |> Path.basename(),
        "name" => frame_path,
        "edges" => []
      }

      {:reply, :ok, Map.put(state, "nodes", [node | state["nodes"]])}
    end
  end

  def handle_call(
        {:add_edge, src_node_name, destination_node_name, edge_id, path_to_video},
        _from,
        %{"nodes" => nodes} = state
      ) do
    case find_node(src_node_name, nodes) do
      {:ok, node} ->
        updated_edge = create_edge(src_node_name, destination_node_name, edge_id, path_to_video)

        updated_node = Map.put(node, "edges", [updated_edge | node["edges"]])

        nodes = replace_node_in_list(updated_node, nodes)

        {:reply, :ok, Map.put(state, "nodes", nodes)}

      {:error, :not_found} ->
        {:reply, {:error, "Source node not found"}, state}
    end
  end

  defp find_node(node_name, nodes) do
    case Enum.find(nodes, fn node -> node["name"] == node_name end) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  defp create_edge(src_node_name, destination_node_name, edge_id, path_to_video) do
    %{
      "from" => src_node_name,
      "to" => destination_node_name,
      "id" => edge_id,
      "destination" => destination_node_name,
      "fromPath" =>
        GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, src_node_name}),
      "toPath" =>
        GenServer.call(
          Emulsion.Files,
          {:convert_disk_path_to_browser_path, destination_node_name}
        ),
      "path" =>
        GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, path_to_video})
    }
  end

  defp replace_node_in_list(updated_node, nodes) do
    Enum.map(nodes, fn node ->
      if node["name"] == updated_node["name"], do: updated_node, else: node
    end)
  end

  # def handle_call(
  #       {:add_edge, src_node_name, destination_node_name, edge_id, path_to_video},
  #       _from,
  #       state
  #     ) do
  #   nodes =
  #     Enum.map(state["nodes"], fn node ->
  #       if node["name"] == src_node_name do
  #         IO.puts(":add_edge found from #{src_node_name} to #{destination_node_name}")

  #         edge = %{
  #           "from" => src_node_name,
  #           "to" => destination_node_name,
  #           "id" => edge_id,
  #           "destination" => destination_node_name,
  #           "fromPath" =>
  #             GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, src_node_name}),
  #           "toPath" =>
  #             GenServer.call(
  #               Emulsion.Files,
  #               {:convert_disk_path_to_browser_path, destination_node_name}
  #             ),
  #           "path" =>
  #             GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, path_to_video})
  #         }

  #         Map.put(node, "edges", [edge | node["edges"]])
  #       else
  #         IO.puts(":add_edge didn't find #{src_node_name} in #{node["name"]}")
  #         node
  #       end
  #     end)

  #   {:reply, :ok, Map.put(state, "nodes", nodes)}
  # end

  def handle_call({:delete_edge, node_name, edge_id}, _from, state) do
    nodes =
      Enum.map(state["nodes"], fn node ->
        if node["name"] == node_name do
          edges = Enum.filter(node["edges"], fn edge -> edge["id"] != edge_id end)

          Map.put(node, "edges", edges)
        else
          node
        end
      end)

    {:reply, :ok, Map.put(state, "nodes", nodes)}
  end

  def tag_edge(edge_id, tag) do
    GenServer.call(__MODULE__, {:tag_edge, edge_id, tag})
  end

  def handle_call({:tag_edge, edge_id, tag}, _from, state) do
    # Map over the nodes, and for each node, map over its edges.
    # If an edge's ID matches the provided edge_id, add the tag to its "tags" list.
    nodes =
      Enum.map(state["nodes"], fn node ->
        Map.update!(node, "edges", fn edges ->
          Enum.map(edges, fn edge ->
            if edge["id"] == edge_id do
              # If the edge already has a "tags" key, append to it; otherwise, create it.
              Map.update(edge, "tags", [tag], &[tag | &1])
            else
              edge
            end
          end)
        end)
      end)

    {:reply, :ok, Map.put(state, "nodes", nodes)}
  end

  def node_exists?(frame_path) do
    GenServer.call(__MODULE__, {:node_exists?, convert_if_needed(frame_path)})
  end

  def edge_exists?(src_node_name, destination_node_name) do
    GenServer.call(
      __MODULE__,
      {:edge_exists?, convert_if_needed(src_node_name), convert_if_needed(destination_node_name)}
    )
  end

  def handle_call({:node_exists?, frame_path}, _from, state) do
    node_exists = Enum.any?(state["nodes"], fn node -> node["id"] == frame_path end)
    {:reply, node_exists, state}
  end

  def handle_call({:edge_exists?, src_node_name, destination_node_name}, _from, state) do
    edge_exists =
      Enum.any?(state["nodes"], fn node ->
        node["id"] == src_node_name and
          Enum.any?(node["edges"], fn edge -> edge["to"] == destination_node_name end)
      end)

    {:reply, edge_exists, state}
  end

  defp convert_if_needed(path) do
    if String.starts_with?(path, "/file") do
      Emulsion.Files.convert_browser_path_to_disk_path(path)
    else
      path
    end
  end
end
