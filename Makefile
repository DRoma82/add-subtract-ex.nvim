.PHONY: test demo

# Run the headless Neovim test suite.
test:
	nvim --headless --clean -u NONE -l tests/run.lua

# Record the README demo GIF and shrink it (requires vhs and gifsicle:
# brew install vhs gifsicle).
demo:
	vhs assets/demo.tape
	gifsicle -O3 --lossy=60 assets/demo.gif -o assets/demo.gif
