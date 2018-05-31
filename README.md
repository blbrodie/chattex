# Example Chat Server in Elixir

This is an example chat server written in Elixir. It is not for
production, but is useful for exploring and learning about Elixir and
OTP.

The chat server utilizes `:gen_tcp`, which is the Erlang provided
module that gives us communication over TCP. Intimidating at first, my
hope is that this project can provide insight in using this module,
along with `GenServers`.

The chat server consists of 4 components:

### The Connection Dispatcher

The connection dispatcher awaits for new TCP connections, and when one
is avaialable, hands the new connection off to the client registrar.

### The Client Registrar

The client registrar handles the coordination of client server. The
register first asks the client for a name, and if valid, assigns that
process to a client server, while monitoring the client server process
for termination.

### The Client Server

A client server is a process that represents the TCP socket, and data
flowing to and from the client to the chat server.

### The Chat Server

The chat server coordinates the messages from a client to other
clients, and shared state. Notice that the client registrar and the
chat server could actually be combined into one process, but I chose
to separate them.


## To Test
`make test`

## To Run
`make run`

## To Connect
`make telnet`
