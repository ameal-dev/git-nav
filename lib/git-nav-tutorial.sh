#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  lib/git-nav-tutorial.sh — Interactive tutorial for git-nav
#  Sourced by bin/git-nav; COLOR_* variables and cmd_* functions are in scope.
# ─────────────────────────────────────────────────────────────────────────────

TUTORIAL_SANDBOX=""

_tutorial_cleanup() {
  if [[ -n "$TUTORIAL_SANDBOX" && -d "$TUTORIAL_SANDBOX" ]]; then
    rm -rf "$TUTORIAL_SANDBOX"
    TUTORIAL_SANDBOX=""
  fi
}

_tutorial_header() {
  local title="$1"
  echo ""
  echo -e "${COLOR_CYAN}${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
  echo -e "${COLOR_BOLD}  $title${COLOR_RESET}"
  echo -e "${COLOR_CYAN}${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
  echo ""
}

_tutorial_pause() {
  echo ""
  echo -ne "${COLOR_DIM}[ press Enter to continue ]${COLOR_RESET}"
  read -r || true
  echo ""
}

_tutorial_in_git_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null
}

_tutorial_sandbox_create() {
  TUTORIAL_SANDBOX=$(mktemp -d)
  git -C "$TUTORIAL_SANDBOX" init -q
  git -C "$TUTORIAL_SANDBOX" config user.email "tutorial@example.com"
  git -C "$TUTORIAL_SANDBOX" config user.name "Tutorial User"
  git -C "$TUTORIAL_SANDBOX" commit --allow-empty -q -m "Initial commit"

  for branch in \
    "feat/PROJ-123-user-authentication" \
    "feat/PROJ-456-payment-gateway" \
    "bugfix/PROJ-789-login-redirect" \
    "hotfix/PROJ-101-null-pointer-crash" \
    "feat/PROJ-202-dark-mode" \
    "bugfix/PROJ-303-email-validation"
  do
    git -C "$TUTORIAL_SANDBOX" branch "$branch" 2>/dev/null || true
  done
}

_tutorial_sandbox_destroy() {
  _tutorial_cleanup
}

# ── Module 1: search ────────────────────────────────────────────────────────

_tutorial_module_search() {
  _tutorial_header "Module 1 · gn search — Fuzzy branch search"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  Your colleague Slacks: ${COLOR_YELLOW}\"Can you review the auth fix?\"${COLOR_RESET}"
  echo -e "  You have 20+ branches. You can't remember the exact name."
  echo -e "  Without git-nav: ${COLOR_DIM}git branch | grep auth   (scroll, squint, retype)${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn search auth${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Fuzzy-matches 'auth' across every branch name.${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Type just a few letters — it doesn't need to be exact.${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Single match? Switches immediately. Multiple? Numbered menu.${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo; then
    echo -e "${COLOR_BOLD}Live demo — branches in your repo matching 'auth':${COLOR_RESET}"
    echo ""

    local branches
    branches=$(git branch --all --format='%(refname:short)' | \
      sed 's|^origin/||' | sort -u | \
      grep -iE "a.*u.*t.*h" 2>/dev/null || true)

    local current
    current=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

    if [[ -z "$branches" ]]; then
      branches=$(git branch --all --format='%(refname:short)' | \
        sed 's|^origin/||' | sort -u | head -5 || true)
      echo -e "  ${COLOR_DIM}(no 'auth' branches here — showing first 5 branches instead)${COLOR_RESET}"
      echo ""
    fi

    local i=1
    while IFS= read -r branch; do
      [[ -z "$branch" ]] && continue
      local formatted
      formatted=$(format_branch_name "$branch" "$current")
      printf "  ${COLOR_YELLOW}%2d${COLOR_RESET}  %b\n" "$i" "$formatted"
      ((i++)) || true
    done <<< "$branches"

    echo ""
    echo -e "  ${COLOR_DIM}Switch to branch #: _   ← you'd type a number and press Enter${COLOR_RESET}"
  else
    echo -e "  ${COLOR_DIM}(run from inside a git repo to see live output)${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn search auth${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn search feat${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn aven43${COLOR_RESET}       ${COLOR_DIM}# no subcommand — bare query searches directly${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn search <term>${COLOR_RESET} fuzzy-matches branch names across your whole repo"
  echo -e "  • One match → instant switch. Multiple → pick from a numbered list."
}

# ── Module 2: ticket ────────────────────────────────────────────────────────

_tutorial_module_ticket() {
  _tutorial_header "Module 2 · gn ticket — Find a branch by ticket ID"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  Jira says ${COLOR_YELLOW}PROJ-342${COLOR_RESET} needs a code review."
  echo -e "  Which branch is that? feat, bugfix, hotfix? Did someone prefix it differently?"
  echo -e "  Without git-nav: ${COLOR_DIM}git branch | grep PROJ-342   (and hope you typed it right)${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn ticket PROJ-342${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Case-insensitive. Works with any format: AVEN-43, BUG-7, ENG-1001.${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# One match → switches immediately. Multiple → numbered menu.${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo; then
    echo -e "${COLOR_BOLD}Live demo — ticket-style branches in your repo:${COLOR_RESET}"
    echo ""

    local branches
    branches=$(git branch --all --format='%(refname:short)' | \
      sed 's|^origin/||' | sort -u | \
      grep -iE '[A-Z]+-[0-9]+' 2>/dev/null | head -8 || true)

    if [[ -z "$branches" ]]; then
      echo -e "  ${COLOR_DIM}(no ticket-style branches in this repo)${COLOR_RESET}"
      echo -e "  ${COLOR_DIM}Example: feat/AVEN-43-fix-login would match 'gn ticket AVEN-43'${COLOR_RESET}"
    else
      local current
      current=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
      local i=1
      while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        local formatted
        formatted=$(format_branch_name "$branch" "$current")
        printf "  ${COLOR_YELLOW}%2d${COLOR_RESET}  %b\n" "$i" "$formatted"
        ((i++)) || true
      done <<< "$branches"
    fi
  else
    echo -e "  ${COLOR_DIM}(run from inside a git repo to see live output)${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn ticket PROJ-342${COLOR_RESET}   ${COLOR_DIM}# replace with a real ticket from your repo${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn ticket <ID>${COLOR_RESET} finds branches by ticket ID, regardless of type prefix"
  echo -e "  • You don't need to remember whether it's feat/, bugfix/, or hotfix/"
}

# ── Module 3: back ──────────────────────────────────────────────────────────

_tutorial_module_back() {
  _tutorial_header "Module 3 · gn back — Return to your previous branch"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  You're deep in a code review on someone else's branch."
  echo -e "  You need to hop back to ${COLOR_YELLOW}your${COLOR_RESET} branch to fix something quick."
  echo -e "  Without git-nav: ${COLOR_DIM}git checkout ...what was the name again...${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn back${COLOR_RESET}     ${COLOR_DIM}# jumps to your previous branch${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn back 2${COLOR_RESET}   ${COLOR_DIM}# jumps 2 branches back in your personal history${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn b${COLOR_RESET}        ${COLOR_DIM}# shortest alias${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo && [[ -f "$HISTORY_FILE" && -s "$HISTORY_FILE" ]]; then
    echo -e "${COLOR_BOLD}Your branch history (most recent first):${COLOR_RESET}"
    echo ""
    local i=1
    while IFS= read -r branch; do
      git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || continue
      local formatted
      formatted=$(format_branch_name "$branch" "")
      printf "  ${COLOR_YELLOW}%2d${COLOR_RESET}  %b\n" "$i" "$formatted"
      ((i++)) || true
      [[ $i -gt 5 ]] && break
    done < "$HISTORY_FILE"
    echo ""
    echo -e "  ${COLOR_DIM}gn back  →  would switch to history item #1${COLOR_RESET}"
  else
    echo -e "  ${COLOR_DIM}(no history yet — git-nav builds it automatically as you switch)${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}Try: gn search <something>, switch a few times, then run gn back${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn back${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn back${COLOR_RESET} is your escape hatch — instant return to the previous branch"
  echo -e "  • ${COLOR_GREEN}gn back 2${COLOR_RESET} goes further back through your personal navigation history"
}

# ── Module 4: recent ────────────────────────────────────────────────────────

_tutorial_module_recent() {
  _tutorial_header "Module 4 · gn recent — Resume where you left off"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  It's Monday morning. You were juggling three things Friday"
  echo -e "  afternoon. Which branch were you on? Where were you in each?"
  echo -e "  Without git-nav: ${COLOR_DIM}git branch --sort=-committerdate | head  (commit dates ≠ you visited them)${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn recent${COLOR_RESET}   ${COLOR_DIM}# shows the branches YOU visited, in order of last visit${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn r${COLOR_RESET}        ${COLOR_DIM}# alias${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo; then
    local current
    current=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

    if [[ -f "$HISTORY_FILE" && -s "$HISTORY_FILE" ]]; then
      echo -e "${COLOR_BOLD}Your recent branches:${COLOR_RESET}"
      echo ""
      local i=1
      while IFS= read -r branch; do
        git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || continue
        local formatted
        formatted=$(format_branch_name "$branch" "$current")
        printf "  ${COLOR_YELLOW}%2d${COLOR_RESET}  %b\n" "$i" "$formatted"
        ((i++)) || true
        [[ $i -gt 8 ]] && break
      done < "$HISTORY_FILE"
    else
      echo -e "  ${COLOR_DIM}(no history yet — showing branches by commit date as a preview)${COLOR_RESET}"
      echo ""
      local i=1
      while IFS= read -r branch; do
        local formatted
        formatted=$(format_branch_name "$branch" "$current")
        local age
        age=$(git log -1 --format='%cr' "$branch" 2>/dev/null || echo "")
        printf "  ${COLOR_YELLOW}%2d${COLOR_RESET}  %-50b ${COLOR_DIM}%s${COLOR_RESET}\n" "$i" "$formatted" "$age"
        ((i++)) || true
        [[ $i -gt 6 ]] && break
      done < <(git branch --format='%(refname:short)' --sort=-committerdate)
    fi
  else
    echo -e "  ${COLOR_DIM}(run from inside a git repo to see live output)${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn recent${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn recent${COLOR_RESET} tracks your navigation history, not just commit dates"
  echo -e "  • Stale branches (deleted elsewhere) are filtered out automatically"
}

# ── Module 5: type ──────────────────────────────────────────────────────────

_tutorial_module_type() {
  _tutorial_header "Module 5 · gn type — Filter branches by prefix"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  You need to cut a ${COLOR_YELLOW}hotfix${COLOR_RESET}. But first — are there open hotfixes already?"
  echo -e "  Also, you just want to see your feature branches without bugfix/chore noise."
  echo -e "  Without git-nav: ${COLOR_DIM}git branch | grep '^  hotfix/'   (manual prefix filter)${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn type${COLOR_RESET}          ${COLOR_DIM}# shows all prefix types and branch counts${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn type hotfix${COLOR_RESET}   ${COLOR_DIM}# lists only hotfix/ branches with last-commit ages${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn type feat${COLOR_RESET}     ${COLOR_DIM}# just feature branches${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo; then
    echo -e "${COLOR_BOLD}Branch types in your repo:${COLOR_RESET}"
    echo ""

    local types
    types=$(git branch --format='%(refname:short)' | \
      grep '/' | sed 's|/.*||' | sort | uniq -c | sort -rn || true)

    if [[ -z "$types" ]]; then
      echo -e "  ${COLOR_DIM}(no prefixed branches like feat/, bugfix/ found in this repo)${COLOR_RESET}"
    else
      while IFS= read -r line; do
        local count name
        count=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print $2}')
        printf "  ${COLOR_CYAN}%-15s${COLOR_RESET} ${COLOR_DIM}(%d branches)${COLOR_RESET}\n" "$name" "$count"
      done <<< "$types"
    fi
  else
    echo -e "  ${COLOR_DIM}(run from inside a git repo to see live output)${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn type${COLOR_RESET}        ${COLOR_DIM}# see what types you have${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn type feat${COLOR_RESET}   ${COLOR_DIM}# replace with a type from your repo${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn type${COLOR_RESET} without args gives a summary of all branch prefixes and counts"
  echo -e "  • ${COLOR_GREEN}gn type <prefix>${COLOR_RESET} narrows the list with commit ages — perfect for cleanup"
}

# ── Module 6: branch ────────────────────────────────────────────────────────

_tutorial_module_branch() {
  _tutorial_header "Module 6 · gn branch — Create a branch the right way"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  You're starting ${COLOR_YELLOW}PROJ-456${COLOR_RESET}. The ritual before git-nav:"
  echo -e "  checkout main, pull latest, remember the naming convention, type it"
  echo -e "  without a typo, and don't forget to slugify the description."
  echo -e "  Without git-nav: ${COLOR_DIM}git checkout main && git pull && git checkout -b feat/PROJ-456-...${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn branch feat PROJ-456 add payment flow${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}#  → syncs main, creates feat/PROJ-456-add-payment-flow${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn branch PROJ-456 add payment flow${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}#  → 'feat' is the default type, same result${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gnb PROJ-456 add payment flow${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}#  → shortest alias${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}Live demo — running in a sandboxed repo:${COLOR_RESET}"
  echo ""

  _tutorial_sandbox_create

  local base_branch
  base_branch=$(git -C "$TUTORIAL_SANDBOX" symbolic-ref --short HEAD 2>/dev/null || echo "main")

  echo -e "  ${COLOR_DIM}\$ gn branch feat PROJ-456 add payment flow${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}Syncing ${COLOR_BOLD}${base_branch}${COLOR_RESET}${COLOR_CYAN}...${COLOR_RESET}"
  echo -e "${COLOR_CYAN}Creating ${COLOR_BOLD}feat/PROJ-456-add-payment-flow${COLOR_RESET}${COLOR_CYAN} from ${base_branch}...${COLOR_RESET}"

  git -C "$TUTORIAL_SANDBOX" checkout -b "feat/PROJ-456-add-payment-flow" -q 2>/dev/null

  echo -e "${COLOR_GREEN}✓ Created and switched to ${COLOR_BOLD}feat/PROJ-456-add-payment-flow${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_DIM}Sandbox branch list:${COLOR_RESET}"
  git -C "$TUTORIAL_SANDBOX" branch | while IFS= read -r line; do
    echo -e "  ${COLOR_DIM}${line}${COLOR_RESET}"
  done

  _tutorial_sandbox_destroy

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn branch feat PROJ-456 add payment flow${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}  Replace PROJ-456 with a real ticket and description.${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn branch${COLOR_RESET} syncs main and creates a correctly-named branch in one step"
  echo -e "  • Spaces become hyphens automatically — no manual slug formatting needed"
}

# ── Module 7: status ────────────────────────────────────────────────────────

_tutorial_module_status() {
  _tutorial_header "Module 7 · gn status — Branch health at a glance"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  Sprint review in 10 minutes. Which of your branches have commits?"
  echo -e "  Which have fallen behind main and will conflict on merge?"
  echo -e "  Without git-nav: ${COLOR_DIM}git branch -v  (cramped, no ahead/behind counts)${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn status${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# AHEAD = commits on your branch not in main (your work)${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# BEHIND = commits in main you're missing (potential conflicts)${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Also shows linked PR numbers if you have the 'gh' CLI.${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo; then
    echo -e "${COLOR_BOLD}Live demo — your branch status:${COLOR_RESET}"
    echo ""

    local base
    base=$(detect_base_branch)
    local current
    current=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

    local branches
    if [[ -f "$HISTORY_FILE" && -s "$HISTORY_FILE" ]]; then
      branches=$(head -8 "$HISTORY_FILE")
    else
      branches=$(git branch --format='%(refname:short)' --sort=-committerdate | head -6)
    fi

    printf "  ${COLOR_BOLD}%-40s  %5s  %6s  %-10s${COLOR_RESET}\n" "BRANCH" "AHEAD" "BEHIND" "AGE"
    printf "  ${COLOR_DIM}%-40s  %5s  %6s  %-10s${COLOR_RESET}\n" "────────────────────────────────────────" "─────" "──────" "──────────"

    while IFS= read -r branch; do
      [[ -z "$branch" ]] && continue
      git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || continue

      local ahead behind age
      ahead=$(git rev-list --count "${base}..${branch}" 2>/dev/null || echo 0)
      behind=$(git rev-list --count "${branch}..${base}" 2>/dev/null || echo 0)
      age=$(git log -1 --format='%cr' "$branch" 2>/dev/null || echo "?")

      local marker=""
      [[ "$branch" == "$current" ]] && marker="${COLOR_GREEN}●${COLOR_RESET} "

      local display_branch="$branch"
      [[ ${#branch} -gt 38 ]] && display_branch="${branch:0:35}..."

      printf "  ${marker}%-38s  ${COLOR_GREEN}%5s${COLOR_RESET}  ${COLOR_RED}%6s${COLOR_RESET}  ${COLOR_DIM}%s${COLOR_RESET}\n" \
        "$display_branch" "$ahead" "$behind" "$age"
    done <<< "$branches"
  else
    echo -e "  ${COLOR_DIM}(run from inside a git repo to see live output)${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn status${COLOR_RESET}   ${COLOR_DIM}# alias: gns${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn status${COLOR_RESET} gives you an AHEAD/BEHIND dashboard for your working branches"
  echo -e "  • Green = your unique commits. Red = base commits you're missing."
}

# ── Module 8: copy ──────────────────────────────────────────────────────────

_tutorial_module_copy() {
  _tutorial_header "Module 8 · gn copy — Copy branch info to clipboard"

  echo -e "${COLOR_BOLD}The scenario:${COLOR_RESET}"
  echo -e "  Writing a PR description. You need the branch name, ticket ID,"
  echo -e "  and a readable title for the PR subject — all from the same branch."
  echo -e "  Without git-nav: ${COLOR_DIM}git branch --show-current | pbcopy  (then manually extract ticket)${COLOR_RESET}"

  _tutorial_pause

  echo -e "${COLOR_BOLD}Here's how git-nav solves this:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn copy${COLOR_RESET}           ${COLOR_DIM}# copies the full branch name${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn copy --ticket${COLOR_RESET}  ${COLOR_DIM}# copies only the ticket ID  e.g. PROJ-456${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn copy --desc${COLOR_RESET}    ${COLOR_DIM}# copies the title-cased description  e.g. Add Payment Flow${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gnc${COLOR_RESET}               ${COLOR_DIM}# alias for gn copy${COLOR_RESET}"
  echo ""

  _tutorial_pause

  if _tutorial_in_git_repo; then
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

    echo -e "${COLOR_BOLD}What each flag copies from your current branch:${COLOR_RESET}"
    echo ""
    echo -e "  Current branch: ${COLOR_CYAN}${branch}${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_DIM}gn copy${COLOR_RESET}           →  ${COLOR_GREEN}${branch}${COLOR_RESET}"

    if [[ "$branch" =~ ([A-Z]+-[0-9]+) ]]; then
      echo -e "  ${COLOR_DIM}gn copy --ticket${COLOR_RESET}  →  ${COLOR_GREEN}${BASH_REMATCH[1]}${COLOR_RESET}"
    else
      echo -e "  ${COLOR_DIM}gn copy --ticket${COLOR_RESET}  →  ${COLOR_YELLOW}(no ticket ID in branch name)${COLOR_RESET}"
    fi

    local desc=""
    if [[ "$branch" =~ ^[^/]+/[A-Z]+-[0-9]+-(.+)$ ]]; then
      desc=$(title_case "$(echo "${BASH_REMATCH[1]}" | tr '-' ' ')")
    elif [[ "$branch" =~ ^[^/]+/(.+)$ ]]; then
      desc=$(title_case "$(echo "${BASH_REMATCH[1]}" | tr '-' ' ')")
    else
      desc=$(title_case "$(echo "$branch" | tr '-' ' ')")
    fi
    echo -e "  ${COLOR_DIM}gn copy --desc${COLOR_RESET}    →  ${COLOR_GREEN}${desc}${COLOR_RESET}"
  else
    echo -e "  Example from branch ${COLOR_CYAN}feat/PROJ-456-add-payment-flow${COLOR_RESET}:"
    echo ""
    echo -e "  ${COLOR_DIM}gn copy${COLOR_RESET}           →  ${COLOR_GREEN}feat/PROJ-456-add-payment-flow${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}gn copy --ticket${COLOR_RESET}  →  ${COLOR_GREEN}PROJ-456${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}gn copy --desc${COLOR_RESET}    →  ${COLOR_GREEN}Add Payment Flow${COLOR_RESET}"
  fi

  _tutorial_pause

  echo -e "${COLOR_BOLD}Now try it yourself:${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_CYAN}gn copy${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn copy --ticket${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}gn copy --desc${COLOR_RESET}"
  echo ""

  _tutorial_pause

  echo -e "${COLOR_BOLD}What you just learned:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}gn copy${COLOR_RESET} puts the branch name straight on the clipboard"
  echo -e "  • ${COLOR_GREEN}--ticket${COLOR_RESET} and ${COLOR_GREEN}--desc${COLOR_RESET} extract the parts you need for PRs and Slack"
}

# ── Dispatcher ──────────────────────────────────────────────────────────────

_tutorial_run_module() {
  local n="$1"
  case "$n" in
    1) _tutorial_module_search ;;
    2) _tutorial_module_ticket ;;
    3) _tutorial_module_back ;;
    4) _tutorial_module_recent ;;
    5) _tutorial_module_type ;;
    6) _tutorial_module_branch ;;
    7) _tutorial_module_status ;;
    8) _tutorial_module_copy ;;
    *) echo -e "${COLOR_RED}Unknown module: $n${COLOR_RESET}" ;;
  esac
}

# ── Entry point ─────────────────────────────────────────────────────────────

_tutorial_main() {
  trap _tutorial_cleanup EXIT

  clear 2>/dev/null || true

  echo ""
  echo -e "${COLOR_BOLD}${COLOR_CYAN}  git-nav interactive tutorial${COLOR_RESET}"
  echo -e "${COLOR_DIM}  8 commands. Each module takes ~2 minutes. No forced order.${COLOR_RESET}"
  echo ""
  echo -e "  Read-only demos (search, ticket, recent, back, type, status, copy)"
  echo -e "  run against your real repo. The branch-creation demo uses a sandbox."
  echo ""

  while true; do
    echo -e "${COLOR_BOLD}Modules:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_YELLOW}1${COLOR_RESET}  ${COLOR_CYAN}search${COLOR_RESET}   Fuzzy-find a branch when a colleague says 'check the auth fix'"
    echo -e "  ${COLOR_YELLOW}2${COLOR_RESET}  ${COLOR_CYAN}ticket${COLOR_RESET}   Jump to a branch from a Jira / Linear ticket ID"
    echo -e "  ${COLOR_YELLOW}3${COLOR_RESET}  ${COLOR_CYAN}back${COLOR_RESET}     Instantly return to your previous branch"
    echo -e "  ${COLOR_YELLOW}4${COLOR_RESET}  ${COLOR_CYAN}recent${COLOR_RESET}   Resume Monday morning from where you left off Friday"
    echo -e "  ${COLOR_YELLOW}5${COLOR_RESET}  ${COLOR_CYAN}type${COLOR_RESET}     Cut through clutter — see only feat, bugfix, or hotfix branches"
    echo -e "  ${COLOR_YELLOW}6${COLOR_RESET}  ${COLOR_CYAN}branch${COLOR_RESET}   Create a correctly-named branch in one step  ${COLOR_DIM}[sandbox]${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}7${COLOR_RESET}  ${COLOR_CYAN}status${COLOR_RESET}   Sprint review — see ahead/behind for all your working branches"
    echo -e "  ${COLOR_YELLOW}8${COLOR_RESET}  ${COLOR_CYAN}copy${COLOR_RESET}     Paste branch name or ticket ID into a PR or Slack"
    echo ""
    echo -e "  ${COLOR_DIM}0 or q  quit${COLOR_RESET}"
    echo ""
    echo -ne "${COLOR_DIM}Pick a module (1–8): ${COLOR_RESET}"
    read -r choice || true

    case "$choice" in
      1|2|3|4|5|6|7|8)
        _tutorial_run_module "$choice"
        echo ""
        echo -e "${COLOR_DIM}  ──────────────────────────────────────────────────────${COLOR_RESET}"
        echo -e "  Module complete. Pick another or ${COLOR_YELLOW}0${COLOR_RESET} to quit."
        echo -e "${COLOR_DIM}  ──────────────────────────────────────────────────────${COLOR_RESET}"
        echo ""
        ;;
      0|q|Q|quit|exit)
        echo ""
        echo -e "${COLOR_DIM}  Thanks for the tutorial. Happy branching!${COLOR_RESET}"
        echo ""
        trap - EXIT
        return 0
        ;;
      "")
        ;;
      *)
        echo -e "${COLOR_RED}  Please enter a number 1–8 or 0 to quit.${COLOR_RESET}"
        echo ""
        ;;
    esac
  done
}
