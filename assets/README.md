# Demo assets

`demo.gif` is referenced from the top of the root `README.md` and is produced
by recording `demo.tape` with [vhs](https://github.com/charmbracelet/vhs).

Files:

- `demo.txt` — the scratch buffer, one feature per line, each annotated with the
  expected `<C-a>` / `<C-x>` result.
- `demo-init.lua` — a curated, isolated Neovim config: Catppuccin Mocha theme +
  the local plugin under development (loaded via `dir`), with legacy Lua syntax
  highlighting. It writes its plugins/state under `assets/.demo/` (gitignored),
  so it never touches your real `~/.local/share/nvim`.
- `demo-open.sh` — launches Neovim with `demo-init.lua` and the isolated dirs.
- `demo.tape` — the vhs script that drives the whole recording.

## Recording

From the repo root:

```sh
brew install vhs         # once; pulls ttyd + ffmpeg
make demo                # -> assets/demo.gif   (same as: vhs assets/demo.tape)
```

> First run is a **warm-up**: it clones Catppuccin into `assets/.demo/`, which
> can take longer than the tape's startup `Sleep`. Run `make demo` **twice** —
> discard the first GIF, keep the second (clean, fully-loaded) recording.

To try it by hand instead of recording:

```sh
./assets/demo-open.sh
# then move onto each target and press <C-a> / <C-x>; try a count like 3<C-a>
```

## Tweaking

- **Theme / font** live at the top of `demo.tape` (`Set Theme "catppuccin-mocha"`,
  `Set FontFamily "ComicCode Nerd Font"`). Change `Set FontSize` / `Width` /
  `Height` to taste.
- **Keystrokes** are search-driven (`/true` then `Ctrl+A`, ...). If you edit
  `demo.txt`, keep each code token before its comment mention so the first match
  lands on the code.

## Keep it small

Aim for < 5 MB so the README loads fast:

```sh
brew install gifsicle
gifsicle -O3 --lossy=60 assets/demo.gif -o assets/demo.gif
```
