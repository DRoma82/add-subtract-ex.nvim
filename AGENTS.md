# Agent instructions

## Demo

A change that adds or alters a user-visible feature also updates the demo in the same change:

- `assets/demo.txt`: one annotated line for the feature.
- `assets/demo.tape`: a step that exercises it, plus a taller `Set Height` when lines were added.
- `assets/demo.md`: the feature in the task list.

Recording conventions live in `assets/README.md`. The GIF itself is recorded by the user, so the final report ends with a reminder to regenerate it with `make demo` and check it visually.

## Changelog

A change a plugin user would notice (new feature, behavior change, bug fix, removed option) adds a bullet under `## [Unreleased]` in `CHANGELOG.md` in the same change, grouped under `Added`, `Changed`, `Fixed`, or `Removed`. Write the bullet for users: what they can now do or what behaves differently, including how to opt out when a default changes. Docs-, test-, CI-, and demo-only changes get no entry.

## Releases

After implementing a change that added a changelog entry, the final report suggests the next version number with the reason for the bump, and asks the user whether to release it now or keep collecting changes under `Unreleased`. The release itself runs only on the user's go-ahead. Versions are SemVer git tags (`vX.Y.Z`); plugin managers resolve versions from these tags, so the code holds no version string. While on `0.x`, a new feature or breaking change bumps the minor version and a fix-only release bumps the patch.

1. In `CHANGELOG.md`, rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a fresh empty `## [Unreleased]` above it, and update the compare links at the bottom (`Unreleased` compares from the new tag, the new version compares from the previous tag).
2. Commit the changelog, then create an annotated tag on that commit: `git tag -a vX.Y.Z -m vX.Y.Z`.
3. Push the commit and the tag.
4. Create a GitHub release for the tag titled `vX.Y.Z`, with that version's changelog section as the notes.
