defmodule Chat.ChatServer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, []}
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
    client_pids()
    |> Enum.each(&Chat.ClientServer.push(&1,construct_msg({name, msg})))

    {:reply, :ok, state}
  end

  def handle_cast({:broadcast_event, event}, state) do
    client_pids()
    |> Enum.each(&Chat.ClientServer.push(&1, ts() <> event))

    {:noreply, state}
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
