# Roadmap

- [ ] **Visual mode `<C-a>`/`<C-x>` and `g<C-a>`/`g<C-x>`** (dial.nvim,
  vim-speeddating): act on every target in the selection; `g` variants
  step progressively (1, 2, 3...). Native visual `<C-a>` already covers plain
  numbers. speeddating also fills blank lines from the line above to build
  sequences (`2000-10-30`, `2000-10-31`, `2000-11-01`).
- [ ] **Cycles longer than two** (dial.nvim `constant`, switch.vim lists):
  `foo -> bar -> baz -> foo`. `words`/`symbols` only take pairs today. Built-in
  candidates: weekdays (`Mon`...`Sun`, `Monday`...`Sunday`) and month names
  (`Jan`/`January`).
- [ ] **Per-filetype rules** (dial.nvim `on_filetype`, switch.vim
  `b:switch_custom_definitions`): e.g. `let`/`const` in TypeScript,
  `public`/`private`, `==`/`===` in JavaScript. The Markdown checkbox is the only
  filetype-specific rule today and it is hardcoded.
- [ ] **Semantic versions** (dial.nvim): `1.2.3`, the part under the cursor
  steps; bumping minor resets patch, bumping major resets both. Fits the existing
  date/time "part under cursor" model.
  - [ ] **Hex colors** (dial.nvim): `#1a1a1a` stepped per channel, keeping case.
- [ ] **Word-boundary option** (dial.nvim `word`, switch.vim `Words`): check
  first whether word matching already stops `sand` becoming `sor`.
- [ ] **Set a timestamp to now** (vim-speeddating `d<C-x>`, `d<C-a>` for UTC).
- [ ] **More date formats**: dotted `dd.mm.yyyy`, month names, RFC-style
  timestamps like `Sat, 01 Jan 2000 00:00:03 +0000` (dial.nvim,
  vim-speeddating).
- [ ] **Ordinals and roman numerals** (vim-speeddating): `1st -> 2nd`,
  `IV -> V`.
- [ ] **Octal `0o17`** (dial.nvim).

