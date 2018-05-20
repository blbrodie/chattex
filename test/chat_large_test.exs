defmodule ChatLargeTest do
  use ExUnit.Case

  # LargeTest tests the whole application.
  # See Mike Bland's post Small, Medium, Large
  # https://mike-bland.com/2011/11/01/small-medium-large.html

  test "tcp client can connect to the chat server" do
    assert {:ok, socket} = connect()
  end

  test "tcp client is prompted to enter name" do

  end

  defp connect() do
    :gen_tcp.connect('localhost', 8080, [:binary, packet: :line, active: false])
  end
end
