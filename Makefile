.PHONY: test dialyzer

test:
	mix test $(test)

dialyzer:
	mix dialyzer

run:
	mix run --no-halt

telnet:
	telnet localhost 8080
