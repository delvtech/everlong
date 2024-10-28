.PHONY: build test

### Build ###

build:
	forge build --force

### Test ###

test:
	forge test

coverage:
	forge coverage --report lcov
