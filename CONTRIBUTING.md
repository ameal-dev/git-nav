# Contributing

git-nav is a single Bash script (`bin/git-nav`) plus a sourced tutorial lib
(`lib/git-nav-tutorial.sh`). No build step, no dependencies to install for development.

## Before pushing

```bash
shellcheck --severity=warning bin/git-nav lib/git-nav-tutorial.sh
```

CI (`.github/workflows/ci.yml`) runs the same lint, then a set of functional tests against
throwaway repos in `/tmp`. Both run on every push and PR to `main`.

## Version

The version lives in exactly one place: `GIT_NAV_VERSION` near the top of `bin/git-nav`.
Bump it, then tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which drafts a GitHub Release
for you to review and publish — it does not update `Formula/git-nav.rb` automatically. See
that file's `test do` block for the version-string check CI runs against it.

## Adding a command

Follow the existing shape: a `cmd_<name>()` function in `bin/git-nav`, wired into the
`case` statement at the bottom of the file, documented in `cmd_help()`, and added to the
command tables in `README.md`. If it's something you'd reach for daily, add an alias to
`share/git-nav.aliases.sh` and to `cmd_help`'s SHELL ALIASES block — keep those two in sync.
