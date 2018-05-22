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

    :ok = :gen_tcp.close(cs)

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

  test "client broadcasts message to all other users" do
    alphaSocket = joins_chat("alpha")
    betaSocket = joins_chat("beta")
    gammaSocket = joins_chat("gamma")

    benSocket = joins_chat("ben")

    recv_all_messages(benSocket)


    recv_all_messages(alphaSocket)
    recv_all_messages(betaSocket)
    recv_all_messages(gammaSocket)

    send_to_chat(benSocket, "Hello!" <> @crlf)

    {:ok, line} = alphaSocket |> recv_from_chat()
    assert [_ts, "<ben>", "Hello!"] = String.split(line)
    {:ok, line} = betaSocket |> recv_from_chat()
    assert [_ts, "<ben>", "Hello!"] = String.split(line)
    {:ok, line} = gammaSocket |> recv_from_chat()
    assert [_ts, "<ben>", "Hello!"] = String.split(line)
    {:ok, line} = benSocket |> recv_from_chat()
    assert [_ts, "<ben>", "Hello!"] = String.split(line)
  end

  test "client broadcasts leaves and joins to all other users" do
    alphaSocket = joins_chat("alpha")

    benSocket = joins_chat("ben")

    {:ok, _} = recv_from_chat(benSocket)

    {:ok, line} = recv_from_chat(alphaSocket, 2)
    assert [_ts, "*alpha" ,"has" ,"joined", "the", "chat*"] = String.split(line)
    {:ok, line} = recv_from_chat(alphaSocket)
    assert [_ts, "*ben" ,"has" ,"joined", "the", "chat*"] = String.split(line)

    closes_chat(benSocket)

    {:ok, line} = recv_from_chat(alphaSocket)
    assert [_ts, "*ben" ,"has" ,"left", "the", "chat*"] = String.split(line)
  end

  test "client receives the most recent 10 messages in the chat" do
    alphaSocket = joins_chat("alpha")
    betaSocket = joins_chat("beta")

    recv_all_messages(alphaSocket)
    recv_all_messages(betaSocket)

    for i <- 1..4, do: send_to_chat(alphaSocket, "Hello #{i}" <> @crlf)
    for i <- 1..4, do: send_to_chat(betaSocket, "Hello #{i}" <> @crlf)

    benSocket = joins_chat("ben")
    recv_from_chat(benSocket) #welcome message

    [_|msgs] = recv_all_messages(benSocket) #ignore my join message

    assert length(msgs) === 10

    assert [_ts, "<beta>" , "Hello", "4"] = String.split(List.last(msgs))
    assert [_ts, "*alpha" ,"has" ,"joined", "the", "chat*"] =
      String.split(([h|_] = msgs; h))
  end

  test "@ben should send a BEL to ben" do
    alphaSocket = joins_chat("alpha")
    betaSocket = joins_chat("beta")
    benSocket = joins_chat("ben")

    recv_all_messages(alphaSocket)
    recv_all_messages(betaSocket)
    recv_all_messages(benSocket)

    send_to_chat(alphaSocket, "Hello @ben! Hello @beta." <> @crlf)

    ["\a" <> @crlf, _] = recv_all_messages(benSocket)
    ["\a" <> @crlf, _] = recv_all_messages(betaSocket)
    [_] = recv_all_messages(alphaSocket)
  end

  defp recv_all_messages(socket, msgs \\ []) do
    case recv_from_chat(socket) do
      {:ok, msg} -> recv_all_messages(socket, [msg | msgs])
      {:error, :timeout} -> msgs
    end
  end

  defp closes_chat(socket) do
    :ok = :gen_tcp.close(socket)
  end

  defp joins_chat(name) do
    {:ok, cs} = connect()
    {:ok, @welcome_msg} = recv_from_chat(cs)
    :ok = send_to_chat(cs, name <> @crlf)
    cs
  end

  defp recv_from_chat(socket, numLines \\ 1)
  defp recv_from_chat(socket, 1) do
    :gen_tcp.recv(socket, 0, 100)
  end
  defp recv_from_chat(socket, numLines) do
    recv_from_chat(socket)
    recv_from_chat(socket, numLines - 1)
  end


  defp send_to_chat(socket, text) do
    :gen_tcp.send(socket, text)
  end

  defp connect() do
    :gen_tcp.connect('localhost', 8080, [:binary, packet: :line, active: false])
  end

  defp restart_app() do
    Application.stop(:chat)
    :ok = Application.start(:chat)
  end
end
