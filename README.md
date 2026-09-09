# git-nav

Smart Git branch navigator for repos with complex branch names.

Tired of typing `git checkout feature/WH-6639-timeline-entries-are-out-of-order`? git-nav
gives you fuzzy search, ticket lookup, branch history, and a handful of everyday git
shortcuts, so you never have to.

## Quickstart

```bash
git clone git@github.com:fortnox-lab/git-nav.git ~/tools/git-nav
cd ~/tools/git-nav
./install.sh
source share/git-nav.aliases.sh
git-nav tutorial
```

`install.sh` symlinks `git-nav` onto your PATH (`~/.local/bin` by default — pass
`--prefix DIR` to use a different one) and tells you which optional tools are missing.
`git-nav tutorial` is an interactive, hands-on walkthrough of every command against your
own repo — the fastest way to get a feel for it.

To make the install permanent, add these two lines to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
source ~/tools/git-nav/share/git-nav.aliases.sh
```

## Requirements

| Tool | Needed for | Required? |
|---|---|---|
| `git` | everything | yes |
| `bash` | everything (tested on bash 3.2+, macOS's system bash included) | yes |
| [`git-delta`](https://github.com/dandavison/delta) | `git-nav diff` (rich, paged, syntax-highlighted view) | optional — `diff --plain` works without it |
| [`gh`](https://cli.github.com) | `git-nav pr`; PR numbers in `git-nav status` | optional |
| `pbcopy` / `xclip` / `wl-copy` | `git-nav copy` | optional |

`install.sh` checks for all of these and tells you exactly what's missing.

## Commands

### Navigation

```
git-nav                        Interactive mode
git-nav search <query>         Fuzzy search branches
git-nav list [filter]          List branches sorted by last commit
git-nav recent                 Recently visited branches
git-nav back [n]               Go back n branches (default: 1)
git-nav bounce                 Toggle to previous branch (smart fallback)
git-nav ticket <ID>            Find branch by ticket (e.g. WH-6639)
git-nav type [type]            Browse by prefix (feature/bugfix/...)
```

Any unrecognized argument is treated as a search query, so `git-nav timeline` just works.

### Branch operations

```
git-nav branch [type] <ticket> <desc>   Sync base, create type/TICKET-desc (type defaults to 'feat')
git-nav copy [query]                    Copy branch name to clipboard
git-nav copy --ticket [query]           Copy only the ticket ID
git-nav copy --desc [query]             Copy description, title-cased
git-nav commit [-t] [-f] [-c] <msg>     Commit all; -t prepends ticket, -f/-c add a conventional-commit type
git-nav pr [base]                       Open a PR for the current branch (default base: main)
git-nav merge [--squash|--no-ff] <query>  Merge matched branch into current
git-nav rebase <query>                  Rebase current branch onto matched branch
git-nav diff [query]                    Paged, syntax-highlighted diff (vs HEAD, a branch, or --staged)
git-nav log [query]                     git log for matched branch (current if no query)
git-nav delete [--force] <query>        Delete matched branch, with confirmation
```

### Context & status

```
git-nav what [query]           Commits + diff summary for a branch
git-nav status                 Dashboard: ahead/behind/age (+ PR number if `gh` is installed)
git-nav stash                  Stash with an auto-generated "branch @ time" message
git-nav stash pop              Pop a stash (current branch's stashes shown first)
git-nav tutorial               Interactive, hands-on walkthrough of every command
```

Run `git-nav help` any time for the full reference with examples.

## Examples

```bash
# Fuzzy search — partial matches work
git-nav search timeline         # matches feature/WH-6639-timeline-entries-are-out-of-order
git-nav search tlo              # fuzzy: t.*l.*o

# Jump straight to a ticket
git-nav ticket WH-6639          # finds and switches in one step

# Quick navigation
git-nav back                    # previous branch (like cd -)
git-nav back 3                  # 3 branches ago
git-nav bounce                  # toggle previous ↔ current

# Create a branch the right way
git-nav branch WH-6639 timeline entries out of order
# → syncs main, creates feature/WH-6639-timeline-entries-out-of-order

# Everyday git, with less typing
git-nav diff --staged           # paged diff of staged changes
git-nav pr                      # PR → main, title auto-filled from the branch name
git-nav status                  # ahead/behind for your recent branches
```

## How it works

Every command shows a numbered list. Type a number to switch. That's it.

Branch names are displayed in a readable format:

```
feature/WH-6639-timeline-entries-are-out-of-order
  →  feature/ WH-6639 timeline entries are out of order
```

A per-repo history file (at `$(git rev-parse --git-common-dir)/git-nav-history`, typically
`.git/git-nav-history`) tracks your recent switches for `bounce`, `back`, `recent`, and
`status`. By default that history only updates when you switch *through* git-nav — a plain
`git checkout other-branch` doesn't touch it. See **Hooks** below to track those too.

## Hooks

```
git-nav hook install     Track plain 'git checkout'/'git switch' too (per-repo, opt-in)
git-nav hook status      Show whether the hook is installed in this repo
git-nav hook uninstall   Remove it
```

`git-nav hook install` adds a `post-checkout` git hook to the current repo, so ordinary
`git checkout`/`git switch` — not just git-nav's own commands — get recorded into the same
history file `bounce`, `back`, `recent`, and `status` read from. It's per-repo (run it once
in each repo you want this in) and opt-in — install.sh doesn't do it for you.

If a `post-checkout` hook already exists in the repo (from another tool), `hook install`
leaves it alone and prints the one line to add to it by hand, rather than overwriting it.

## Configuration

| Variable | Default | Affects |
|---|---|---|
| `GIT_NAV_DIFF_THEME` | `Catppuccin Macchiato` | Syntax theme used by `git-nav diff` (must be one of `delta --list-syntax-themes`) |

## Conventions it assumes

git-nav is opinionated about a few things. If your repo does things differently, some
commands will need a flag or just won't fit:

- **Remote is named `origin`.** `git-nav branch` runs `git pull origin <base>` when syncing.
- **Base branch is `main` or `master`.** `detect_base_branch()` checks for both, in that
  order, and falls back to `main` if neither exists.
- **Branch names look like `type/TICKET-123-slug-here`.** `git-nav branch` defaults `type`
  to `feat` if you omit it. Ticket IDs are matched with `[A-Z]+-[0-9]+` (Jira/Linear-style —
  works for `WH-6639`, `AVEN-43`, etc.).

## Shell aliases

`source share/git-nav.aliases.sh` from your `~/.zshrc` or `~/.bashrc` (see Quickstart). It's
the single source of truth for aliases — `git-nav help` lists the same set:

```
gn      git-nav (interactive)      gnrb    git-nav rebase
gnb     git-nav branch             gnd     git-nav diff
gnc     git-nav copy               gnl     git-nav log
gncom   git-nav commit             gndel   git-nav delete
gnpr    git-nav pr                 gnw     git-nav what
gnm     git-nav merge              gns     git-nav status
gnr     git-nav recent             gnst    git-nav stash
                                   gnkeys  git-nav help
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
