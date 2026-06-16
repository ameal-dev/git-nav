# Paged Catppuccin Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `git-nav diff` with a Catppuccin-themed, syntax-highlighted diff that paginates one file per page via `delta` + `less`.

**Architecture:** `cmd_diff` parses flags, resolves a diff target (HEAD / branch / `--staged`), enumerates changed files, renders each file's `git diff` through `delta` into a temp file, then hands all temp files to a single `less -R` so `less` provides scroll-within-file plus `:n`/`:p`/`q` file navigation. `--plain` bypasses everything to raw `git diff`. A `trap` cleans the temp dir.

**Tech Stack:** Bash (single file `bin/git-nav`), `git-delta`, `less`. Tests are inline functional snippets in `.github/workflows/ci.yml`, gated by `shellcheck --severity=warning` and `bash -n`.

**Spec:** `docs/superpowers/specs/2026-06-16-paged-catppuccin-diff-design.md`

---

## File Structure

- **Modify** `bin/git-nav:578-599` — replace `cmd_diff` body with the new flag parser, target resolver, delta-render loop, and `less` pager. Single responsibility: render a paged diff.
- **Modify** `bin/git-nav:1024` and `:1047` — help text and example line for `diff`.
- **Modify** `Formula/git-nav.rb` — add `depends_on "git-delta"`.
- **Modify** `.github/workflows/ci.yml` — add a functional test step covering the non-interactive paths (`--plain`, no-changes, delta-missing). The interactive `less` path is not auto-tested.

All work stays in the existing files; no new files. The branch `feat/paged-catppuccin-diff` already exists and holds the spec commit.

---

## Task 1: Replace `cmd_diff` with flag parser + `--plain` path

This task delivers arg parsing, target resolution, and the `--plain` escape hatch (raw `git diff`). The rich delta path is a stub for now (`echo`/return) so the file stays runnable and shellcheck-clean; Task 2 fills it in.

**Files:**
- Modify: `bin/git-nav:578-599` (the entire current `cmd_diff`)
- Test: `.github/workflows/ci.yml` (added in Task 5; tested manually here)

- [ ] **Step 1: Write the failing test (run manually in a terminal)**

```bash
# Set up a throwaway repo
rm -rf /tmp/gn-diff && mkdir -p /tmp/gn-diff && cd /tmp/gn-diff
git init -q && git config user.email t@t && git config user.name t
printf 'line one\nline two\n' > file.txt
git add file.txt && git commit -q -m init
printf 'line one CHANGED\nline two\n' > file.txt   # unstaged change

GN="bash $HOME/code/tools/git-nav/bin/git-nav"

# --plain must show the raw diff (contains the changed line marker)
$GN diff --plain | grep -q '+line one CHANGED' && echo "PLAIN OK" || echo "PLAIN FAIL"
```

Expected before implementing: `PLAIN FAIL` (old `cmd_diff` requires a `<query>` and errors with "Usage").

- [ ] **Step 2: Replace `cmd_diff` (lines 578-599) with the parser + target resolver + `--plain`**

```bash
cmd_diff() {
  local query="" target_mode="head" side="" plain="" passthrough=()

  for arg in "$@"; do
    case "$arg" in
      --staged|--cached)     target_mode="staged" ;;
      --side|--side-by-side) side="1" ;;
      --plain)               plain="1" ;;
      --*)                   passthrough+=("$arg") ;;
      *)                     query="$arg" ;;
    esac
  done

  # Resolve the diff target into git-diff arguments.
  local target=()
  if [[ "$target_mode" == "staged" ]]; then
    target=(--staged)
  elif [[ -n "$query" ]]; then
    local branch
    branch=$(pick_branch "$query") || return 1
    target=("$branch")
  else
    target=(HEAD)
  fi

  # --plain: raw git diff, no delta/less.
  if [[ -n "$plain" ]]; then
    git diff "${passthrough[@]}" "${target[@]}"
    return
  fi

  # Rich path implemented in Task 2.
  echo -e "${COLOR_DIM}(rich diff not yet implemented)${COLOR_RESET}"
  return 0
}
```

- [ ] **Step 3: Run the test again**

Run the Step 1 snippet.
Expected: `PLAIN OK`.

- [ ] **Step 4: Lint**

```bash
cd "$HOME/code/tools/git-nav"
bash -n bin/git-nav && shellcheck --severity=warning bin/git-nav && echo "LINT OK"
```
Expected: `LINT OK` (no output from shellcheck, then `LINT OK`).

- [ ] **Step 5: Commit**

```bash
cd "$HOME/code/tools/git-nav"
git add bin/git-nav
git commit -m "refactor: cmd_diff flag parser and --plain escape hatch

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Implement the delta render loop + `less` pager

Replace the Task 1 stub with delta detection, no-changes handling, per-file rendering, and the `less` multi-file pager.

**Files:**
- Modify: `bin/git-nav` — the `# Rich path implemented in Task 2.` stub block inside `cmd_diff`

- [ ] **Step 1: Write the failing tests (run manually)**

```bash
# Reuse /tmp/gn-diff from Task 1 (has an unstaged change).
cd /tmp/gn-diff
GN="bash $HOME/code/tools/git-nav/bin/git-nav"

# (a) delta-missing guard: simulate delta absent by emptying PATH of it.
#     Run with a PATH that has git/bash but not delta.
env PATH="/usr/bin:/bin" bash "$HOME/code/tools/git-nav/bin/git-nav" diff 2>&1 \
  | grep -q 'brew install git-delta' && echo "GUARD OK" || echo "GUARD FAIL"

# (b) no-changes path: clean repo prints "No changes".
git checkout -q -- file.txt   # discard the unstaged change
$GN diff --plain | head -1     # should be empty (no diff)
# With delta installed, `$GN diff` should print "No changes"; tested in Step 4.
```

Expected before implementing: `GUARD FAIL` (the stub prints the placeholder, not the install hint).

- [ ] **Step 2: Replace the stub block with the rich implementation**

Replace these two lines inside `cmd_diff`:

```bash
  # Rich path implemented in Task 2.
  echo -e "${COLOR_DIM}(rich diff not yet implemented)${COLOR_RESET}"
  return 0
```

with:

```bash
  # Rich path requires delta.
  if ! command -v delta &>/dev/null; then
    echo -e "${COLOR_RED}delta not found.${COLOR_RESET} Install with: ${COLOR_BOLD}brew install git-delta${COLOR_RESET}" >&2
    echo -e "${COLOR_DIM}Or run: git-nav diff --plain${COLOR_RESET}" >&2
    return 1
  fi

  # Enumerate changed files for this target.
  local files
  files=$(git diff --name-only "${passthrough[@]}" "${target[@]}")
  if [[ -z "$files" ]]; then
    echo -e "${COLOR_DIM}No changes${COLOR_RESET}"
    return 0
  fi

  local theme="${GIT_NAV_DIFF_THEME:-Catppuccin Macchiato}"
  local delta_args=(--syntax-theme "$theme" --line-numbers --paging=never)
  [[ -n "$side" ]] && delta_args+=(--side-by-side)

  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/git-nav-diff.XXXXXX")
  trap 'rm -rf "$tmpdir"' EXIT

  # Render each file's diff through delta into a numbered temp file so
  # less shows them in a stable order. delta prints the file path as a
  # styled header, so the less footer only needs counters + key hints.
  local i=0
  local tmpfiles=()
  while IFS= read -r f; do
    i=$((i + 1))
    local out
    out=$(printf '%s/%02d-%s' "$tmpdir" "$i" "$(echo "$f" | tr '/' '_')")
    git diff "${passthrough[@]}" "${target[@]}" -- "$f" \
      | delta "${delta_args[@]}" > "$out"
    tmpfiles+=("$out")
  done <<< "$files"

  local prompt=' file %i/%m   [:n]ext  [:p]rev  [q]uit  (scroll with arrows) '
  less -R -P "$prompt" "${tmpfiles[@]}"
```

- [ ] **Step 3: Run the guard test**

Run the Step 1 (a) snippet.
Expected: `GUARD OK`.

- [ ] **Step 4: Manual verification with delta installed**

```bash
command -v delta >/dev/null || brew install git-delta
cd /tmp/gn-diff
printf 'line one CHANGED\nline two\nthree\n' > file.txt        # make a change
printf 'second file\n' > other.txt && git add other.txt        # second changed file
GN="bash $HOME/code/tools/git-nav/bin/git-nav"

$GN diff
# Expect: full-screen view of file 1; footer shows "file 1/2 ... [:n]ext ...".
# Press ":n" -> moves to other.txt (file 2/2). Press "q" -> quits cleanly.
# Confirm syntax-highlighted, Catppuccin-colored output.

# No-changes path:
git stash -q && git checkout -q -- . 2>/dev/null
$GN diff | grep -q 'No changes' && echo "NOCHANGE OK" || echo "NOCHANGE FAIL"

# Temp dir is cleaned up:
ls -d "${TMPDIR:-/tmp}"/git-nav-diff.* 2>/dev/null && echo "LEAK" || echo "CLEAN OK"
```
Expected: paged view works, `NOCHANGE OK`, `CLEAN OK`.

- [ ] **Step 5: Lint**

```bash
cd "$HOME/code/tools/git-nav"
bash -n bin/git-nav && shellcheck --severity=warning bin/git-nav && echo "LINT OK"
```
Expected: `LINT OK`.

- [ ] **Step 6: Commit**

```bash
cd "$HOME/code/tools/git-nav"
git add bin/git-nav
git commit -m "feat: paged catppuccin diff via delta and less

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Update help text

**Files:**
- Modify: `bin/git-nav:1024` (the `diff` line in the BRANCH OPERATIONS block)
- Modify: `bin/git-nav:1047` (the `diff --stat` example line)

- [ ] **Step 1: Replace the diff help line (1024)**

Old:
```bash
  echo -e "  ${COLOR_CYAN}git-nav diff${COLOR_RESET} [--stat] <query>    Diff current branch against matched branch"
```
New:
```bash
  echo -e "  ${COLOR_CYAN}git-nav diff${COLOR_RESET} [query]             Paged Catppuccin diff (vs HEAD, branch, or --staged; --plain, --side)"
```

- [ ] **Step 2: Replace the diff example line (1047)**

Old:
```bash
  echo -e "  ${COLOR_DIM}git-nav diff --stat main                       # show changed files vs main${COLOR_RESET}"
```
New:
```bash
  echo -e "  ${COLOR_DIM}git-nav diff --staged                          # paged diff of staged changes${COLOR_RESET}"
```

- [ ] **Step 3: Verify help renders and lint**

```bash
cd "$HOME/code/tools/git-nav"
bash bin/git-nav help | grep -q "Paged Catppuccin diff" && echo "HELP OK"
bash -n bin/git-nav && shellcheck --severity=warning bin/git-nav && echo "LINT OK"
```
Expected: `HELP OK` then `LINT OK`.

- [ ] **Step 4: Commit**

```bash
cd "$HOME/code/tools/git-nav"
git add bin/git-nav
git commit -m "docs: update diff help text for paged catppuccin viewer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Add `git-delta` Homebrew dependency

**Files:**
- Modify: `Formula/git-nav.rb`

- [ ] **Step 1: Add the dependency**

After the line `depends_on "bash"`, add:
```ruby
  depends_on "git-delta"
```

- [ ] **Step 2: Verify Ruby syntax**

```bash
cd "$HOME/code/tools/git-nav"
ruby -c Formula/git-nav.rb
```
Expected: `Syntax OK`.

- [ ] **Step 3: Commit**

```bash
cd "$HOME/code/tools/git-nav"
git add Formula/git-nav.rb
git commit -m "build: depend on git-delta for paged diff

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

Note: `Formula/git-nav.rb` already has an unrelated unstaged modification in the working tree from before this work. Stage only the `depends_on "git-delta"` line for this commit (use `git add -p Formula/git-nav.rb` and accept just that hunk) so the pre-existing change is not swept in.

---

## Task 5: Add CI functional tests

Add a CI step mirroring the existing `bounce` functional test. CI runners have no `delta`, which lets us test the `--plain`, no-changes, and delta-missing paths exactly.

**Files:**
- Modify: `.github/workflows/ci.yml` — add a new step after the "Functional test — bounce command" step (currently the last step in the `test` job).

- [ ] **Step 1: Add the functional test step**

Append this step under the `test` job, after the bounce step (match the existing two-space-under-`steps` indentation):

```yaml
      - name: Functional test — diff command
        run: |
          mkdir -p /tmp/test-diff
          cd /tmp/test-diff
          git init -q
          git config user.email "ci@example.com"
          git config user.name "CI"
          printf 'line one\nline two\n' > file.txt
          git add file.txt
          git commit -q -m "init"

          GN="bash $GITHUB_WORKSPACE/bin/git-nav"

          # No changes yet: rich path prints "No changes" (delta absent on CI,
          # but the no-changes check runs before the delta guard).
          # Make an unstaged change so we have something to diff.
          printf 'line one CHANGED\nline two\n' > file.txt

          # --plain shows the raw diff without needing delta.
          $GN diff --plain | grep -q '+line one CHANGED' \
            || { echo "FAIL: --plain output"; exit 1; }

          # Rich path with delta absent: clear install guidance, non-zero exit.
          if $GN diff 2>&1 | grep -q 'brew install git-delta'; then
            echo "delta guard OK"
          else
            echo "FAIL: delta-missing guidance"; exit 1
          fi

          # No-changes path: discard the change, --plain prints nothing.
          git checkout -q -- file.txt
          [ -z "$($GN diff --plain)" ] || { echo "FAIL: no-changes plain"; exit 1; }

          echo "Diff functional tests passed"
```

- [ ] **Step 2: Validate the workflow YAML locally**

```bash
cd "$HOME/code/tools/git-nav"
ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml"); puts "YAML OK"'
```
Expected: `YAML OK`.

- [ ] **Step 3: Dry-run the test body locally (without delta on PATH)**

```bash
rm -rf /tmp/test-diff && mkdir -p /tmp/test-diff && cd /tmp/test-diff
git init -q && git config user.email t@t && git config user.name t
printf 'line one\nline two\n' > file.txt && git add file.txt && git commit -q -m init
printf 'line one CHANGED\nline two\n' > file.txt
env PATH="/usr/bin:/bin" bash "$HOME/code/tools/git-nav/bin/git-nav" diff 2>&1 \
  | grep -q 'brew install git-delta' && echo "GUARD OK"
bash "$HOME/code/tools/git-nav/bin/git-nav" diff --plain | grep -q '+line one CHANGED' && echo "PLAIN OK"
```
Expected: `GUARD OK` and `PLAIN OK`.

- [ ] **Step 4: Commit**

```bash
cd "$HOME/code/tools/git-nav"
git add .github/workflows/ci.yml
git commit -m "ci: functional tests for paged diff command

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Spec coverage:** command surface (Task 1 flags + Task 2 render), delta engine + theme env var (Task 2), `less` multi-file `:n`/`:p`/`q` footer (Task 2), `--plain` (Task 1), `--side` (Tasks 1+2), no-changes + delta-missing + temp cleanup (Task 2), formula dependency (Task 4), CI tests (Task 5), help text (Task 3). All spec sections mapped.
- **Naming consistency:** `target`, `passthrough`, `delta_args`, `tmpfiles`, `GIT_NAV_DIFF_THEME` used identically across Task 1 and Task 2.
- **Pre-existing working-tree changes:** `Formula/git-nav.rb` (modified) and `lib/` (untracked) predate this work — Task 4 stages only its own hunk; no task touches `lib/`.
- **Not auto-tested:** interactive `less` navigation (manual verification in Task 2, Step 4) — standard for TUI paging.
