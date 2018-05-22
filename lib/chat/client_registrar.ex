defmodule Chat.ClientRegistrar do
  require Logger
  use GenServer, restart: :temporary
  @crlf "\r\n"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Logger.debug("#{__MODULE__}: starting")

    {:ok, {%{},%{}}}
  end

  @spec register(GenServer.server(), port()) :: :ok
  def register(server, socket) do
    GenServer.cast(server, {:register, socket})
  end

  @spec clients(GenServer.server()) :: {:ok, [{String.t(), pid()}]}
  def clients(server), do: GenServer.call(server, :clients)

  @spec client_name(GenServer.server(), pid()) :: String.t()
  def client_name(server, pid), do: GenServer.call(server, {:client_name, pid})
    # [name] = Registry.keys(Chat.ClientRegistry, pid)
    # name

  def handle_call({:client_name, pid}, _from, {_, pids} = state) do
    %{^pid => name} = pids
    {:reply, name, state}
  end

  def handle_call(:clients, _from, {users,_} = state) do
    {:reply, users, state}
  end

  def handle_cast({:register, socket}, state) do
    case req_register(socket) do
      :ok -> {:noreply, state}
      {:error, :closed} -> {:noreply, state}
      err ->
        Logger.error("There was an error registering client: #{socket}, #{err}")
        {:noreply, state}
    end
  end

  defp req_register(socket) do
    :gen_tcp.send(socket,
      "Welcome to The Chat! Please enter your name." <> @crlf)
  end

  def handle_info({:tcp, socket, data}, {names, pids} = state) do
    [name|_] = String.split(data)

    case names do
      %{^name => _} ->
        :gen_tcp.send(socket,
          "The nickname #{name} already exists. " <>
          "Please choose a new nickname." <> @crlf)
        {:noreply, state}
      _ ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Chat.ClientServerSup, {Chat.ClientServer, {socket, []}})
        Process.monitor(pid)
        users = (for {other, _} <- names, other != name, do: other)
        :gen_tcp.send(socket,
          "You are connected with #{length(users)} other user(s): [#{user_string(users)}]" <> @crlf)
        :gen_tcp.controlling_process(socket, pid)
        Chat.ChatServer.broadcast_event(Chat.ChatServer,
          "*" <> name <> " has joined the chat*" <> @crlf)
        {:noreply, {Map.put(names, name, pid), Map.put(pids, pid, name)}}
    end
  end

  # this can happen between assigning control to the client server process
  # unless we use {accept, once}
  def handle_info({:tcp_closed, socket}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, pid, reason}, {names, pids} = state) do
    %{^pid => name} = pids

    Chat.ChatServer.broadcast_event(Chat.ChatServer,
      "*" <> name <> " has left the chat*" <> @crlf)
    {:noreply, {Map.delete(names, name), Map.delete(pids, pid)}}
  end

  defp user_string(users, str \\ "")
  defp user_string([user], str) do
    user_string([], str <> "#{user}")
  end
  defp user_string([], str) do
    str
  end
  defp user_string([h|t], str) do
    user_string(t, str <> h <> ", ")
  end

end
