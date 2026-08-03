# Demo assets

`demo.gif` is referenced from the top of the root `README.md`.

## Recording a clean, reproducible demo

`demo.txt` is a scratch buffer that shows one feature per line. Each line has a
comment describing the expected `<C-a>` / `<C-x>` result, so the recording is
easy to script and reproduce.

### 1. Launch an isolated Neovim with only this plugin

From the repo root:

```sh
nvim -u NONE \
  --cmd "set rtp+=$PWD" \
  -c "lua require('add-subtract-ex').setup({})" \
  -c "set number nolist laststatus=0 signcolumn=no" \
  assets/demo.txt
```

Then move the cursor onto each target and press `<C-a>` (or `<C-x>`).
Try a count too, e.g. `3<C-a>` on the `count` or `grade` line.

### 2. Record the terminal

Use whichever you prefer:

- **asciinema + agg** (crisp, small):
  ```sh
  asciinema rec demo.cast          # record, then Ctrl-D to stop
  agg demo.cast demo.gif           # convert cast -> gif
  ```
- **vhs** (scripted, fully reproducible — recommended):
  see `demo.tape` below, then `vhs demo.tape` which writes `demo.gif` directly.
- **Screen recorder + gifski** (macOS): record an `.mov`, then
  `gifski --fps 15 --width 900 -o demo.gif input.mov`.

### 3. Keep it small

Aim for < 5 MB so it loads fast in the README:

- ~10-15 fps is plenty for keypress demos.
- Width ~800-1000 px.
- Trim dead air at the start/end.

Optimize if needed:

```sh
gifsicle -O3 --lossy=60 demo.gif -o demo.gif
```

## demo.tape (vhs)

If you have [vhs](https://github.com/charmbracelet/vhs), drop this in
`assets/demo.tape` and run `vhs assets/demo.tape`:

```
Output demo.gif
Set FontSize 18
Set Width 960
Set Height 640
Set Padding 20

Hide
Type "nvim -u NONE --cmd 'set rtp+=$PWD' -c \"lua require('add-subtract-ex').setup({})\" -c 'set number nolist laststatus=0 signcolumn=no' assets/demo.txt"
Enter
Sleep 1s
Show

# true -> false
Type "3G" Sleep 500ms
Type "f=w" Sleep 300ms
Type "\x01" Sleep 800ms

# number 41 -> 42
Type "7G" Sleep 500ms
Type "f4" Sleep 300ms
Type "\x01" Sleep 800ms

# symbol and -> or
Type "11G" Sleep 500ms
Type "fa" Sleep 300ms
Type "\x01" Sleep 800ms

# letter A -> B
Type "16G" Sleep 500ms
Type "fA" Sleep 300ms
Type "\x01" Sleep 1s
```

`\x01` is `<C-a>` (use `\x18` for `<C-x>`). Adjust line numbers if you edit
`demo.txt`.
