#!/usr/bin/env bash
# Launch Neovim with the curated demo config (Catppuccin + statuscol + lualine +
# showkeys + the local add-subtract-ex), isolated from your real Neovim data.
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the demo hermetic: its plugins/parsers live under assets/.demo, not your
# real ~/.local/share/nvim. (assets/.demo is gitignored.)
demo_home="$PWD/assets/.demo"
export XDG_DATA_HOME="$demo_home/data"
export XDG_STATE_HOME="$demo_home/state"
export XDG_CACHE_HOME="$demo_home/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

exec nvim -u assets/demo-init.lua assets/demo.txt
