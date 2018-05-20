defmodule Chat.ConnDispatcher do
  use GenServer

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, [])
  end

  def init(port) do
      :gen_tcp.listen(port,
        [:binary, packet: :line, active: true, reuseaddr: true])
  end
end
