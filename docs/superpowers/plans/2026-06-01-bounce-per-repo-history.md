# Bounce + Per-Repo History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `git-nav bounce` command (alias `gntog`) that toggles to the previous branch with smart fallback, backed by per-repo history stored in `.git/git-nav-history`.

**Architecture:** All changes are in `bin/git-nav`. The global `HISTORY_FILE` constant is replaced by a `history_file()` function that uses `git rev-parse --git-common-dir` to return a repo-local path. A new `bounce_switch()` helper handles checkout + output for the bounce command. `cmd_bounce()` implements the smart toggle logic. `cmd_back` is fixed to skip the current branch when counting steps.

**Tech Stack:** Bash 3.2+, git

---

## File Map

| File | Change |
|------|--------|
| `bin/git-nav` | Remove `HISTORY_FILE` constant; add `history_file()` + `bounce_switch()` helpers; rewrite `cmd_back`; add `cmd_bounce`; wire case statement + help text |
| `README.md` | Update history file path reference; add `bounce` to commands + examples; fix `gnb` alias inconsistency; add `gntog` alias |
| `.github/workflows/ci.yml` | Add functional test for `bounce` |

---

## Task 1: Replace `HISTORY_FILE` constant with `history_file()` function

**Files:**
- Modify: `bin/git-nav:10` (Config section — remove constant)
- Modify: `bin/git-nav:60-67` (`record_switch`)
- Modify: `bin/git-nav:283-303` (`cmd_recent`)
- Modify: `bin/git-nav:652-698` (`cmd_status`)

### Context

`HISTORY_FILE` is set at line 10 of the Config section and referenced in four functions. `record_switch` also uses `${HISTORY_FILE}.tmp` for atomic writes.

- [ ] **Step 1: Remove the `HISTORY_FILE` constant from the Config section**

In `bin/git-nav`, delete this line (line 10):
```bash
HISTORY_FILE="$HOME/.git-nav-history"
```

- [ ] **Step 2: Add `history_file()` function to the Helpers section**

Add immediately after the `detect_base_branch()` function (after line 58):
```bash
history_file() {
  echo "$(git rev-parse --git-common-dir)/git-nav-history"
}
```

- [ ] **Step 3: Update `record_switch` to use `history_file()`**

Replace the current `record_switch` body:
```bash
record_switch() {
  local branch="$1"
  local hf
  hf=$(history_file)
  touch "$hf"
  grep -vxF "$branch" "$hf" > "${hf}.tmp" 2>/dev/null || true
  { echo "$branch"; cat "${hf}.tmp"; } | head -n "$MAX_HISTORY" > "$hf"
  rm -f "${hf}.tmp"
}
```

- [ ] **Step 4: Update `cmd_recent` to use `history_file()`**

In `cmd_recent`, replace:
```bash
  if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
```
with:
```bash
  local hf
  hf=$(history_file)
  if [[ ! -f "$hf" ]] || [[ ! -s "$hf" ]]; then
```

Then replace all remaining `"$HISTORY_FILE"` references in `cmd_recent` with `"$hf"`. There are two: the `while IFS= read -r branch; done < "$HISTORY_FILE"` loop and the second loop inside the selection block.

Full updated `cmd_recent`:
```bash
cmd_recent() {
  local hf
  hf=$(history_file)

  if [[ ! -f "$hf" ]] || [[ ! -s "$hf" ]]; then
    echo -e "${COLOR_YELLOW}No branch history yet. Start switching!${COLOR_RESET}"
    return 0
  fi

  local current
  current=$(current_branch)

  echo -e "${COLOR_BOLD}Recent branches:${COLOR_RESET}\n"

  local i=1
  while IFS= read -r branch; do
    # Only show branches that still exist
    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
      local formatted
      formatted=$(format_branch_name "$branch" "$current")
      printf "  ${COLOR_YELLOW}%2d${COLOR_RESET}  %b\n" "$i" "$formatted"
      ((i++))
    fi
  done < "$hf"

  echo ""
  echo -ne "${COLOR_DIM}Switch to branch #: ${COLOR_RESET}"
  read -r choice

  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    local target
    local j=0
    while IFS= read -r branch; do
      if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        ((j++))
        if [[ "$j" -eq "$choice" ]]; then
          target="$branch"
          break
        fi
      fi
    done < "$hf"

    if [[ -n "${target:-}" ]]; then
      do_switch "$target"
    fi
  fi
}
```

- [ ] **Step 5: Update `cmd_status` to use `history_file()`**

In `cmd_status`, replace:
```bash
  if [[ -f "$HISTORY_FILE" && -s "$HISTORY_FILE" ]]; then
    branches=$(cat "$HISTORY_FILE")
```
with:
```bash
  local hf
  hf=$(history_file)
  if [[ -f "$hf" && -s "$hf" ]]; then
    branches=$(cat "$hf")
```

- [ ] **Step 6: Verify syntax and lint**

```bash
bash -n bin/git-nav && echo "Syntax OK"
shellcheck --severity=warning bin/git-nav
```

Expected: no errors or warnings.

- [ ] **Step 7: Smoke-test in the git-nav repo itself**

```bash
# Should work without error — uses the repo's own .git dir
bash bin/git-nav recent
```

Expected: shows recently visited branches (or "No branch history yet" if `.git/git-nav-history` doesn't exist yet).

- [ ] **Step 8: Commit**

```bash
git add bin/git-nav
git commit -m "refactor: per-repo history via git-common-dir"
```

---

## Task 2: Fix `cmd_back` to skip the current branch

**Files:**
- Modify: `bin/git-nav:328-350` (`cmd_back`)

### Context

Currently `cmd_back 1` reads line 1 of the history file which is the current branch (most recently recorded switch). The fix iterates history and skips entries matching the current branch before counting.

- [ ] **Step 1: Replace `cmd_back` with the fixed version**

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

- [ ] **Step 2: Verify syntax and lint**

```bash
bash -n bin/git-nav && echo "Syntax OK"
shellcheck --severity=warning bin/git-nav
```

Expected: no errors or warnings.

- [ ] **Step 3: Functional test for `back`**

```bash
cd /tmp && rm -rf test-back && mkdir test-back && cd test-back
git init -q && git config user.email "t@t.com" && git config user.name "T"
git commit --allow-empty -q -m "init"
git branch feat/one
git branch feat/two

GN="bash /Users/emil.ryden/code/tools/git-nav/bin/git-nav"

# Use search (single match → auto-switches and records history)
$GN search one &>/dev/null   # switches to feat/one, records it
$GN search two &>/dev/null   # switches to feat/two, records it
# History is now: [feat/two, feat/one, ...]  Current: feat/two

# back 1 should skip feat/two (current) and return feat/one
result=$($GN back 2>&1)
echo "$result" | grep -q "feat/one" && echo "back 1 PASS" || echo "back 1 FAIL: $result"
```

Expected: `back 1 PASS`

- [ ] **Step 4: Commit**

```bash
cd /Users/emil.ryden/code/tools/git-nav
git add bin/git-nav
git commit -m "fix: cmd_back skips current branch when counting steps"
```

---

## Task 3: Add `bounce_switch()` helper and `cmd_bounce()` command

**Files:**
- Modify: `bin/git-nav` — add `bounce_switch()` after `do_switch`; add `cmd_bounce()` after `cmd_back`

### Context

`bounce_switch()` is a helper used only by `cmd_bounce`. It does `git checkout` + `record_switch` directly (not via `do_switch`) so it can print the `from => to  (label)` format without double-printing.

- [ ] **Step 1: Add `bounce_switch()` helper after `do_switch` (after line ~88)**

Add immediately after the closing `}` of `do_switch`:
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
```

- [ ] **Step 2: Add `cmd_bounce()` after `cmd_back`**

Add immediately after the closing `}` of `cmd_back`:
```bash
cmd_bounce() {
  local current
  current=$(current_branch)
  local hf
  hf=$(history_file)

  # 1. Check per-repo history for a valid previous branch
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

- [ ] **Step 3: Verify syntax and lint**

```bash
bash -n bin/git-nav && echo "Syntax OK"
shellcheck --severity=warning bin/git-nav
```

Expected: no errors or warnings.

- [ ] **Step 4: Functional test — 1-branch error**

```bash
cd /tmp && rm -rf test-bounce && mkdir test-bounce && cd test-bounce
git init -q && git config user.email "t@t.com" && git config user.name "T"
git commit --allow-empty -q -m "init"

result=$(bash /Users/emil.ryden/code/tools/git-nav/bin/git-nav bounce 2>&1)
echo "$result" | grep -q "Only one branch" && echo "1-branch PASS" || echo "1-branch FAIL: $result"
```

Expected: `1-branch PASS`

- [ ] **Step 5: Functional test — 2-branch auto-switch**

```bash
cd /tmp/test-bounce
git branch feature/hello

result=$(bash /Users/emil.ryden/code/tools/git-nav/bin/git-nav bounce 2>&1)
echo "$result" | grep -q "feature/hello" && echo "2-branch PASS" || echo "2-branch FAIL: $result"
echo "$result" | grep -q "only branch available" && echo "2-branch label PASS" || echo "2-branch label FAIL: $result"
```

Expected: both `PASS`

- [ ] **Step 6: Functional test — history toggle**

```bash
cd /tmp/test-bounce
GN="bash /Users/emil.ryden/code/tools/git-nav/bin/git-nav"

# State after Step 5: on feature/hello, history=[feature/hello]
# history has no entry for main yet, so this bounce uses 2-branch fallback
result=$($GN bounce 2>&1)
echo "$result" | grep -qE "main|master" && echo "toggle-to-main PASS" || echo "toggle-to-main FAIL: $result"
echo "$result" | grep -q "only branch available" && echo "label-1 PASS" || echo "label-1 FAIL: $result"
# Now on main, history=[main, feature/hello]

# Bounce again — history has feature/hello as previous, so this uses history path
result=$($GN bounce 2>&1)
echo "$result" | grep -q "feature/hello" && echo "toggle-to-feature PASS" || echo "toggle-to-feature FAIL: $result"
echo "$result" | grep -q "previous" && echo "label-2 PASS" || echo "label-2 FAIL: $result"
```

Expected: all four `PASS`

- [ ] **Step 7: Commit**

```bash
cd /Users/emil.ryden/code/tools/git-nav
git add bin/git-nav
git commit -m "feat: add bounce command with smart toggle and per-repo history"
```

---

## Task 4: Wire up case statement, help text, and README

**Files:**
- Modify: `bin/git-nav:997-1023` (main case statement)
- Modify: `bin/git-nav:925-986` (`cmd_help`)
- Modify: `README.md`

- [ ] **Step 1: Add `bounce` to the main case statement**

In the `case "${1:-}" in` block, add after the `back|b|prev|-)` line:
```bash
  bounce|tog)          shift; cmd_bounce ;;
```

- [ ] **Step 2: Add `bounce` to `cmd_help` — navigation section**

In `cmd_help`, after the `git-nav back` line, add:
```bash
  echo -e "  ${COLOR_CYAN}git-nav bounce${COLOR_RESET}                   Toggle to previous branch (smart fallback)"
```

- [ ] **Step 3: Add `gntog` to the aliases section of `cmd_help`**

In the `SHELL ALIASES` section of `cmd_help`, add after the `gnb` line:
```bash
  echo -e "  ${COLOR_CYAN}gntog${COLOR_RESET}   git-nav bounce"
```

- [ ] **Step 4: Update README — fix history path + add bounce command**

In `README.md`, make these changes:

a) Replace:
```
A history file (`~/.git-nav-history`) tracks your recent switches for `back` and `recent`.
```
with:
```
A history file (`.git/git-nav-history`) tracks your recent switches per-repo for `bounce`, `back`, and `recent`.
```

b) After the `git-nav back [n]` line in the commands list, add:
```
git-nav bounce                  # Toggle to previous branch (smart fallback)
```

c) After the `git-nav back` examples, add:
```
git-nav bounce                  # toggle previous ↔ current
```

d) Fix the alias inconsistency — README has `alias gnb='git-nav back'` but the script uses `gnb` for `git-nav branch`. Replace:
```
alias gnb='git-nav back'
```
with:
```
alias gnb='git-nav branch'
alias gntog='git-nav bounce'
```

- [ ] **Step 5: Verify syntax and lint**

```bash
bash -n bin/git-nav && echo "Syntax OK"
shellcheck --severity=warning bin/git-nav
```

Expected: no errors or warnings.

- [ ] **Step 6: Verify help renders**

```bash
bash bin/git-nav help | grep -q "bounce" && echo "help PASS" || echo "help FAIL"
bash bin/git-nav help | grep -q "gntog" && echo "alias PASS" || echo "alias FAIL"
```

Expected: both `PASS`

- [ ] **Step 7: Commit**

```bash
git add bin/git-nav README.md
git commit -m "docs: wire bounce into help text and README, fix gnb alias"
```

---

## Task 5: Add CI functional test for bounce

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add bounce functional test to CI**

In `.github/workflows/ci.yml`, add a new step after the existing `Functional test — search and list` step:

```yaml
      - name: Functional test — bounce command
        run: |
          mkdir -p /tmp/test-bounce
          cd /tmp/test-bounce
          git init -q
          git config user.email "ci@example.com"
          git config user.name "CI"
          git commit --allow-empty -q -m "init"

          GN="bash $GITHUB_WORKSPACE/bin/git-nav"

          # 1-branch: should error with "Only one branch"
          $GN bounce 2>&1 | grep -q "Only one branch" || (echo "FAIL: 1-branch error" && exit 1)

          # 2-branch: should auto-switch with "(only branch available)"
          git branch feature/hello
          $GN bounce 2>&1 | grep -q "only branch available" || (echo "FAIL: 2-branch label" && exit 1)

          # history toggle: bounce back should show "(previous)"
          $GN bounce 2>&1 | grep -q "previous" || (echo "FAIL: history label" && exit 1)

          echo "Bounce functional tests passed"
```

- [ ] **Step 2: Verify CI YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML OK"
```

Expected: `YAML OK`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add functional test for bounce command"
```
