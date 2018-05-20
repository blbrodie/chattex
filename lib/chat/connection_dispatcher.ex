defmodule Chat.ConnDispatcher do
  require Logger
  use GenServer

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, [])
  end

  def init(port) do
    GenServer.cast(self(), :accept)
    :gen_tcp.listen(port,
      [:binary, packet: :line, active: true, reuseaddr: true])
  end

  defp accept(listenSocket) do
    {:ok, clientSocket} = :gen_tcp.accept(listenSocket)
    register_client(clientSocket)
    accept(listenSocket)
  end

  defp register_client(socket) do
    Chat.ClientRegistrar.register(Chat.ClientRegistrar, socket)
    :gen_tcp.controlling_process(socket, Process.whereis(Chat.ClientRegistrar))
  end

  def handle_cast(:accept, listenSocket) do
    accept(listenSocket)
    {:noreply, listenSocket}
  end
end
