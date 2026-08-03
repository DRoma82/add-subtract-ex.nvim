.PHONY: test

# Run the headless Neovim test suite.
test:
	nvim --headless --clean -u NONE -l tests/run.lua
