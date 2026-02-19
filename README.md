# git-nav

Smart Git branch navigator for repos with complex branch names.

Tired of typing `git checkout feature/AVEN-43-timeline-entries-are-out-of-order`? git-nav gives you fuzzy search, ticket lookup, and branch history so you never have to.

## Install

```bash
git clone https://github.com/ameal-dev/git-nav.git ~/tools/git-nav
ln -sf ~/tools/git-nav/bin/git-nav ~/.local/bin/git-nav
```

Make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
git-nav                        # Interactive mode
git-nav search <query>         # Fuzzy search branches
git-nav ticket <ID>            # Find branch by ticket (e.g. AVEN-43)
git-nav recent                 # Recently visited branches
git-nav back [n]               # Go back to previous branch
git-nav list [filter]          # List branches sorted by last commit
git-nav type [type]            # Browse by prefix (feature/bugfix/...)
```

Any unrecognized argument is treated as a search query, so `git-nav timeline` just works.

## Examples

```bash
# Fuzzy search — partial matches work
git-nav search timeline         # matches feature/AVEN-43-timeline-entries-are-out-of-order
git-nav search tlo              # fuzzy: t.*l.*o

# Jump straight to a ticket
git-nav ticket AVEN-43          # finds and switches in one step

# Quick navigation
git-nav back                    # previous branch (like cd -)
git-nav back 3                  # 3 branches ago

# Browse by type
git-nav type                    # shows: feature (12), bugfix (4), hotfix (1)
git-nav type feature            # lists only feature branches
```

## How it works

Every command shows a numbered list. Type a number to switch. That's it.

Branch names are displayed in a readable format:

```
feature/AVEN-43-timeline-entries-are-out-of-order
  →  feature/ AVEN-43 timeline entries are out of order
```

A history file (`~/.git-nav-history`) tracks your recent switches for `back` and `recent`.

## Shell aliases

Add to your `.zshrc` or `.bashrc`:

```bash
alias gn='git-nav'
alias gns='git-nav search'
alias gnb='git-nav back'
alias gnr='git-nav recent'
alias gnt='git-nav ticket'
```

## Requirements

- Bash 4+
- Git

## License

MIT license
