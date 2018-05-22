defmodule Chat.ClientRegistrar do
  require Logger
  use GenServer, restart: :temporary
  @crlf "\r\n"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
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

  @spec client_pid(GenServer.server(), String.t()) :: pid()
  def client_pid(server, name), do: GenServer.call(server, {:client_pid, name})

  def handle_call({:client_name, pid}, _from, {_, pids} = state) do
    %{^pid => name} = pids
    {:reply, name, state}
  end

  def handle_call({:client_pid, name}, _from, {names, _} = state) do
    %{^name => pid} = names
    {:reply, pid, state}
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
    request_name(socket)
  end

  def handle_info({:tcp, socket, data}, {names, pids} = state) do
    [name|_] = String.split(data)

    case names do
      %{^name => _} -> request_new_name(socket, name)
        {:noreply, state}
      _ ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Chat.ClientServerSup, {Chat.ClientServer, {socket, []}})
        send_welcome_msg(name, names, socket)
        send_most_recent_msgs(socket)
        hand_over_control(socket, pid)
        broadcast_join(name)
        {:noreply, {Map.put(names, name, pid), Map.put(pids, pid, name)}}
    end
  end

  # this can happen between assigning control to the client server process
  # unless we use {accept, once}
  def handle_info({:tcp_closed, _socket}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, pid, _reason}, {names, pids}) do
    %{^pid => name} = pids

    Chat.ChatServer.broadcast_event(Chat.ChatServer,
      "*" <> name <> " has left the chat*" <> @crlf)
    {:noreply, {Map.delete(names, name), Map.delete(pids, pid)}}
  end

  defp request_name(socket) do
    :gen_tcp.send(socket,
      "Welcome to The Chat! Please enter your name." <> @crlf)
  end

  defp request_new_name(socket, name) do
    :gen_tcp.send(socket,
      "The nickname #{name} already exists. " <>
        "Please choose a new nickname." <> @crlf)
  end

  defp broadcast_join(name) do
    Chat.ChatServer.broadcast_event(Chat.ChatServer,
      "*" <> name <> " has joined the chat*" <> @crlf)
  end

  defp hand_over_control(socket, pid) do
    Process.monitor(pid)
    :gen_tcp.controlling_process(socket, pid)
  end

  defp send_most_recent_msgs(socket) do
    Chat.ChatServer.recent_msgs(Chat.ChatServer)
    |> (fn(msg) -> :gen_tcp.send(socket,msg) end).()
  end

  defp send_welcome_msg(name, names, socket) do
    users = (for {other, _} <- names, other != name, do: other)
    :gen_tcp.send(socket,
      "You are connected with #{length(users)} other user(s): [#{user_string(users)}]" <> @crlf)
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
