# a genserver that watches for a specific file to be created and notifies subscribers
# when it's done and what it was
defmodule Emulsion.NotifyWhenCreated do
  use GenServer

  @interval 1000
  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init() do
    {:ok, %{watches: []}}
  end

  def handle_cast({:watch_file, file}, state) do
    schedule_polling(file)
    {:noreply, %{ watches: state.watches ++ [file] }}
  end

  def schedule_polling(file) do
    Process.send_after(self(), {:poll_file, file}, @interval)
  end

  defp poll_file(file) do
    if File.exists?(file) do
      notify_subscribers(file)
    else
      schedule_polling(file)
    end
  end

  defp notify_subscribers(file) do
    # Notify subscribers that the file has been created
    PubSub.broadcast("file_exists", file)
  end
end

# genserver that watches a directory every @interval seconds.
# and broadcasts when it's done changing
# used as a callback mechanism for the external calls to ffmpeg
defmodule Emulsion.NotifyWhenDone do
  use GenServer
  alias Phoenix.PubSub

  @interval 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{watches: []}, name: Keyword.get(opts, :name))
  end

  def init(state) do
    Process.send_after(self(), :check_directories, @interval)
    {:ok, state}
  end

  def handle_info(:check_directories, state) do
    new_watches = Enum.map(state.watches, fn watch ->
      if watch.last_modified == last_modified(watch.path) do
        Emulsion.PubSub.broadcast("topic_files", {watch.name, %{watch.name, watch.path, "Directory has stopped being modified"}})
        nil
      else
        Process.send_after(self(), :check_directories, @interval)
        watch
      end
    end)

    {:noreply, %{state | watches: Enum.reject(new_watches, &is_nil/1)}}
  end

  def watch(pid, name, path) do
    GenServer.cast(pid, {:watch, name, path})
  end

  def handle_cast({:watch, name, path}, state) do
    watch = %{
      name: name,
      path: path,
      last_modified: last_modified(path)
    }

    state = %{state | watches: [watch | state.watches]}
    {:noreply, state}
  end

  defp last_modified(path) do
    {:ok, info} = File.stat(path)
    info[:mtime]
  end
end
