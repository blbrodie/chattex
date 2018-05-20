defmodule ChatLargeTest do
  use ExUnit.Case
  @moduletag :capture_log

  @welcome_msg "Welcome to The Chat! Please enter your name.\r\n"
  @connected_with "You are connected with"
  @crlf "\r\n"

  # A large test tests the whole application.
  # See Mike Bland's post Small, Medium, Large
  # https://mike-bland.com/2011/11/01/small-medium-large.html

  setup do
    restart_app()
  end

  test "client can connect to the chat server" do
    assert {:ok, _socket} = connect()
  end

  test "client is prompted to enter nickname" do
    {:ok, socket} = connect()
    assert {:ok, @welcome_msg} = recv_from_chat(socket)
  end

  test "two clients can connect and are prompted to enter nickname" do
    {:ok, cs1} = connect()
    {:ok, cs2} = connect()

    assert {:ok, @welcome_msg} = recv_from_chat(cs1)
    assert {:ok, @welcome_msg} = recv_from_chat(cs2)

  end

  test "client can respond with nickname and receive connected msg" do
    {:ok, cs} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs)
    :ok = send_to_chat(cs, "ben_brodie" <> @crlf)
    assert {:ok, @connected_with <> " 0 other user(s): []" <> @crlf} =
      recv_from_chat(cs)
  end

  test "client can not register with existing nickname" do
    {:ok, cs1} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs1)
    :ok = send_to_chat(cs1, "ben_brodie" <> @crlf)
    {:ok, @connected_with <> " 0 other user(s): []" <> @crlf} =
      recv_from_chat(cs1)

    {:ok, cs2} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs2)
    :ok = send_to_chat(cs2, "ben_brodie" <> @crlf)

    assert {:ok, "The nickname ben_brodie already exists. " <>
                 "Please choose a new nickname." <> @crlf} =
      recv_from_chat(cs2)
  end

  test "client can register if it has left and reconnected" do
    {:ok, cs} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs)
    :ok = send_to_chat(cs, "ben_brodie" <> @crlf)
    {:ok, @connected_with <> " 0 other user(s): []" <> @crlf} =
      recv_from_chat(cs)

    :ok = :gen_tcp.shutdown(cs, :write)

    {:ok, cs} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs)
    :ok = send_to_chat(cs, "ben_brodie" <> @crlf)

    assert {:ok, @connected_with <> " 0 other user(s): []" <> @crlf} =
      recv_from_chat(cs)
  end

  test "client receives a list of other users" do
    joins_chat("alpha")
    joins_chat("beta")
    joins_chat("gamma")

    assert {:ok, @connected_with <>
      " 3 other user(s): [alpha, beta, gamma]" <> @crlf} =
      joins_chat("ben_brodie") |> recv_from_chat()
  end

  defp joins_chat(name) do
    {:ok, cs} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs)
    :ok = send_to_chat(cs, name <> @crlf)
    cs
  end

  defp send_to_chat(socket, text) do
    :gen_tcp.send(socket, text)
  end

  defp recv_from_chat(socket) do
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
