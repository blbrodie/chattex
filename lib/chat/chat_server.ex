defmodule Chat.ChatServer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, []}
  end

  @spec recent_msgs(GenServer.server()) :: [String.t()]
  def recent_msgs(server) do
    GenServer.call(server, :recent_msgs)
  end

  @spec broadcast(GenServer.server(), pid(), String.t()) :: :ok
  def broadcast(server, from, msg) do
    name = Chat.ClientRegistrar.client_name(Chat.ClientRegistrar, from)
    GenServer.call(server, {:broadcast, {name, msg}})
  end

  @spec broadcast_event(GenServer.server(), String.t()) :: :ok
  def broadcast_event(server, event) do
    GenServer.cast(server, {:broadcast_event, event})
  end

  def handle_call({:broadcast, {name, msg}}, _from, state) do
    outgoing = construct_msg({name, msg})

    client_pids()
    |> Enum.each(&Chat.ClientServer.push(&1,outgoing))

    mentions(msg)
    |> Enum.map(&Chat.ClientRegistrar.client_pid(Chat.ClientRegistrar, &1))
    |> Enum.each(&Chat.ClientServer.push(&1,"\a\r\n"))

    {:reply, :ok, [outgoing | Enum.take(state, 9)]}
  end

  def handle_cast({:broadcast_event, event}, state) do
    client_pids()
    |> Enum.each(&Chat.ClientServer.push(&1, ts() <> event))

    {:noreply, [ts() <> event | Enum.take(state,9)]}
  end

  def handle_call(:recent_msgs, _from, state) do
    {:reply, state, state}
  end

  def mentions(msg) do
    List.flatten(Regex.scan(~r/@(\w+)/, msg, capture: :all_but_first))
  end

  defp client_pids() do
    Chat.ClientRegistrar.clients(Chat.ClientRegistrar)
    |> Enum.map(fn({_,pid}) -> pid end)
  end

  defp construct_msg({name, msg}) do
    ts() <> "<" <> name <> "> " <> msg
  end

  defp ts() do
    "[#{Time.truncate(Time.utc_now(), :second)}] "
  end

end
