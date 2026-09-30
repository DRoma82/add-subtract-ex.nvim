# vhs tape for the README demo.  Run from the repo root:  vhs assets/demo.tape
# Produces assets/demo.gif.  Requires: vhs (brew install vhs).

Output assets/demo.gif

Require nvim
Set Shell bash
Set Theme "catppuccin-mocha"
Set FontFamily "ComicCode Nerd Font"
Set FontSize 18
Set Width 1000
Set Height 720
Set Padding 24

# Open the isolated demo buffer without showing the launch command.
Hide
Type "./assets/demo-open.sh" Enter
Sleep 2.5s
Show
Sleep 800ms

# Each step: jump to the target with a search, then press <C-a>.
# true -> false
Type "/true" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# left -> right
Type "/left" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# YES -> NO (casing preserved)
Type "/YES" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# 41 -> 42 (native number)
Type "/41" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# 0xFE -> 0xFF (hex literal, native)
Type "/0xFE" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# 0b0010 -> 0b0011 (binary literal, native)
Type "/0b0010" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# and -> or (word/operator pair)
Type "/and" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# <= -> >=
Type "/<=" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# ++ -> --
Type "/++" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# A -> D (letter shift with a count)
Type "/A'" Enter Sleep 500ms
Type "3" Ctrl+A Sleep 900ms

# 2024-01-31 -> 2024-02-01 (day rolls the month)
Type `/31"` Enter Sleep 500ms
Ctrl+A Sleep 900ms

# The part under the cursor steps: month (02 -> 03), then year (2024 -> 2025).
Type "hh" Sleep 400ms
Ctrl+A Sleep 900ms
Type `F"l` Sleep 400ms
Ctrl+A Sleep 900ms

# 11:59 PM -> 12:00 AM (minute carries the hour and meridiem)
Type "/59 " Enter Sleep 500ms
Ctrl+A Sleep 900ms

# AM -> PM (toggle with the cursor on it)
Type "fA" Sleep 400ms
Ctrl+A Sleep 1s

# Markdown checkboxes only toggle in markdown buffers, so switch files off-camera.
Hide
Type ":e assets/demo.md" Enter
Sleep 500ms
Show
Sleep 800ms

# Tick the last feature: [ ] -> [x]
Type "G" Sleep 500ms
Ctrl+A Sleep 1.5s

