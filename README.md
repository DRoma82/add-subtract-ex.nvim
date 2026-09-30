# add-subtract-ex.nvim

[![CI](https://github.com/DRoma82/add-subtract-ex.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/DRoma82/add-subtract-ex.nvim/actions/workflows/ci.yml)

An extended `CTRL-A` / `CTRL-X` for Neovim.

![demo](assets/demo.gif)

Native `CTRL-A` (`:help CTRL-A`) adds to the number at or after the cursor.
This plugin keeps that behavior (see the signed-number note below) and extends
the *same* keys to also:

- **Toggle word pairs** — `true`/`false`, `yes`/`no`, `on`/`off`, ... with casing preserved (`TRUE` → `FALSE`, `True` → `False`).
- **Invert symbol pairs** — `&&`/`||`, `==`/`!=`, `<=`/`>=`, `++`/`--`, `+`/`-`.
- **Toggle Markdown checkboxes** — `- [ ]` ↔ `- [x]` (also `[X]`, `*`/`+` bullets, and `1.` lists) in `markdown` buffers, when the cursor is on or before the checkbox.
- **Shift letters** — `a` → `b`, `Z` stays `Z` (no wrapping), with a `count` (`3<C-a>`).
- **Step dates** — `yyyy-MM-dd` and `dd/MM/yyyy` (or `MM/dd/yyyy`, also with `yy`): the day, month, or year under the cursor moves, rolling over months and years (`2024-01-31` → `2024-02-01`).
- **Step times** — `HH:mm`, `HH:mm:ss`, and 12h `h:mm PM`: the part under the cursor moves and carries like a clock (`23:59` → `00:00`, `11:59 PM` → `12:00 AM`); `AM`/`PM` toggles.
- **Repeat with `.`** — every action repeats on the target under the cursor, numbers included, with the same count.
- **Defer to native numbers** — decimal, hex (`0xFF`), and binary (`0b1010`) literals are handled by native `CTRL-A`/`CTRL-X`.

The **earliest target at or after the cursor wins**, mirroring how native
`CTRL-A` targets the nearest number instead of always preferring one kind.

> ⚠️ **Signed numbers:** because `+`/`-` is a built-in symbol pair, by default a
> leading sign is toggled instead of incrementing the number. This applies to
> signed decimal, hex, and binary literals: `-5` → `+5`, `-0xFF` → `+0xFF`,
> `-0b1010` → `+0b1010` (native would give `-4`, `-0x100`, `-0b1011`). Set
> `sign_aware = true` to treat a `+`/`-` immediately before a digit as a number
> sign and defer to native (`-5` → `-4`, `-0xFF` → `-0x100`), while a standalone
> `+`/`-` still toggles.

## Install

### lazy.nvim

```lua
{
  "DRoma82/add-subtract-ex.nvim",
  -- opts = {} triggers setup() with defaults (maps <C-a>/<C-x>)
  opts = {},
}
```

### vim.pack (Neovim 0.12+)

Neovim's built-in manager doesn't run `setup()` for you, so call it after adding
the plugin:

```lua
vim.pack.add({
  { src = "https://github.com/DRoma82/add-subtract-ex.nvim" },
})

require("add-subtract-ex").setup() -- maps <C-a>/<C-x>
```

### packer.nvim

```lua
use({
  "DRoma82/add-subtract-ex.nvim",
  config = function()
    require("add-subtract-ex").setup()
  end,
})
```

## Configuration

Defaults:

```lua
require("add-subtract-ex").setup({
  -- Keys to map in normal mode.
  --   nil (omit)  -> map <C-a> / <C-x>
  --   false       -> map nothing, leave <C-a>/<C-x> native
  --   table       -> map exactly these; omitted directions stay native
  keys = { increment = "<C-a>", decrement = "<C-x>" },

  -- Enable alphabetical letter shifting (a -> b).
  letters = true,

  -- Treat a +/- directly before a digit as a number sign: defer to native
  -- so signed numbers increment (-5 -> -4) instead of flipping (-5 -> +5).
  sign_aware = false,

  -- Date stepping. Set to false to disable.
  dates = {
    format = "dmy",        -- slash dates: "dmy" (dd/MM/yyyy) or "mdy" (MM/dd/yyyy)
    pad = false,           -- always write day/month with 2 digits
    default_part = "day",  -- part to step when the cursor is before the date
    century_pivot = 69,    -- yy below this is 20yy, otherwise 19yy (POSIX)
  },

  -- Time stepping. Set to false to disable.
  times = {
    default_part = "hour", -- part to step when the cursor is before the time
    two_part = "hm",       -- read a two-part time as "hm" (HH:mm) or "ms" (mm:ss)
  },

  -- Include the shipped word/symbol dictionaries.
  builtins = true,

  -- Extra pairs. Each { a, b } toggles both ways. A pair whose first element
  -- matches a built-in (e.g. { "true", "apple" }) overrides that built-in.
  words = {},
  symbols = {},
})
```

### Dates

Dates are recognised as `yyyy-M-d` (ISO) and, for slash dates, `d/M/yyyy` or
`d/M/yy` (`M/d/...` with `format = "mdy"`). Day and month may be 1 or 2 digits;
the written padding is kept unless `pad = true`.

- The part under the cursor steps. A separator belongs to the part before it;
  a cursor before the date steps `default_part`.
- Days roll over months and years (`31/12/2024` → `01/01/2025`). Stepping the
  month or year clamps the day to the month's end (`2024-01-31` → `2024-02-29`).
- `yyyy` stops at `0000`/`9999`; `yy` stops at the edges of its pivot window
  (1969–2068 by default).
- Date-shaped text that isn't a real date (`31/02/2024`) is left alone with a
  warning.

> ⚠️ With dates on (the default), slash-separated number triples like `10/20/30`
> are read as dates, so `<C-a>` warns instead of incrementing a number. Set
> `dates = false` to get the old behavior back.

### Times

Times are recognised as `HH:mm` and `HH:mm:ss`, plus 12h `h:mm[:ss] AM` (the
space is optional, `am`/`pm` casing is kept). A 24h hour needs 2 digits, so
ratios and verse references like `3:16` stay numbers.

- The part under the cursor steps; a separator (including the space before
  `AM`/`PM`) belongs to the part before it, and a cursor before the time steps
  `default_part`. On `AM`/`PM` the key toggles it.
- Parts carry and wrap like a clock: `10:59` → `11:00`, `23:59` → `00:00`,
  `11:59 PM` → `12:00 AM`. A time after a date never changes the date.
- A two-part time is ambiguous (`05:30` could be HH:mm or mm:ss). It reads as
  HH:mm unless `two_part = "ms"`, where minutes wrap within `00`–`59`. Times
  with seconds or `AM`/`PM` are always clock times.
- Invalid times (`25:00`, `13:00 PM`) are left alone with a warning.

### Custom keys (leaving `<C-a>`/`<C-x>` native)

```lua
require("add-subtract-ex").setup({
  keys = { increment = "<leader>a", decrement = "<leader>x" },
})
```

### Extending and overriding dictionaries

```lua
require("add-subtract-ex").setup({
  words = {
    { "foo", "bar" },      -- new pair
    { "true", "apple" },   -- overrides the built-in true/false
  },
  symbols = {
    { "<", ">" },
  },
})
```

### Disabling built-ins

```lua
require("add-subtract-ex").setup({
  builtins = false,
  words = { { "true", "false" } },
})
```

## API

Without keymaps you can call the functions directly:

```lua
local ase = require("add-subtract-ex")
ase.increment() -- like <C-a>
ase.decrement() -- like <C-x>
```

A count applies to numbers, letter shifts, dates, and times (e.g. `5<C-a>` adds 5, shifts a
letter 5 positions, or moves a date or time part by 5). Word and symbol pairs are single toggles and ignore the count.

Dot-repeat (`.`) works through the keys that `setup()` maps; direct calls to
`increment()`/`decrement()` are not repeatable.

## Tests

A dependency-free headless Neovim suite lives in `tests/run.lua`:

```sh
make test
# or
nvim --headless --clean -u NONE -l tests/run.lua
```

It exits non-zero on failure, so it drops straight into CI.

## Acknowledgements

This started life as a standalone Lua script in my personal Neovim config.
[nvim-toggler](https://github.com/nguyenvukhang/nvim-toggler) by
[@nguyenvukhang](https://github.com/nguyenvukhang) is what inspired me to turn
that config into a proper plugin — thanks for the nudge! Go check it out if you
want a focused, configurable word-inversion plugin.

## Similar plugins

- [nvim-toggler](https://github.com/nguyenvukhang/nvim-toggler)
- [dial.nvim](https://github.com/monaqa/dial.nvim)
- [vim-speeddating](https://github.com/tpope/vim-speeddating)
- [switch.vim](https://github.com/AndrewRadev/switch.vim)

## Contributors

[![Contributors](https://contrib.rocks/image?repo=DRoma82/add-subtract-ex.nvim)](https://github.com/DRoma82/add-subtract-ex.nvim/graphs/contributors)

## License

MIT
