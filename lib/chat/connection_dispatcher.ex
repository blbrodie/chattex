defmodule Chat.ConnDispatcher do
  use GenServer

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, [])
  end

  def init(port) do
    GenServer.cast(self(), :accept)
    :gen_tcp.listen(port,
      [:binary, packet: :line, active: true, reuseaddr: true])
  end

  def handle_cast(:accept, listenSocket) do
    {:ok, clientSocket} = :gen_tcp.accept(listenSocket)
    :ok = :gen_tcp.send(clientSocket,
      "Welcome to The Chat! Please enter your name\r\n")
    {:noreply, listenSocket}
  end

end
