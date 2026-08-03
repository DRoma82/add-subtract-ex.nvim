#!/usr/bin/env bash
# Launch an isolated Neovim with only add-subtract-ex loaded, for demo recording.
set -euo pipefail
cd "$(dirname "$0")/.."
exec nvim -u NONE \
	--cmd "set rtp+=$PWD" \
	-c "lua require('add-subtract-ex').setup({})" \
	-c "set number nolist nohlsearch laststatus=0 signcolumn=no" \
	assets/demo.txt
