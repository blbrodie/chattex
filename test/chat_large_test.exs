defmodule ChatLargeTest do
  use ExUnit.Case

  # A large test the whole application.
  # See Mike Bland's post Small, Medium, Large
  # https://mike-bland.com/2011/11/01/small-medium-large.html

  setup do
    restart_app()
  end

  test "tcp client can connect to the chat server" do
    restart_app()
    assert {:ok, _socket} = connect()
  end

  test "tcp client is prompted to enter nickname" do
    {:ok, socket} = connect()
    assert {:ok, "Welcome to The Chat! Please enter your name\r\n"} =
      :gen_tcp.recv(socket, 0, 5000)
  end

  test "two tcp clients can connect and are prompted to enter nickname" do
    {:ok, cs1} = connect()
    {:ok, cs2} = connect()

    assert {:ok, "Welcome to The Chat! Please enter your name\r\n"} = recv(cs1)
    assert {:ok, "Welcome to The Chat! Please enter your name\r\n"} = recv(cs2)

  end

  defp recv(socket) do
      :gen_tcp.recv(socket, 0, 1000)
  end

  defp connect() do
    :gen_tcp.connect('localhost', 8080, [:binary, packet: :line, active: false])
  end

  defp restart_app() do
    Application.stop(:chat)
    :ok = Application.start(:chat)
  end
end
