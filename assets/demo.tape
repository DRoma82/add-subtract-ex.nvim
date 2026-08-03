# vhs tape for the README demo.  Run from the repo root:  vhs assets/demo.tape
# Produces assets/demo.gif.  Requires: vhs (brew install vhs).

Output assets/demo.gif

Require nvim
Set Shell bash
Set FontSize 18
Set Width 1000
Set Height 660
Set Padding 24

# Open the isolated demo buffer without showing the launch command.
Hide
Type "./assets/demo-open.sh" Enter
Sleep 1.5s
Show
Sleep 800ms

# Each step: jump to the target with a search, then press <C-a>.
# true -> false
Type "/true" Enter Sleep 500ms
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

# and -> or (word/operator pair)
Type "/and" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# <= -> >=
Type "/<=" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# ++ -> --
Type "/++" Enter Sleep 500ms
Ctrl+A Sleep 900ms

# A -> B (letter shift)
Type "/A'" Enter Sleep 500ms
Ctrl+A Sleep 1s

# A count also works: 3<C-a> shifts three positions (B -> E here).
Type "3" Ctrl+A Sleep 1.5s
