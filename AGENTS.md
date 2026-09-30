# Agent instructions

## Demo

A change that adds or alters a user-visible feature also updates the demo in the same change:

- `assets/demo.txt`: one annotated line for the feature.
- `assets/demo.tape`: a step that exercises it, plus a taller `Set Height` when lines were added.
- `assets/demo.md`: the feature in the task list.

Recording conventions live in `assets/README.md`. The GIF itself is recorded by the user, so the final report ends with a reminder to regenerate it with `make demo` and check it visually.
