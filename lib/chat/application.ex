defmodule Chat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Chat.ChatServer, name: Chat.ChatServer},
      {DynamicSupervisor, strategy: :one_for_one, name: Chat.ClientServerSup},
      {Chat.ClientRegistrar, name: Chat.ClientRegistrar},
      {Chat.ConnDispatcher, 8080}
    ]

    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
