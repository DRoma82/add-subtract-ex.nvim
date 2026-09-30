# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-09-30

### Added

- Dot-repeat: `.` repeats the last `<C-a>`/`<C-x>` on whatever is under the
  cursor (toggle, date, time, letter, or number), keeping its count.

### Fixed

- Numbers stepped inside a macro or mapping now change in order, instead of
  after the rest of the macro's keys ran.

## [0.2.0] - 2026-09-30

### Added

- Markdown checkbox toggling: `- [ ]` ↔ `- [x]` (also `[X]`, `*`/`+` bullets,
  and numbered lists) in `markdown` buffers.
- Date stepping for `yyyy-MM-dd`, `dd/MM/yyyy`, and `MM/dd/yyyy` (also `yy`):
  the part under the cursor moves, rolling over months and years. Configure it
  with the `dates` option.
- Time stepping for `HH:mm`, `HH:mm:ss`, and 12h `h:mm AM/PM`: the part under
  the cursor moves and carries like a clock, and `AM`/`PM` toggles. Configure
  it with the `times` option.
- Demo coverage for counts and Markdown checkboxes.

### Changed

- With dates enabled (the default), slash-separated number triples like
  `10/20/30` are read as dates. Set `dates = false` to restore the old behavior.

## [0.1.0] - 2026-08-14

### Added

- Extended `CTRL-A`/`CTRL-X` that toggles word pairs (`true`/`false`,
  `yes`/`no`, ...) with casing preserved.
- Symbol pair inversion (`&&`/`||`, `==`/`!=`, `<=`/`>=`, `++`/`--`, `+`/`-`).
- Letter shifting with counts, without wrapping.
- Deferral to native `CTRL-A`/`CTRL-X` for decimal, hex, and binary numbers.
- `sign_aware` option to treat a leading `+`/`-` as a number sign.
- CI, demo GIF, and install docs for lazy.nvim and `vim.pack`.

[Unreleased]: https://github.com/DRoma82/add-subtract-ex.nvim/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/DRoma82/add-subtract-ex.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/DRoma82/add-subtract-ex.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DRoma82/add-subtract-ex.nvim/releases/tag/v0.1.0
