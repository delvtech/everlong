.PHONY: build test

### Build ###

build:
	forge build --force --sizes

### Test ###

test:
	forge test

coverage:
	forge coverage --report lcov
