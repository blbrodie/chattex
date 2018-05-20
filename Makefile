.PHONY: test dialyzer

test:
	mix test $(test)

dialyzer:
	mix dialyzer
