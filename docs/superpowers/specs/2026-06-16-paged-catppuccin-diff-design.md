# Paged Catppuccin Diff for `git-nav diff`

**Date:** 2026-06-16
**Status:** Approved

## Problem

`git diff` produces a single long vertical scroll with no syntax highlighting,
making it hard to relate a hunk back to the file it lives in. The current
`cmd_diff` is a thin wrapper (`git diff <branch>`) with the same limitations.

The user wants a diff viewer that:

1. Renders code with real per-language syntax highlighting in the **Catppuccin**
   palette, matching their editor (LazyVim / Catppuccin) so the shape of the
   code in the diff matches the shape in their files.
2. Paginates **one file per page**, with forward/backward navigation, instead of
   one long scroll.

## Decisions

- **Render engine: `git-delta`.** Best-in-class diff renderer with real
  syntax highlighting and line numbers. Catppuccin themes are already present in
  the user's `bat` theme assets, which `delta` reuses, so `--syntax-theme
  "Catppuccin Macchiato"` works with zero extra setup. Added as a Homebrew
  dependency.
- **Navigation: full-screen sequential pager via `less` multi-file mode.** Each
  file's rendered diff is written to a temp file; all temp files are handed to a
  single `less -R` invocation. `less` provides scroll-within-file plus its
  built-in `:n` (next file) / `:p` (previous file) / `q` (quit) — one page =
  one file, forward and back.
- **Keys: `less` built-in `:n`/`:p`/`q`.** Bare `n`/`p` rebinding requires
  `--lesskey-src` (less 598+); the user's `less` is 581.2, so bare-key binding
  is not portable. Built-in `:n`/`:p` work everywhere. Footer advertises the
  active keys. (Progressive enhancement — bind bare `n`/`p` — only if a lesskey
  compiler is detected; not required for v1.)
- **Replaces `diff`/`d`.** The enhanced viewer becomes the default. `--plain`
  is an escape hatch to the old raw `git diff`.
- **Default flavor: Catppuccin Macchiato** (matches the user's alacritty theme),
  overridable via `GIT_NAV_DIFF_THEME`.
- **Layout: unified by default**, `--side` opts into side-by-side.

## Command Surface

```
git-nav diff              # working tree vs HEAD, paged
git-nav diff <query>      # vs fuzzy-picked branch (existing pick_branch)
git-nav diff --staged     # staged changes, paged
git-nav diff --side       # side-by-side layout
git-nav diff --plain      # bypass delta/less -> raw `git diff`
```

- `d` remains an alias for `diff`.
- Unrecognized `--flags` (e.g. `--stat`) pass through to the underlying
  `git diff` used for file enumeration and rendering.

## Pipeline (per invocation)

1. `ensure_git_repo`.
2. Parse args: separate the optional branch `query` from flags
   (`--staged`, `--side`, `--plain`, pass-through `--*`).
3. If `--plain`: run plain `git diff <target> <passthrough>` and return.
4. Resolve the diff target:
   - no query, no `--staged` -> `HEAD` (all working-tree changes)
   - `--staged` -> `--staged`
   - query -> `pick_branch "$query"` (existing fuzzy picker)
5. Verify `delta` is available; if not, print install guidance and exit
   non-zero (see Error Handling).
6. Enumerate changed files: `git diff --name-only <target>`. If empty, print a
   dim "No changes" and exit 0.
7. Create a temp dir (`mktemp -d`); register a `trap` to remove it on EXIT.
8. For each file in order, render
   `git diff <target> -- <file>` piped through `delta` into a numbered temp file
   (e.g. `01-src_auth.ts`) so `less` shows them in a stable order.
9. Invoke a single `less -R` over the ordered temp files with a custom `-P`
   footer prompt.

## delta Invocation

```
delta --syntax-theme "${GIT_NAV_DIFF_THEME:-Catppuccin Macchiato}" \
      --line-numbers \
      --paging=never \
      [--side-by-side]      # only when --side
```

- `--paging=never` because `less` owns paging.
- The theme env var lets the user switch flavor without code changes.

## less Footer

Custom prompt via `-P`, using less's built-in file counters `%i` (current) and
`%m` (total):

```
 <file>   file %i/%m   [:n]ext  [:p]rev  [q]uit  (scroll up/down)
```

## Error Handling

- **`delta` not installed:** print
  `delta not found - install with: brew install git-delta` and note that
  `git-nav diff --plain` works without it. Exit non-zero.
- **`--plain`:** skips delta, temp files, and `less`; runs `git diff` directly
  so it always works.
- **Not a git repo:** handled by existing `ensure_git_repo`.
- **No changes:** dim "No changes" message, exit 0.
- **Temp cleanup:** `trap '... rm -rf "$tmpdir"' EXIT` guarantees cleanup even on
  interrupt.

## Homebrew Formula

Add to `Formula/git-nav.rb`:

```ruby
depends_on "git-delta"
```

(`less` is part of every supported system; not declared.)

## Testing

Extend the existing CI functional test (mirrors the `bounce` test):

- `diff --plain` on a repo with changes produces non-empty output and exit 0.
- `diff` with no changes prints "No changes" and exits 0.
- `diff` when `delta` is absent from `PATH` prints install guidance and exits
  non-zero (stub `PATH` for the test).
- `diff --help`/usage path behaves.

Interactive `less` navigation is not unit-tested (standard for TUI paging).

## Out of Scope (YAGNI)

- Bare `n`/`p` key rebinding (deferred; depends on newer `less`).
- fzf-based file picker (a different navigation model the user did not choose).
- Configurable line-number / decoration styles beyond the theme env var.
