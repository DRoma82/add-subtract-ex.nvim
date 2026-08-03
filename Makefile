.PHONY: test demo

# Run the headless Neovim test suite.
test:
	nvim --headless --clean -u NONE -l tests/run.lua

# Record the README demo GIF (requires vhs: brew install vhs).
demo:
	vhs assets/demo.tape
