defmodule Chat.ClientServer do
  require Logger
  use GenServer, restart: :temporary

  def start_link({socket, opts}) do
    GenServer.start_link(__MODULE__, socket, opts)
  end

  def init(socket) do
    Logger.debug("#{__MODULE__} started. pid: #{inspect self()}, socket: #{inspect socket}")
    {:ok, socket}
  end

  @spec push(GenServer.server(), String.t()) :: :ok
  def push(server, packet) do
    GenServer.cast(server, {:push, packet})
  end

  def handle_cast({:push, packet}, socket) do
    case :gen_tcp.send(socket, packet) do
      :ok -> {:noreply, socket}
      {:error, :closed} -> {:stop, :normal, socket}
    end
  end


  def handle_info({:tcp_closed, _socket}, socket) do
    {:stop, :normal, socket}
  end

  def handle_info({:tcp, _socket, msg}, socket) do
    :ok = Chat.ChatServer.broadcast(Chat.ChatServer, self(), msg)
    {:noreply, socket}
  end



end
