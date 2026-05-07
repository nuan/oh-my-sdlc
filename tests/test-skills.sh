#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

check() {
  local file="$ROOT/$1"
  local pattern="$2"
  local label="$3"
  if [ ! -f "$file" ]; then
    echo "FAIL: $1 does not exist"
    FAIL=$((FAIL + 1))
    return
  fi
  if grep -q "$pattern" "$file"; then
    PASS=$((PASS + 1))
  else
    echo "FAIL [$1]: missing '$label'"
    FAIL=$((FAIL + 1))
  fi
}

# ── CLAUDE.md ────────────────────────────────────────
check "CLAUDE.md" "get_next_work" "get_next_work"
check "CLAUDE.md" "claim_task" "claim_task"
check "CLAUDE.md" "complete_task" "complete_task"
check "CLAUDE.md" "NOTION_TOKEN" "NOTION_TOKEN"
check "CLAUDE.md" "skills/" "skills/ reference"

# ── GEMINI.md ────────────────────────────────────────
check "GEMINI.md" "get_next_work" "get_next_work"
check "GEMINI.md" "claim_task" "claim_task"
check "GEMINI.md" "NOTION_TOKEN" "NOTION_TOKEN"

# ── AGENTS.md ────────────────────────────────────────
check "AGENTS.md" "get_next_work" "get_next_work"
check "AGENTS.md" "claim_task" "claim_task"
check "AGENTS.md" "NOTION_TOKEN" "NOTION_TOKEN"

# ── skills/bootstrap.md ──────────────────────────────
check "skills/bootstrap.md" "NOTION_TOKEN" "NOTION_TOKEN"
check "skills/bootstrap.md" "get_next_work" "get_next_work"
check "skills/bootstrap.md" "claim_task" "claim_task"
check "skills/bootstrap.md" "complete_task" "complete_task"
check "skills/bootstrap.md" "get_project_knowledge" "get_project_knowledge"
check "skills/bootstrap.md" "return_task" "return_task"

# ── skills/requirements.md ───────────────────────────
check "skills/requirements.md" "REFINE" "REFINE"
check "skills/requirements.md" "P0" "priority P0"
check "skills/requirements.md" "Ready" "Ready status"
check "skills/requirements.md" "Inbox" "Inbox status"
check "skills/requirements.md" "get_project_knowledge" "get_project_knowledge"
check "skills/requirements.md" "验收标准" "acceptance criteria"

# ── skills/develop.md ────────────────────────────────
check "skills/develop.md" "DEVELOP" "DEVELOP"
check "skills/develop.md" "return_task" "return_task"
check "skills/develop.md" "complete_task" "complete_task"
check "skills/develop.md" "get_project_knowledge" "get_project_knowledge"
check "skills/develop.md" "upsert_knowledge_entry" "upsert_knowledge_entry"
check "skills/develop.md" "做了什么" "result summary"
check "skills/develop.md" "superpowers" "superpowers"

# ── skills/deploy.md ─────────────────────────────────
check "skills/deploy.md" "DEPLOY" "DEPLOY"
check "skills/deploy.md" "return_task" "return_task"
check "skills/deploy.md" "complete_task" "complete_task"
check "skills/deploy.md" "DEPLOY_TOKEN\|DEPLOY_SSH_KEY_PATH" "deploy credentials"
check "skills/deploy.md" "github-actions" "github-actions"

# ── skills/monitor.md ────────────────────────────────
check "skills/monitor.md" "MONITOR" "MONITOR"
check "skills/monitor.md" "return_task" "return_task"
check "skills/monitor.md" "complete_task" "complete_task"
check "skills/monitor.md" "monitor-check.sh" "monitor-check.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
