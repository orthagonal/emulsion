

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

  def export_playgraph(playgraph, templates) do
    GenServer.call(__MODULE__, {:export_playgraph, playgraph, templates})
  end

  def handle_call(:get_directory, _from, state) do
    {:reply, state.directory, state}
  end

  def handle_call({:set_directory, directory}, _from, state) do
    {:reply, :ok, Map.put(state, :directory, directory)}
  end

  def handle_call({:export_playgraph, playgraph, templates},  from, state) do
    handle_call({:export_playgraph, playgraph, templates, ["lib/game_code_templates/cursor.playgraph"]}, from, state)
  end

  def handle_call({:export_playgraph, playgraph, templates, additional_playgraphs}, _from, state) do
    File.mkdir_p!("#{state.directory}/main")

    normalized_playgraphs = %{
      "main" => normalize_playgraph_paths(playgraph, "#{state.directory}/main")
    }

    # Process additional playgraphs
    normalized_playgraphs = for playgraph_path <- additional_playgraphs do
      playgraph_name = Path.basename(playgraph_path, ".playgraph")
      raw_additional_playgraph = File.read!(playgraph_path)
      additional_playgraph = Jason.decode!(raw_additional_playgraph)
      normalized_playgraphs = Map.put(normalized_playgraphs, playgraph_name, normalize_playgraph_paths(additional_playgraph, "#{state.directory}/#{playgraph_name}"))
      File.mkdir_p!("#{state.directory}/#{playgraph_name}")
      normalized_playgraphs
    end

    string_playgraphs = Jason.encode!(normalized_playgraphs)

    # additional templates (optional)
    if Map.has_key?(templates, :playgraph_template) do
      playgraph_template = templates.playgraph_template
      playgraph_content = do_export_template(playgraph_template, %{playgraph: string_playgraphs, playgraph_name: "one"})
      playgraph_path = Path.join([state.directory, "playgraph.js"])
      File.write!(playgraph_path, playgraph_content)
    end

    File.write!("#{state.directory}/playgraph.playgraph", string_playgraphs)

    {:reply, normalized_playgraphs, state}
  end

  defp convert_if_needed(path) do
    if String.starts_with?(path, "/file") do
      Emulsion.Files.convert_browser_path_to_disk_path(path)
    else
      path
    end
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

  def export_template(template_name, context) do
    GenServer.call(__MODULE__, {:export_template, template_name, context})
  end

  defp do_export_template(template_name, context) do
    template_path = Path.join(["lib/game_code_templates", "#{template_name}.eex"])
    template = File.read!(template_path)
    bindings = Enum.map(context, fn {k, v} -> {k, v} end) # Convert context map to keyword list
    EEx.eval_file(template_path, bindings)
  end

  def handle_call({:export_template, template_name, context}, _from, state) do
    content = do_export_template(template_name, context)
    {:reply, content, state}
  end

  def export_player(title, playgraph, templates) do
    GenServer.call(__MODULE__, {:export_player, title, playgraph, templates})
  end

  def handle_call({:export_player, title, playgraph, templates}, _from, state) do
    # mandatory templates
    html_template = templates.html_template
    js_template = templates.js_template
    # Render JS template
    js_content = do_export_template(js_template, %{playgraph: playgraph})
    # Render HTML template
    html_path_template = Path.join(["./lib/game_code_templates", "#{html_template}.eex"])
    bindings = Enum.map(%{script_template: js_content, game_title: title}, fn {k, v} -> {k, v} end) # Convert context map to keyword list
    html_content = EEx.eval_file(html_path_template, bindings)

     # Write HTML content to a file
    html_path = Path.join([state.directory, "player.html"])
    File.mkdir_p!(Path.dirname(html_path))
    File.write!(html_path, html_content)
    # write src.js to file
    js_path = Path.join([state.directory, "src.js"])
    File.write!(js_path, js_content)

    {:reply, :ok, state}
  end

  # This is now a regular public function that calls the GenServer functions for exporting
  def export_all(title, playgraph, templates, assets_path) do
    # Set the directory
    set_directory(assets_path)

    # Export the playgraph
    export_playgraph(playgraph, templates)

    # Export the player
    export_player(title, playgraph, templates)

    # Export any other assets
    export_other_assets(assets_path)
  end

  defp export_other_assets(assets_path) do
    # Here you can copy other required assets like images, stylesheets, etc.
    # You might want to structure your code to handle different types of assets separately.
  end
end
