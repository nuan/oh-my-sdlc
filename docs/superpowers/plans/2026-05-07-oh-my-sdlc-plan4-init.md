# oh-my-sdlc init.sh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `scripts/init.sh` — the one-time human-executed bootstrap script that creates six Notion databases and generates project configuration files.

**Architecture:** Two-pass Notion DB creation (Pass 1: create six DBs without relations; Pass 2: PATCH each to add relation properties). Interactive prompts collect project settings. All generated config is non-sensitive and committed to the project. Mode A = fresh project; Mode B = existing project (appends "read knowledge base first" marker to guide files).

**Tech Stack:** bash, curl, jq, existing `scripts/lib/notion.sh` library, bats for tests.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `scripts/lib/notion.sh` | Modify | Add `notion_create_database` and `notion_update_database` |
| `scripts/init.sh` | Create | Interactive bootstrap: create 6 DBs, generate config files |
| `tests/test-notion-lib.bats` | Modify | Add unit tests for the two new notion.sh functions |
| `tests/test-init.bats` | Create | Integration tests for init.sh (Mode A + Mode B) |

---

### Task 1: Extend notion.sh with DB management functions

**Files:**
- Modify: `scripts/lib/notion.sh`
- Modify: `tests/test-notion-lib.bats`

- [ ] **Step 1: Write failing tests for notion_create_database and notion_update_database**

Append to the end of `tests/test-notion-lib.bats`:

```bash
@test "notion_create_database: 成功时返回包含 id 的 JSON" {
  export MOCK_CURL_RESPONSE='{"id":"new-db-abc","object":"database"}'
  source scripts/lib/notion.sh
  run notion_create_database "parent-page-id" "测试数据库" '{"标题":{"title":{}}}'
  assert_success
  assert_output --partial '"id":"new-db-abc"'
}

@test "notion_create_database: curl 失败时返回错误码" {
  export MOCK_CURL_EXIT_CODE=1
  export MOCK_CURL_RESPONSE='{"object":"error","status":400}'
  source scripts/lib/notion.sh
  run notion_create_database "parent-page-id" "DB" '{"标题":{"title":{}}}'
  assert_failure
}

@test "notion_update_database: 成功时返回 database 对象" {
  export MOCK_CURL_RESPONSE='{"id":"db-xyz","object":"database"}'
  source scripts/lib/notion.sh
  run notion_update_database "db-xyz" '{"Sprint":{"relation":{"database_id":"sprint-id","type":"single_property","single_property":{}}}}'
  assert_success
  assert_output --partial '"id":"db-xyz"'
}

@test "notion_update_database: curl 失败时返回错误码" {
  export MOCK_CURL_EXIT_CODE=1
  export MOCK_CURL_RESPONSE='{"object":"error","status":400}'
  source scripts/lib/notion.sh
  run notion_update_database "db-id" '{}'
  assert_failure
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd ~/.config/superpowers/worktrees/oh-my-sdlc/feat/init
./tests/bats/bin/bats tests/test-notion-lib.bats -t "notion_create_database"
```

Expected: FAIL with "notion_create_database: command not found" (or similar)

- [ ] **Step 3: Add notion_create_database and notion_update_database to notion.sh**

Append to the end of `scripts/lib/notion.sh` (after the last function, before the final newline):

```bash
notion_create_database() {
  local parent_page_id="$1"
  local title="$2"
  local properties_json="$3"
  local payload
  payload=$(jq -n \
    --arg parent_id "$parent_page_id" \
    --arg title "$title" \
    --argjson props "$properties_json" \
    '{parent:{type:"page_id",page_id:$parent_id},title:[{text:{content:$title}}],properties:$props}')
  curl -s -X POST \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${NOTION_API}/databases"
}

notion_update_database() {
  local db_id="$1"
  local properties_json="$2"
  curl -s -X PATCH \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -H "Content-Type: application/json" \
    -d "{\"properties\": $properties_json}" \
    "${NOTION_API}/databases/${db_id}"
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
./tests/bats/bin/bats tests/test-notion-lib.bats -t "notion_create_database"
./tests/bats/bin/bats tests/test-notion-lib.bats -t "notion_update_database"
```

Expected: all 4 new tests PASS

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
./tests/bats/bin/bats tests/test-notion-lib.bats
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/notion.sh tests/test-notion-lib.bats
git commit -m "feat: add notion_create_database and notion_update_database to notion.sh"
```

---

### Task 2: Implement scripts/init.sh (Mode A: fresh project)

**Files:**
- Create: `scripts/init.sh`
- Create: `tests/test-init.bats`

- [ ] **Step 1: Create tests/test-init.bats with failing Mode A tests**

Create `tests/test-init.bats`:

```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() {
  setup_test_env
  TMPDIR=$(mktemp -d)
  export TMPDIR
}

teardown() {
  teardown_test_env
  rm -rf "$TMPDIR"
}

# Helper: run init.sh with piped input in a temp project root
run_init() {
  local input="$1"
  run bash -c "printf '%s' '$input' | PROJECT_ROOT='$TMPDIR' bash scripts/init.sh"
}

@test "init.sh Mode A: 正常退出码 0" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run_init "test-page-id\nMyProject\n14\n10\n3\nA\n"
  assert_success
}

@test "init.sh Mode A: 生成 .sdlc/config.json" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run_init "test-page-id\nMyProject\n14\n10\n3\nA\n"
  assert_success
  [ -f "$TMPDIR/.sdlc/config.json" ]
}

@test "init.sh Mode A: config.json 包含所有数据库 ID" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run_init "test-page-id\nMyProject\n14\n10\n3\nA\n"
  assert_success
  run jq -r '.databases.requirements' "$TMPDIR/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.sprints' "$TMPDIR/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.tasks' "$TMPDIR/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.knowledge' "$TMPDIR/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.deployments' "$TMPDIR/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.monitor_logs' "$TMPDIR/.sdlc/config.json"
  assert_output "test-db-000"
}

@test "init.sh Mode A: config.json 包含正确的项目名和 Sprint 配置" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run_init "test-page-id\nMyProject\n14\n10\n3\nA\n"
  assert_success
  run jq -r '.project_name' "$TMPDIR/.sdlc/config.json"
  assert_output "MyProject"
  run jq -r '.sprint.duration_days' "$TMPDIR/.sdlc/config.json"
  assert_output "14"
  run jq -r '.sprint.capacity' "$TMPDIR/.sdlc/config.json"
  assert_output "10"
}

@test "init.sh Mode A: 生成 .claude/mcp.json" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run_init "test-page-id\nMyProject\n14\n10\n3\nA\n"
  assert_success
  [ -f "$TMPDIR/.claude/mcp.json" ]
  run jq -r '.mcpServers.sdlc.command' "$TMPDIR/.claude/mcp.json"
  assert_output "npx"
}

@test "init.sh Mode A: 生成 .gemini/mcp.json" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run_init "test-page-id\nMyProject\n14\n10\n3\nA\n"
  assert_success
  [ -f "$TMPDIR/.gemini/mcp.json" ]
  run jq -r '.mcpServers.sdlc.command' "$TMPDIR/.gemini/mcp.json"
  assert_output "npx"
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
./tests/bats/bin/bats tests/test-init.bats
```

Expected: FAIL with "scripts/init.sh: No such file or directory"

- [ ] **Step 3: Create scripts/init.sh**

Create `scripts/init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "${SCRIPT_DIR}/lib/notion.sh"

prompt() {
  local label="$1" default="${2:-}"
  if [ -n "$default" ]; then
    printf "%s [%s]: " "$label" "$default" >&2
  else
    printf "%s: " "$label" >&2
  fi
  local value
  read -r value
  echo "${value:-$default}"
}

printf "\n=== oh-my-sdlc 初始化 ===\n\n" >&2

# ── Notion Token ──
if [ -z "${NOTION_TOKEN:-}" ]; then
  NOTION_TOKEN=$(prompt "Notion Integration Token (sk-...)")
  export NOTION_TOKEN
  PROFILE="${SHELL_PROFILE:-$HOME/.bashrc}"
  echo "export NOTION_TOKEN='${NOTION_TOKEN}'" >> "$PROFILE"
  printf "→ NOTION_TOKEN 已写入 %s\n" "$PROFILE" >&2
else
  printf "→ 使用已有 NOTION_TOKEN\n" >&2
fi

# ── Project settings ──
NOTION_PAGE_ID=$(prompt "Notion 父页面 ID")
PROJECT_NAME=$(prompt "项目名称")
SPRINT_DURATION=$(prompt "Sprint 周期（天）" "14")
SPRINT_CAPACITY=$(prompt "Sprint 容量（任务数）" "10")

printf "\n部署方式：\n  1) github-actions\n  2) script\n  3) manual\n" >&2
DEPLOY_CHOICE=$(prompt "选择" "3")
case "$DEPLOY_CHOICE" in
  1) DEPLOY_METHOD="github-actions"
     DEPLOY_TRIGGER=$(prompt "Workflow 文件路径" ".github/workflows/deploy.yml") ;;
  2) DEPLOY_METHOD="script"
     DEPLOY_TRIGGER=$(prompt "部署脚本路径" "./scripts/deploy.sh") ;;
  *) DEPLOY_METHOD="manual"
     DEPLOY_TRIGGER="" ;;
esac

printf "\n项目类型：\n  A) 全新项目\n  B) 已有项目接入\n" >&2
MODE=$(prompt "选择" "A")
MODE="${MODE^^}"

# ── Pass 1: Create all DBs without relations ──
printf "\n=== 创建 Notion 数据库（第一步：基础结构）===\n" >&2

REQ_PROPS='{"标题":{"title":{}},"状态":{"select":{"options":[{"name":"Inbox"},{"name":"Refined"},{"name":"Ready"},{"name":"In Sprint"},{"name":"Done"}]}},"优先级":{"select":{"options":[{"name":"P0"},{"name":"P1"},{"name":"P2"},{"name":"P3"}]}},"来源":{"select":{"options":[{"name":"Human"},{"name":"Monitor"}]}},"创建时间":{"created_time":{}}}'

SPRINT_PROPS='{"名称":{"title":{}},"状态":{"select":{"options":[{"name":"Planning"},{"name":"Active"},{"name":"Completed"}]}},"开始日期":{"date":{}},"结束日期":{"date":{}},"目标":{"rich_text":{}},"开始说明":{"rich_text":{}},"结束说明":{"rich_text":{}}}'

TASK_PROPS='{"标题":{"title":{}},"状态":{"select":{"options":[{"name":"Todo"},{"name":"Claiming"},{"name":"In Progress"},{"name":"Review"},{"name":"Done"},{"name":"Failed"},{"name":"Blocked"}]}},"类型":{"select":{"options":[{"name":"Dev"},{"name":"Test"},{"name":"Deploy"},{"name":"Monitor"},{"name":"SprintPlan"},{"name":"DailyQuota"}]}},"认领人":{"rich_text":{}},"结果摘要":{"rich_text":{}},"退还原因":{"rich_text":{}},"退还次数":{"number":{"format":"number"}}}'

KNOW_PROPS='{"模块名称":{"title":{}},"功能描述":{"rich_text":{}},"关键文件":{"rich_text":{}},"技术栈":{"rich_text":{}},"类型":{"select":{"options":[{"name":"feature"},{"name":"module"},{"name":"infra"},{"name":"tech-stack"}]}},"最后更新":{"date":{}}}'

DEPLOY_PROPS='{"版本":{"title":{}},"状态":{"select":{"options":[{"name":"Triggered"},{"name":"Success"},{"name":"Failed"}]}},"环境":{"select":{"options":[{"name":"staging"},{"name":"production"}]}},"时间":{"date":{}},"备注":{"rich_text":{}}}'

MONITOR_PROPS='{"名称":{"title":{}},"时间":{"date":{}},"类型":{"select":{"options":[{"name":"heartbeat"},{"name":"finding"}]}},"来源":{"rich_text":{}},"发现内容":{"rich_text":{}},"状态":{"select":{"options":[{"name":"New"},{"name":"Processing"},{"name":"Done"}]}}}'

printf "创建需求库...\n" >&2
DB_REQUIREMENTS_ID=$(notion_create_database "$NOTION_PAGE_ID" "${PROJECT_NAME} 需求库" "$REQ_PROPS" | jq -r '.id')
printf "创建Sprint表...\n" >&2
DB_SPRINTS_ID=$(notion_create_database "$NOTION_PAGE_ID" "${PROJECT_NAME} Sprint表" "$SPRINT_PROPS" | jq -r '.id')
printf "创建任务表...\n" >&2
DB_TASKS_ID=$(notion_create_database "$NOTION_PAGE_ID" "${PROJECT_NAME} 任务表" "$TASK_PROPS" | jq -r '.id')
printf "创建知识库...\n" >&2
DB_KNOWLEDGE_ID=$(notion_create_database "$NOTION_PAGE_ID" "${PROJECT_NAME} 知识库" "$KNOW_PROPS" | jq -r '.id')
printf "创建部署记录...\n" >&2
DB_DEPLOYMENTS_ID=$(notion_create_database "$NOTION_PAGE_ID" "${PROJECT_NAME} 部署记录" "$DEPLOY_PROPS" | jq -r '.id')
printf "创建监控日志...\n" >&2
DB_MONITOR_LOGS_ID=$(notion_create_database "$NOTION_PAGE_ID" "${PROJECT_NAME} 监控日志" "$MONITOR_PROPS" | jq -r '.id')

# ── Pass 2: Add relation properties ──
printf "\n=== 添加数据库关联（第二步）===\n" >&2

notion_update_database "$DB_REQUIREMENTS_ID" \
  "$(jq -n --arg id "$DB_SPRINTS_ID" \
    '{"Sprint":{"relation":{"database_id":$id,"type":"single_property","single_property":{}}}}')" \
  > /dev/null

notion_update_database "$DB_TASKS_ID" \
  "$(jq -n --arg req "$DB_REQUIREMENTS_ID" --arg spr "$DB_SPRINTS_ID" \
    '{"需求":{"relation":{"database_id":$req,"type":"single_property","single_property":{}}},"Sprint":{"relation":{"database_id":$spr,"type":"single_property","single_property":{}}}}')" \
  > /dev/null

notion_update_database "$DB_DEPLOYMENTS_ID" \
  "$(jq -n --arg id "$DB_SPRINTS_ID" \
    '{"Sprint":{"relation":{"database_id":$id,"type":"single_property","single_property":{}}}}')" \
  > /dev/null

notion_update_database "$DB_MONITOR_LOGS_ID" \
  "$(jq -n --arg id "$DB_REQUIREMENTS_ID" \
    '{"需求":{"relation":{"database_id":$id,"type":"single_property","single_property":{}}}}')" \
  > /dev/null

# ── Generate config files ──
printf "\n=== 生成配置文件 ===\n" >&2

mkdir -p "${PROJECT_ROOT}/.sdlc"
jq -n \
  --arg name "$PROJECT_NAME" \
  --arg req "$DB_REQUIREMENTS_ID" \
  --arg spr "$DB_SPRINTS_ID" \
  --arg tsk "$DB_TASKS_ID" \
  --arg kno "$DB_KNOWLEDGE_ID" \
  --arg dep "$DB_DEPLOYMENTS_ID" \
  --arg mon "$DB_MONITOR_LOGS_ID" \
  --argjson dur "$SPRINT_DURATION" \
  --argjson cap "$SPRINT_CAPACITY" \
  --arg method "$DEPLOY_METHOD" \
  --arg trigger "$DEPLOY_TRIGGER" \
  '{
    project_name: $name,
    databases: {
      requirements: $req,
      sprints: $spr,
      tasks: $tsk,
      knowledge: $kno,
      deployments: $dep,
      monitor_logs: $mon
    },
    sprint: {duration_days: $dur, capacity: $cap},
    deploy: {method: $method, trigger: $trigger},
    monitor: {interval_hours: 6, checks: []},
    quota: {daily_task_limit: 10, reset_hour_utc: 0, return_threshold: 3}
  }' > "${PROJECT_ROOT}/.sdlc/config.json"
printf "→ .sdlc/config.json\n" >&2

mkdir -p "${PROJECT_ROOT}/.claude"
printf '{"mcpServers":{"sdlc":{"command":"npx","args":["tsx","mcp/sdlc-mcp/src/index.ts","--config",".sdlc/config.json"]}}}\n' \
  > "${PROJECT_ROOT}/.claude/mcp.json"
printf "→ .claude/mcp.json\n" >&2

mkdir -p "${PROJECT_ROOT}/.gemini"
printf '{"mcpServers":{"sdlc":{"command":"npx","args":["tsx","mcp/sdlc-mcp/src/index.ts","--config",".sdlc/config.json"]}}}\n' \
  > "${PROJECT_ROOT}/.gemini/mcp.json"
printf "→ .gemini/mcp.json\n" >&2

# ── Create initial data ──
printf "\n=== 创建初始数据 ===\n" >&2

SPRINT_START=$(date -u +%Y-%m-%d)
START_TS=$(date -u +%s)
END_TS=$((START_TS + SPRINT_DURATION * 86400))
SPRINT_END=$(date -u -d "@${END_TS}" +%Y-%m-%d 2>/dev/null || date -u -r "${END_TS}" +%Y-%m-%d)

notion_create_page "$DB_SPRINTS_ID" \
  "$(jq -n --arg start "$SPRINT_START" --arg end "$SPRINT_END" \
    '{"名称":{"title":[{"text":{"content":"Sprint-001"}}]},"状态":{"select":{"name":"Planning"}},"开始日期":{"date":{"start":$start}},"结束日期":{"date":{"start":$end}}}')" \
  > /dev/null
printf "→ Sprint-001 (Planning)\n" >&2

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
notion_create_page "$DB_MONITOR_LOGS_ID" \
  "$(jq -n --arg now "$NOW_ISO" \
    '{"名称":{"title":[{"text":{"content":"heartbeat"}}]},"时间":{"date":{"start":$now}},"类型":{"select":{"name":"heartbeat"}},"来源":{"rich_text":[{"text":{"content":"init"}}]},"状态":{"select":{"name":"New"}}}')" \
  > /dev/null
printf "→ 监控日志 heartbeat 记录\n" >&2

printf "\n=== 初始化完成 ===\n" >&2
printf "\n下一步：\n" >&2
printf "  1. 确认 NOTION_TOKEN 已配置（重新加载终端或运行 source ~/.bashrc）\n" >&2
printf "  2. 在 Claude Code 中通过 .claude/mcp.json 加载 MCP Server\n" >&2
printf "  3. 运行 scripts/get-next-work.sh 开始工作\n" >&2
```

- [ ] **Step 4: Make init.sh executable**

```bash
chmod +x scripts/init.sh
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
./tests/bats/bin/bats tests/test-init.bats
```

Expected:
```
✓ init.sh Mode A: 正常退出码 0
✓ init.sh Mode A: 生成 .sdlc/config.json
✓ init.sh Mode A: config.json 包含所有数据库 ID
✓ init.sh Mode A: config.json 包含正确的项目名和 Sprint 配置
✓ init.sh Mode A: 生成 .claude/mcp.json
✓ init.sh Mode A: 生成 .gemini/mcp.json

6 tests, 0 failures
```

- [ ] **Step 6: Run full test suite to confirm no regressions**

```bash
./tests/bats/bin/bats tests/
```

Expected: all tests pass, 0 failures

- [ ] **Step 7: Commit**

```bash
git add scripts/init.sh tests/test-init.bats
git commit -m "feat: implement init.sh Mode A - two-pass DB creation and config generation"
```

---

### Task 3: Add Mode B (existing project) to init.sh

**Files:**
- Modify: `scripts/init.sh`
- Modify: `tests/test-init.bats`

- [ ] **Step 1: Write failing Mode B test**

Append to `tests/test-init.bats`:

```bash
@test "init.sh Mode B: CLAUDE.md 包含已有项目提示" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  # Create stub guide files in tmpdir
  printf "# Existing CLAUDE.md\n" > "$TMPDIR/CLAUDE.md"
  printf "# Existing GEMINI.md\n" > "$TMPDIR/GEMINI.md"
  printf "# Existing AGENTS.md\n" > "$TMPDIR/AGENTS.md"

  run bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nB\n' | PROJECT_ROOT='$TMPDIR' bash scripts/init.sh"
  assert_success
  run grep -c "这是已有项目" "$TMPDIR/CLAUDE.md"
  assert_output "1"
}

@test "init.sh Mode B: GEMINI.md 包含已有项目提示" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  printf "# Existing GEMINI.md\n" > "$TMPDIR/GEMINI.md"

  run bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nB\n' | PROJECT_ROOT='$TMPDIR' bash scripts/init.sh"
  assert_success
  run grep -c "这是已有项目" "$TMPDIR/GEMINI.md"
  assert_output "1"
}

@test "init.sh Mode B: guide 文件不存在时跳过（不报错）" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  # tmpdir has no CLAUDE.md/GEMINI.md/AGENTS.md
  run bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nB\n' | PROJECT_ROOT='$TMPDIR' bash scripts/init.sh"
  assert_success
}

@test "init.sh Mode A: CLAUDE.md 不包含已有项目提示" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  printf "# Existing CLAUDE.md\n" > "$TMPDIR/CLAUDE.md"

  run bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR' bash scripts/init.sh"
  assert_success
  run grep -c "这是已有项目" "$TMPDIR/CLAUDE.md" || true
  assert_output "0"
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
./tests/bats/bin/bats tests/test-init.bats -t "Mode B"
```

Expected: FAIL (Mode B not yet implemented)

- [ ] **Step 3: Add Mode B logic to init.sh**

In `scripts/init.sh`, add the following block **after** the `.gemini/mcp.json` generation step and **before** the "Create initial data" section:

```bash
# ── Mode B: mark guide files ──
if [ "$MODE" = "B" ]; then
  MARKER=$'\n\n> **已有项目提示：** 这是已有项目，首次启动前必须先读取知识库（`get_project_knowledge()`），了解现有功能后再开始工作。\n'
  for guide in CLAUDE.md GEMINI.md AGENTS.md; do
    if [ -f "${PROJECT_ROOT}/${guide}" ]; then
      printf "%s" "$MARKER" >> "${PROJECT_ROOT}/${guide}"
      printf "→ 已标注 %s\n" "$guide" >&2
    fi
  done
fi
```

Also add Mode B guidance to the final output block (after the existing `printf` steps at the end of the file):

```bash
if [ "$MODE" = "B" ]; then
  printf "\n  ⚠️  已有项目：第一个 Agent 启动时先执行 skills/bootstrap.md 扫描代码库\n" >&2
fi
```

- [ ] **Step 4: Run Mode B tests to confirm they pass**

```bash
./tests/bats/bin/bats tests/test-init.bats -t "Mode B"
./tests/bats/bin/bats tests/test-init.bats -t "Mode A: CLAUDE.md 不包含"
```

Expected: all 4 new tests PASS

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
./tests/bats/bin/bats tests/
```

Expected: all tests pass, 0 failures

- [ ] **Step 6: Commit**

```bash
git add scripts/init.sh tests/test-init.bats
git commit -m "feat: add init.sh Mode B - mark guide files for existing project onboarding"
```

---

## Self-Review

### Spec Coverage

| Spec Requirement | Task |
|---|---|
| 调用 Notion API 创建六张数据库 | Task 2 (init.sh Pass 1) |
| 数据库间 Relation 属性 | Task 2 (init.sh Pass 2) |
| 生成 .sdlc/config.json | Task 2 |
| 按工具写入 MCP 配置文件 | Task 2 (.claude/mcp.json, .gemini/mcp.json) |
| 创建第一个 Sprint 记录（Planning）| Task 2 |
| 在监控日志库创建 heartbeat 记录 | Task 2 |
| 交互式输入项目名/周期/容量/部署方式 | Task 2 |
| NOTION_TOKEN 不写入文件 | Task 2 (written to shell profile, never to project files) |
| 模式 B：标注已有项目提示 | Task 3 |
| notion_create_database / notion_update_database functions | Task 1 |

### Type Consistency

- `notion_create_database(parent_page_id, title, properties_json)` → used in Task 2 init.sh with same signature
- `notion_update_database(db_id, properties_json)` → used in Task 2 init.sh with same signature
- `notion_create_page(db_id, properties)` → existing function, used in Task 2 for Sprint and heartbeat

### DB Field Names Match Existing Scripts

The following field names must match what `monitor-check.sh` expects:
- Monitor Log DB: `时间` (date), `类型` (select), `来源` (rich_text) — confirmed against `monitor-check.sh:30-36`
- Requirements DB: `标题` (title), `状态` (select), `来源` (select) — confirmed against `monitor-check.sh:110-116`
- Config key `monitor_logs` → loaded as `DB_MONITOR_LOGS` by `load_config` → used in `monitor-check.sh:31` ✓
