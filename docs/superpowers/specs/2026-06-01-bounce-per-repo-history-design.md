# Design: `bounce` command + per-repo history

**Date:** 2026-06-01  
**Status:** Approved

---

## Problem

Two bugs in the current `git-nav back`/`prev`/`-` flow:

1. `HISTORY_FILE` is global (`~/.git-nav-history`) — branch visits from all repos mix together. `cmd_recent` and `cmd_back` in repo A can surface branches that only exist in repo B.
2. `cmd_back 1` reads line 1 of the history file, which is the current branch (last recorded switch). Result: no-op.

The user also wants a dedicated "bounce" command — a smart toggle that falls back gracefully when no history exists.

---

## Storage

### Change

Remove the static constant:
```bash
HISTORY_FILE="$HOME/.git-nav-history"
```

Replace with a function:
```bash
history_file() {
  echo "$(git rev-parse --git-common-dir)/git-nav-history"
}
```

`--git-common-dir` returns `.git/` for normal repos and the shared git dir for worktrees — so history is per-repo and shared across all worktrees of the same repo.

### Callers to update

All four callers replace `"$HISTORY_FILE"` with `"$(history_file)"`:
- `record_switch`
- `cmd_recent`
- `cmd_back`
- `cmd_status`

### Migration

No migration. Old `~/.git-nav-history` simply stops being used. Per-repo history starts fresh.

---

## Fix: `cmd_back`

### Current bug

`sed -n "1p" "$HISTORY_FILE"` returns the current branch (most recent recorded switch = current). `back 1` is always a no-op.

### Fix

Iterate history, skip lines matching the current branch, count from remaining entries.

```bash
cmd_back() {
  local steps="${1:-1}"
  local current
  current=$(current_branch)
  local hf
  hf=$(history_file)

  if [[ ! -f "$hf" ]]; then
    echo -e "${COLOR_YELLOW}No history to go back to.${COLOR_RESET}"
    return 1
  fi

  local count=0 target=""
  while IFS= read -r branch; do
    [[ "$branch" == "$current" ]] && continue
    (( count++ ))
    if [[ "$count" -eq "$steps" ]]; then
      target="$branch"
      break
    fi
  done < "$hf"

  if [[ -z "$target" ]]; then
    echo -e "${COLOR_RED}No branch at position $steps in history.${COLOR_RESET}"
    return 1
  fi

  if ! git show-ref --verify --quiet "refs/heads/$target" 2>/dev/null; then
    echo -e "${COLOR_RED}Branch '${target}' no longer exists.${COLOR_RESET}"
    return 1
  fi

  do_switch "$target"
}
```

---

## New command: `bounce`

### Command name and alias

- Command: `git-nav bounce`
- Alias: `gntog`
- Note: `gnb` is already taken by `git-nav branch`

### Logic

```
1. Per-repo history contains a non-current branch that still exists locally?
   → switch to it
   → print: "master => feature  (previous)"

2. No history (or no valid previous branch):
   a. 1 local branch  → error: "Only one branch: master"
   b. 2 local branches → switch to the other one
                       → print: "master => feature  (only branch available)"
   c. 3+ local branches → drop into cmd_list (no arrow output)
```

### Output format

```
✓ master => feature  (previous)
✓ master => feature  (only branch available)
```

Colours: `✓` green, branch names bold, `=>` dim, label dim.

### Implementation sketch

`cmd_bounce` does NOT call `do_switch` (which prints its own `✓ Switched to…` line). Instead it calls `git checkout` + `record_switch` directly so it controls all output and avoids double-printing.

```bash
bounce_switch() {
  local target="$1" label="$2" from="$3"
  local git_output
  if git_output=$(git checkout "$target" 2>&1); then
    record_switch "$target"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}${from}${COLOR_RESET} ${COLOR_DIM}=>${COLOR_RESET} ${COLOR_BOLD}${target}${COLOR_RESET}  ${COLOR_DIM}(${label})${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}✗ Failed to switch to ${COLOR_BOLD}${target}${COLOR_RESET}"
    echo -e "${COLOR_DIM}${git_output}${COLOR_RESET}"
    return 1
  fi
}

cmd_bounce() {
  local current
  current=$(current_branch)
  local hf
  hf=$(history_file)

  # 1. Check history
  local prev=""
  if [[ -f "$hf" ]]; then
    while IFS= read -r branch; do
      if [[ "$branch" != "$current" ]]; then
        if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
          prev="$branch"
          break
        fi
      fi
    done < "$hf"
  fi

  if [[ -n "$prev" ]]; then
    bounce_switch "$prev" "previous" "$current"
    return 0
  fi

  # 2. No history — count local branches
  local branch_count
  branch_count=$(git branch --format='%(refname:short)' | wc -l | tr -d ' ')

  if [[ "$branch_count" -eq 1 ]]; then
    echo -e "${COLOR_RED}Only one branch: ${COLOR_BOLD}${current}${COLOR_RESET}"
    return 1
  fi

  if [[ "$branch_count" -eq 2 ]]; then
    local other
    other=$(git branch --format='%(refname:short)' | grep -vxF "$current")
    bounce_switch "$other" "only branch available" "$current"
    return 0
  fi

  # 3. 3+ branches, no history — show list
  cmd_list
}
```

### Wire-up in main case statement

```bash
bounce|tog)   shift; cmd_bounce ;;
```

### Shell alias to add to help text

```
gntog   git-nav bounce
```

---

## Files changed

- `bin/git-nav` — all changes above
- `README.md` — document `bounce` command and `gntog` alias
