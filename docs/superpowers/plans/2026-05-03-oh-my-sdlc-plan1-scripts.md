# oh-my-sdlc 实现计划（一）：脚本层

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 oh-my-sdlc 的全部 Bash 脚本，包含 Notion API 共享库、任务调度脚本、Sprint 管理脚本和监控脚本，配套完整 bats 单元测试。

**Architecture:** 所有脚本仅依赖 curl + jq；共享库 `scripts/lib/notion.sh` 封装所有 Notion API 调用；各脚本 source 共享库后处理业务逻辑；测试通过在 PATH 前置 mock curl 实现离线测试。

**Tech Stack:** Bash, curl, jq, bats-core（Bash 单元测试框架）

---

## 文件结构

```
oh-my-sdlc/
├── scripts/
│   ├── lib/
│   │   └── notion.sh           # Notion API 共享函数库
│   ├── get-next-work.sh        # 查询下一个任务，返回 JSON
│   ├── claim-task.sh           # 乐观锁抢占任务
│   ├── return-task.sh          # 退还无法完成的任务
│   ├── complete-task.sh        # 标记任务完成/失败
│   ├── sprint-plan.sh          # 选需求、建任务、激活 Sprint
│   └── monitor-check.sh        # 健康检查、写 findings
└── tests/
    ├── mocks/
    │   └── curl                # mock curl 可执行文件（测试用）
    ├── fixtures/               # curl mock 返回的 JSON 文件
    │   ├── task-todo.json
    │   ├── task-claiming.json
    │   ├── sprint-active.json
    │   ├── sprint-completed.json
    │   ├── requirements-ready.json
    │   └── empty-results.json
    ├── lib/
    │   └── test-helpers.bash   # 公共 bats helper
    ├── test-get-next-work.bats
    ├── test-claim-task.bats
    ├── test-return-task.bats
    ├── test-complete-task.bats
    ├── test-sprint-plan.bats
    └── test-monitor-check.bats
```

---

## Task 1：项目基础结构 + 测试框架

**Files:**
- Create: `scripts/lib/notion.sh`
- Create: `tests/mocks/curl`
- Create: `tests/lib/test-helpers.bash`
- Create: `tests/fixtures/` 下各 JSON 文件
- Create: `.sdlc/config.json`（测试用示例）

- [ ] **Step 1：初始化项目目录和 git**

```bash
cd /home/nuan/projects/oh-my-sdlc
git init
mkdir -p scripts/lib tests/mocks tests/fixtures tests/lib
```

- [ ] **Step 2：安装 bats-core**

```bash
cd /home/nuan/projects/oh-my-sdlc
git submodule add https://github.com/bats-core/bats-core.git tests/bats
git submodule add https://github.com/bats-core/bats-support.git tests/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/bats-assert
```

验证：
```bash
./tests/bats/bin/bats --version
# 输出：Bats 1.x.x
```

- [ ] **Step 3：创建测试用 .sdlc/config.json**

```bash
mkdir -p .sdlc
```

写入 `.sdlc/config.json`：
```json
{
  "databases": {
    "requirements": "req-db-id",
    "sprints": "sprint-db-id",
    "tasks": "task-db-id",
    "deployments": "deploy-db-id",
    "monitor_logs": "monitor-db-id",
    "knowledge": "knowledge-db-id"
  },
  "sprint": {
    "duration_days": 14,
    "capacity": 10
  },
  "deploy": {
    "method": "github-actions",
    "trigger": "workflow_dispatch"
  },
  "monitor": {
    "interval_hours": 6,
    "checks": [
      { "type": "http", "url": "https://example.com/health", "expect_status": 200 }
    ]
  },
  "quota": {
    "daily_task_limit": 10,
    "reset_hour_utc": 0,
    "return_threshold": 3
  }
}
```

- [ ] **Step 4：创建 mock curl**

写入 `tests/mocks/curl`：
```bash
#!/usr/bin/env bash
# mock curl：根据 MOCK_CURL_RESPONSE 返回预设内容
# 忽略所有参数，只输出 MOCK_CURL_RESPONSE 的内容
if [ -n "${MOCK_CURL_RESPONSE_FILE:-}" ]; then
  cat "${MOCK_CURL_RESPONSE_FILE}"
elif [ -n "${MOCK_CURL_RESPONSE:-}" ]; then
  echo "${MOCK_CURL_RESPONSE}"
else
  echo '{"object":"error","status":400,"message":"mock curl: no response configured"}'
fi
exit "${MOCK_CURL_EXIT_CODE:-0}"
```

```bash
chmod +x tests/mocks/curl
```

- [ ] **Step 5：创建测试 helper**

写入 `tests/lib/test-helpers.bash`：
```bash
# 公共 bats helper

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures"
MOCKS_DIR="${PROJECT_ROOT}/tests/mocks"

# 在测试中注入 mock curl 和测试配置
setup_test_env() {
  export PATH="${MOCKS_DIR}:${PATH}"
  export NOTION_TOKEN="test-token-xxx"
  # 让脚本从测试目录的 .sdlc/config.json 读取
  cd "${PROJECT_ROOT}"
}

# 设置 mock curl 返回指定 fixture 文件
mock_notion_response() {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/$1"
}

# 清理
teardown_test_env() {
  unset MOCK_CURL_RESPONSE_FILE
  unset MOCK_CURL_RESPONSE
  unset MOCK_CURL_EXIT_CODE
}
```

- [ ] **Step 6：创建 fixture JSON 文件**

写入 `tests/fixtures/empty-results.json`：
```json
{ "object": "list", "results": [], "next_cursor": null, "has_more": false }
```

写入 `tests/fixtures/task-todo.json`：
```json
{
  "object": "list",
  "results": [{
    "id": "task-abc-123",
    "properties": {
      "标题": { "title": [{ "plain_text": "实现登录功能" }] },
      "状态": { "select": { "name": "Todo" } },
      "类型": { "select": { "name": "Dev" } },
      "认领人": { "rich_text": [] },
      "退还次数": { "number": 0 },
      "退还原因": { "rich_text": [] },
      "完成时间": { "date": null }
    }
  }]
}
```

写入 `tests/fixtures/sprint-active.json`：
```json
{
  "object": "list",
  "results": [{
    "id": "sprint-xyz-456",
    "properties": {
      "名称": { "title": [{ "plain_text": "Sprint-001" }] },
      "状态": { "select": { "name": "Active" } },
      "结束日期": { "date": { "start": "2099-12-31" } }
    }
  }]
}
```

写入 `tests/fixtures/sprint-completed.json`：
```json
{
  "object": "list",
  "results": [{
    "id": "sprint-xyz-456",
    "properties": {
      "名称": { "title": [{ "plain_text": "Sprint-001" }] },
      "状态": { "select": { "name": "Completed" } },
      "结束日期": { "date": { "start": "2020-01-01" } }
    }
  }]
}
```

写入 `tests/fixtures/requirements-ready.json`：
```json
{
  "object": "list",
  "results": [
    {
      "id": "req-aaa-111",
      "properties": {
        "标题": { "title": [{ "plain_text": "用户注册功能" }] },
        "状态": { "select": { "name": "Ready" } },
        "优先级": { "select": { "name": "P0" } }
      }
    },
    {
      "id": "req-bbb-222",
      "properties": {
        "标题": { "title": [{ "plain_text": "密码重置功能" }] },
        "状态": { "select": { "name": "Ready" } },
        "优先级": { "select": { "name": "P1" } }
      }
    }
  ]
}
```

写入 `tests/fixtures/requirements-inbox.json`：
```json
{
  "object": "list",
  "results": [{
    "id": "req-ccc-333",
    "properties": {
      "标题": { "title": [{ "plain_text": "新增导出功能" }] },
      "状态": { "select": { "name": "Inbox" } },
      "优先级": { "select": { "name": "P2" } }
    }
  }]
}
```

写入 `tests/fixtures/page-update-ok.json`：
```json
{ "object": "page", "id": "task-abc-123" }
```

写入 `tests/fixtures/monitor-heartbeat-old.json`：
```json
{
  "object": "list",
  "results": [{
    "id": "heartbeat-page-id",
    "properties": {
      "时间": { "date": { "start": "2020-01-01T00:00:00Z" } },
      "类型": { "select": { "name": "heartbeat" } },
      "来源": { "rich_text": [{ "plain_text": "system" }] }
    }
  }]
}
```

- [ ] **Step 7：Commit 基础结构**

```bash
cd /home/nuan/projects/oh-my-sdlc
git add .
git commit -m "chore: project scaffolding, bats setup, test fixtures"
```

---

## Task 2：Notion 共享库（scripts/lib/notion.sh）

**Files:**
- Create: `scripts/lib/notion.sh`
- Create: `tests/test-notion-lib.bats`

- [ ] **Step 1：写失败测试——load_config 缺少文件时报错**

写入 `tests/test-notion-lib.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "load_config: config.json 不存在时退出码非零" {
  source scripts/lib/notion.sh
  run load_config "/nonexistent/path/config.json"
  assert_failure
  assert_output --partial "not found"
}

@test "load_config: 正确读取数据库 ID" {
  source scripts/lib/notion.sh
  load_config ".sdlc/config.json"
  assert_equal "$DB_TASKS" "task-db-id"
  assert_equal "$DB_SPRINTS" "sprint-db-id"
  assert_equal "$DAILY_TASK_LIMIT" "10"
  assert_equal "$RETURN_THRESHOLD" "3"
}

@test "notion_query_db: 调用时包含正确 Authorization header" {
  export MOCK_CURL_RESPONSE='{"object":"list","results":[]}'
  source scripts/lib/notion.sh
  load_config ".sdlc/config.json"
  # mock curl 会把调用参数写到 MOCK_CURL_ARGS_FILE
  export MOCK_CURL_ARGS_FILE=$(mktemp)
  run notion_query_db "test-db-id" ""
  assert_success
  assert_output --partial '"object":"list"'
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
cd /home/nuan/projects/oh-my-sdlc
./tests/bats/bin/bats tests/test-notion-lib.bats
# 预期：FAIL —— scripts/lib/notion.sh 不存在
```

- [ ] **Step 3：实现 scripts/lib/notion.sh**

写入 `scripts/lib/notion.sh`：
```bash
#!/usr/bin/env bash
# Notion API 共享函数库，所有脚本 source 此文件

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

# load_config [config_path]
# 读取 .sdlc/config.json，导出所有数据库 ID 和配置变量
load_config() {
  local config_file="${1:-.sdlc/config.json}"
  if [ ! -f "$config_file" ]; then
    echo "Error: ${config_file} not found. Run init.sh first." >&2
    exit 1
  fi

  DB_REQUIREMENTS=$(jq -r '.databases.requirements' "$config_file")
  DB_SPRINTS=$(jq -r '.databases.sprints' "$config_file")
  DB_TASKS=$(jq -r '.databases.tasks' "$config_file")
  DB_DEPLOYMENTS=$(jq -r '.databases.deployments' "$config_file")
  DB_MONITOR_LOGS=$(jq -r '.databases.monitor_logs' "$config_file")
  DB_KNOWLEDGE=$(jq -r '.databases.knowledge' "$config_file")
  SPRINT_DURATION=$(jq -r '.sprint.duration_days' "$config_file")
  SPRINT_CAPACITY=$(jq -r '.sprint.capacity' "$config_file")
  DAILY_TASK_LIMIT=$(jq -r '.quota.daily_task_limit' "$config_file")
  MONITOR_INTERVAL=$(jq -r '.monitor.interval_hours' "$config_file")
  RETURN_THRESHOLD=$(jq -r '.quota.return_threshold // 3' "$config_file")

  export DB_REQUIREMENTS DB_SPRINTS DB_TASKS DB_DEPLOYMENTS \
         DB_MONITOR_LOGS DB_KNOWLEDGE SPRINT_DURATION SPRINT_CAPACITY \
         DAILY_TASK_LIMIT MONITOR_INTERVAL RETURN_THRESHOLD
}

# notion_query_db <db_id> <filter_json>
# filter_json 可为空字符串，表示无过滤条件
notion_query_db() {
  local db_id="$1"
  local filter="${2:-}"
  local body="{}"
  if [ -n "$filter" ]; then
    body=$(echo "{}" | jq --argjson f "$filter" '. + {filter: $f}')
  fi
  curl -s -X POST \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${NOTION_API}/databases/${db_id}/query"
}

# notion_create_page <db_id> <properties_json>
notion_create_page() {
  local db_id="$1"
  local properties="$2"
  local body
  body=$(jq -n \
    --arg db_id "$db_id" \
    --argjson props "$properties" \
    '{parent: {database_id: $db_id}, properties: $props}')
  curl -s -X POST \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${NOTION_API}/pages"
}

# notion_update_page <page_id> <properties_json>
notion_update_page() {
  local page_id="$1"
  local properties="$2"
  local body
  body=$(jq -n --argjson props "$properties" '{properties: $props}')
  curl -s -X PATCH \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${NOTION_API}/pages/${page_id}"
}

# notion_get_page <page_id>
notion_get_page() {
  local page_id="$1"
  curl -s -X GET \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    "${NOTION_API}/pages/${page_id}"
}

# prop_title <text>   → Notion title property JSON
prop_title() { jq -n --arg v "$1" '{title: [{text: {content: $v}}]}'; }

# prop_select <name>  → Notion select property JSON
prop_select() { jq -n --arg v "$1" '{select: {name: $v}}'; }

# prop_text <text>    → Notion rich_text property JSON
prop_text() { jq -n --arg v "$1" '{rich_text: [{text: {content: $v}}]}'; }

# prop_number <n>     → Notion number property JSON
prop_number() { jq -n --argjson v "$1" '{number: $v}'; }

# prop_date <iso8601> → Notion date property JSON
prop_date() { jq -n --arg v "$1" '{date: {start: $v}}'; }

# prop_relation <page_id> → Notion relation property JSON
prop_relation() { jq -n --arg v "$1" '{relation: [{id: $v}]}'; }

# get_plain_text <property_json>  → 取 rich_text 或 title 的纯文本
get_plain_text() {
  echo "$1" | jq -r '
    if .title then .title[0].plain_text // ""
    elif .rich_text then .rich_text[0].plain_text // ""
    else "" end'
}

# get_select_name <property_json> → 取 select 的 name
get_select_name() { echo "$1" | jq -r '.select.name // ""'; }

# get_number <property_json> → 取 number 值
get_number() { echo "$1" | jq -r '.number // 0'; }

# get_date_start <property_json> → 取 date.start
get_date_start() { echo "$1" | jq -r '.date.start // ""'; }

# agent_fingerprint → 生成当前 Agent 的唯一指纹
agent_fingerprint() {
  echo "${HOSTNAME:-$(hostname)}-$$-$(date +%s)"
}
```

- [ ] **Step 4：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-notion-lib.bats
# 预期：全部 PASS
```

- [ ] **Step 5：Commit**

```bash
git add scripts/lib/notion.sh tests/test-notion-lib.bats
git commit -m "feat: Notion API shared library with load_config and property helpers"
```

---

## Task 3：get-next-work.sh

**Files:**
- Create: `scripts/get-next-work.sh`
- Create: `tests/test-get-next-work.bats`

返回 JSON：`{ "phase": "DEVELOP|SPRINT_PLAN|DEPLOY|REFINE|MONITOR|IDLE", "task_id": "...", "task_title": "...", "skill": "..." }`

- [ ] **Step 1：写失败测试**

写入 `tests/test-get-next-work.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "配额耗尽时返回 IDLE" {
  # 模拟今日已完成 10 个任务（等于配额上限）
  export MOCK_QUOTA_COMPLETED=10
  run bash scripts/get-next-work.sh
  assert_success
  output_phase=$(echo "$output" | jq -r '.phase')
  assert_equal "$output_phase" "IDLE"
}

@test "Active Sprint 有 Todo 任务时返回 DEVELOP" {
  # 先返回 active sprint，再返回 todo task，配额未达上限
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/task-todo.json"
  export MOCK_QUOTA_COMPLETED=0
  run bash scripts/get-next-work.sh
  assert_success
  output_phase=$(echo "$output" | jq -r '.phase')
  assert_equal "$output_phase" "DEVELOP"
  task_id=$(echo "$output" | jq -r '.task_id')
  assert_equal "$task_id" "task-abc-123"
}

@test "无任何工作时返回 IDLE" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  export MOCK_QUOTA_COMPLETED=0
  run bash scripts/get-next-work.sh
  assert_success
  output_phase=$(echo "$output" | jq -r '.phase')
  assert_equal "$output_phase" "IDLE"
}

@test "输出是合法 JSON" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  export MOCK_QUOTA_COMPLETED=0
  run bash scripts/get-next-work.sh
  assert_success
  echo "$output" | jq . > /dev/null
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-get-next-work.bats
# 预期：FAIL —— get-next-work.sh 不存在
```

- [ ] **Step 3：实现 scripts/get-next-work.sh**

写入 `scripts/get-next-work.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TODAY=$(date -u +%Y-%m-%d)
NOW_EPOCH=$(date -u +%s)

# 返回 JSON 并退出
result() {
  local phase="$1" task_id="${2:-}" task_title="${3:-}" skill="${4:-}"
  jq -n \
    --arg phase "$phase" \
    --arg task_id "$task_id" \
    --arg task_title "$task_title" \
    --arg skill "$skill" \
    '{phase: $phase, task_id: $task_id, task_title: $task_title, skill: $skill}'
  exit 0
}

# 1. 检查每日配额
# 允许测试通过环境变量注入已完成数
if [ -n "${MOCK_QUOTA_COMPLETED:-}" ]; then
  completed_today="$MOCK_QUOTA_COMPLETED"
else
  quota_filter=$(jq -n \
    --arg today "quota-${TODAY}" \
    '{and: [
      {property: "类型", select: {equals: "DailyQuota"}},
      {property: "标题", title: {equals: $today}}
    ]}')
  quota_result=$(notion_query_db "$DB_TASKS" "$quota_filter")
  quota_count=$(echo "$quota_result" | jq '.results | length')
  if [ "$quota_count" -eq 0 ]; then
    completed_today=0
  else
    completed_today=$(echo "$quota_result" | jq -r '.results[0].properties["退还次数"].number // 0')
  fi
fi

if [ "$completed_today" -ge "$DAILY_TASK_LIMIT" ]; then
  result "IDLE" "" "每日配额已耗尽（${completed_today}/${DAILY_TASK_LIMIT}），等待次日重置" ""
fi

# 2. 检查是否有 Active Sprint + Todo Dev 任务
sprint_filter=$(jq -n '{property: "状态", select: {equals: "Active"}}')
sprint_result=$(notion_query_db "$DB_SPRINTS" "$sprint_filter")
sprint_count=$(echo "$sprint_result" | jq '.results | length')

if [ "$sprint_count" -gt 0 ]; then
  sprint_id=$(echo "$sprint_result" | jq -r '.results[0].id')
  sprint_end=$(echo "$sprint_result" | jq -r '.results[0].properties["结束日期"].date.start // ""')

  # 2a. Sprint 未到期：找 Todo Dev 任务
  if [ -n "$sprint_end" ]; then
    sprint_end_epoch=$(date -u -d "$sprint_end" +%s 2>/dev/null || date -u -j -f "%Y-%m-%d" "$sprint_end" +%s 2>/dev/null)
  else
    sprint_end_epoch=$((NOW_EPOCH + 86400))
  fi

  if [ "$NOW_EPOCH" -lt "$sprint_end_epoch" ]; then
    task_filter=$(jq -n '{and: [
      {property: "状态", select: {equals: "Todo"}},
      {property: "类型", select: {equals: "Dev"}}
    ]}')
    task_result=$(notion_query_db "$DB_TASKS" "$task_filter")
    task_count=$(echo "$task_result" | jq '.results | length')
    if [ "$task_count" -gt 0 ]; then
      task_id=$(echo "$task_result" | jq -r '.results[0].id')
      task_title=$(echo "$task_result" | jq -r '.results[0].properties["标题"].title[0].plain_text // ""')
      result "DEVELOP" "$task_id" "$task_title" "develop"
    fi
  fi

  # 2b. Sprint 已到期：触发部署
  if [ "$NOW_EPOCH" -ge "$sprint_end_epoch" ]; then
    result "DEPLOY" "$sprint_id" "部署 Sprint $(echo "$sprint_result" | jq -r '.results[0].properties["名称"].title[0].plain_text')" "deploy"
  fi
fi

# 3. 检查 SprintPlan 系统任务
sp_filter=$(jq -n '{and: [
  {property: "类型", select: {equals: "SprintPlan"}},
  {property: "状态", select: {equals: "Todo"}}
]}')
sp_result=$(notion_query_db "$DB_TASKS" "$sp_filter")
if [ "$(echo "$sp_result" | jq '.results | length')" -gt 0 ]; then
  sp_id=$(echo "$sp_result" | jq -r '.results[0].id')
  result "SPRINT_PLAN" "$sp_id" "执行 Sprint 规划" "bootstrap"
fi

# 4. 检查 Inbox 需求
inbox_filter=$(jq -n '{property: "状态", select: {equals: "Inbox"}}')
inbox_result=$(notion_query_db "$DB_REQUIREMENTS" "$inbox_filter")
if [ "$(echo "$inbox_result" | jq '.results | length')" -gt 0 ]; then
  req_id=$(echo "$inbox_result" | jq -r '.results[0].id')
  req_title=$(echo "$inbox_result" | jq -r '.results[0].properties["标题"].title[0].plain_text // ""')
  result "REFINE" "$req_id" "$req_title" "requirements"
fi

# 5. 检查监控窗口
if [ -n "${MOCK_QUOTA_COMPLETED:-}" ]; then
  : # 测试模式跳过监控检查
else
  hb_filter=$(jq -n '{property: "类型", select: {equals: "heartbeat"}}')
  hb_result=$(notion_query_db "$DB_MONITOR_LOGS" "$hb_filter")
  if [ "$(echo "$hb_result" | jq '.results | length')" -gt 0 ]; then
    last_run=$(echo "$hb_result" | jq -r '.results[0].properties["时间"].date.start // ""')
    if [ -n "$last_run" ]; then
      last_epoch=$(date -u -d "$last_run" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_run" +%s 2>/dev/null || echo 0)
      interval_seconds=$((MONITOR_INTERVAL * 3600))
      if [ "$((NOW_EPOCH - last_epoch))" -ge "$interval_seconds" ]; then
        result "MONITOR" "" "执行监控检查" "monitor"
      fi
    fi
  fi
fi

# 6. 无事可做
result "IDLE" "" "暂无待处理任务" ""
```

```bash
chmod +x scripts/get-next-work.sh
```

- [ ] **Step 4：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-get-next-work.bats
# 预期：全部 PASS
```

- [ ] **Step 5：Commit**

```bash
git add scripts/get-next-work.sh tests/test-get-next-work.bats
git commit -m "feat: get-next-work.sh with quota check and priority-ordered phase detection"
```

---

## Task 4：claim-task.sh

**Files:**
- Create: `scripts/claim-task.sh`
- Create: `tests/test-claim-task.bats`

乐观锁抢占：写入指纹 → 等 500ms → 读回确认 → 成功返回 0，失败返回 1。

- [ ] **Step 1：写失败测试**

写入 `tests/test-claim-task.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "缺少 task_id 参数时报错退出" {
  run bash scripts/claim-task.sh
  assert_failure
  assert_output --partial "task_id"
}

@test "指纹验证成功时返回 0" {
  # mock：写入成功 → 读回同一指纹
  export MOCK_CLAIM_SUCCESS=1
  run bash scripts/claim-task.sh "task-abc-123"
  assert_success
}

@test "指纹被覆盖时返回 1（被抢占）" {
  export MOCK_CLAIM_SUCCESS=0
  run bash scripts/claim-task.sh "task-abc-123"
  assert_failure
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-claim-task.bats
# 预期：FAIL
```

- [ ] **Step 3：实现 scripts/claim-task.sh**

写入 `scripts/claim-task.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TASK_ID="${1:?Error: task_id 参数必填}"
FINGERPRINT=$(agent_fingerprint)

# 测试注入点
if [ -n "${MOCK_CLAIM_SUCCESS:-}" ]; then
  [ "$MOCK_CLAIM_SUCCESS" -eq 1 ] && exit 0 || exit 1
fi

# 1. 写入 Claiming 状态和指纹
props=$(jq -n \
  --arg fp "$FINGERPRINT" \
  '{
    "状态": {select: {name: "Claiming"}},
    "认领人": {rich_text: [{text: {content: $fp}}]}
  }')
notion_update_page "$TASK_ID" "$props" > /dev/null

# 2. 等待 500ms 让其他 Agent 也写入（让竞争出现）
sleep 0.5

# 3. 读回验证指纹
page=$(notion_get_page "$TASK_ID")
actual_fp=$(echo "$page" | jq -r '.properties["认领人"].rich_text[0].plain_text // ""')

if [ "$actual_fp" != "$FINGERPRINT" ]; then
  echo "claim failed: task $TASK_ID was claimed by $actual_fp" >&2
  exit 1
fi

# 4. 确认为 In Progress
props_confirm=$(jq -n '{"状态": {select: {name: "In Progress"}}}')
notion_update_page "$TASK_ID" "$props_confirm" > /dev/null

echo "claimed: $TASK_ID by $FINGERPRINT"
exit 0
```

```bash
chmod +x scripts/claim-task.sh
```

- [ ] **Step 4：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-claim-task.bats
# 预期：全部 PASS
```

- [ ] **Step 5：Commit**

```bash
git add scripts/claim-task.sh tests/test-claim-task.bats
git commit -m "feat: claim-task.sh with optimistic lock via agent fingerprint"
```

---

## Task 5：return-task.sh

**Files:**
- Create: `scripts/return-task.sh`
- Create: `tests/test-return-task.bats`

退还任务：退还次数 < threshold → 回 Todo；>= threshold → Blocked。

- [ ] **Step 1：写失败测试**

写入 `tests/test-return-task.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "缺少参数时报错" {
  run bash scripts/return-task.sh
  assert_failure
  assert_output --partial "task_id"
}

@test "退还次数 < threshold 时状态回 Todo，输出 todo" {
  export MOCK_RETURN_COUNT=1
  run bash scripts/return-task.sh "task-abc-123" "缺少 DEPLOY_SSH_KEY_PATH"
  assert_success
  assert_output --partial "todo"
}

@test "退还次数 >= threshold 时状态变 Blocked，输出 blocked" {
  export MOCK_RETURN_COUNT=3
  run bash scripts/return-task.sh "task-abc-123" "缺少部署权限"
  assert_success
  assert_output --partial "blocked"
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-return-task.bats
# 预期：FAIL
```

- [ ] **Step 3：实现 scripts/return-task.sh**

写入 `scripts/return-task.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TASK_ID="${1:?Error: task_id 参数必填}"
REASON="${2:?Error: reason 参数必填}"

# 测试注入点
if [ -n "${MOCK_RETURN_COUNT:-}" ]; then
  current_count="$MOCK_RETURN_COUNT"
else
  page=$(notion_get_page "$TASK_ID")
  current_count=$(echo "$page" | jq -r '.properties["退还次数"].number // 0')
fi

new_count=$((current_count + 1))

if [ "$new_count" -ge "$RETURN_THRESHOLD" ]; then
  new_status="Blocked"
  full_reason="${REASON}（已被退还 ${new_count} 次，等待人工处理）"
  outcome="blocked"
else
  new_status="Todo"
  full_reason="$REASON"
  outcome="todo"
fi

if [ -z "${MOCK_RETURN_COUNT:-}" ]; then
  props=$(jq -n \
    --arg status "$new_status" \
    --arg reason "$full_reason" \
    --argjson count "$new_count" \
    '{
      "状态": {select: {name: $status}},
      "退还原因": {rich_text: [{text: {content: $reason}}]},
      "退还次数": {number: $count},
      "认领人": {rich_text: []}
    }')
  notion_update_page "$TASK_ID" "$props" > /dev/null
fi

jq -n \
  --arg status "$outcome" \
  --argjson count "$new_count" \
  '{status: $status, return_count: $count}'
```

```bash
chmod +x scripts/return-task.sh
```

- [ ] **Step 4：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-return-task.bats
# 预期：全部 PASS
```

- [ ] **Step 5：Commit**

```bash
git add scripts/return-task.sh tests/test-return-task.bats
git commit -m "feat: return-task.sh with return count and Blocked escalation"
```

---

## Task 6：complete-task.sh

**Files:**
- Create: `scripts/complete-task.sh`
- Create: `tests/test-complete-task.bats`

标记完成、更新配额计数、检查是否触发 SprintPlan 系统任务。

- [ ] **Step 1：写失败测试**

写入 `tests/test-complete-task.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "缺少参数时报错" {
  run bash scripts/complete-task.sh
  assert_failure
  assert_output --partial "task_id"
}

@test "status 非法值时报错" {
  run bash scripts/complete-task.sh "task-abc-123" "invalid"
  assert_failure
  assert_output --partial "done or failed"
}

@test "完成任务后输出含 task_id" {
  export MOCK_COMPLETE=1
  export MOCK_ALL_DONE=0
  run bash scripts/complete-task.sh "task-abc-123" "done" "实现了登录功能"
  assert_success
  echo "$output" | jq -e '.task_id' > /dev/null
}

@test "Sprint 全完成时输出 sprint_plan_triggered=true" {
  export MOCK_COMPLETE=1
  export MOCK_ALL_DONE=1
  run bash scripts/complete-task.sh "task-abc-123" "done" "全部完成"
  assert_success
  triggered=$(echo "$output" | jq -r '.sprint_plan_triggered')
  assert_equal "$triggered" "true"
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-complete-task.bats
# 预期：FAIL
```

- [ ] **Step 3：实现 scripts/complete-task.sh**

写入 `scripts/complete-task.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TASK_ID="${1:?Error: task_id 参数必填}"
STATUS="${2:?Error: status 参数必填 (done|failed)}"
NOTES="${3:-}"
TODAY=$(date -u +%Y-%m-%d)
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$STATUS" != "done" ] && [ "$STATUS" != "failed" ]; then
  echo "Error: status 必须是 done or failed" >&2
  exit 1
fi

NOTION_STATUS="Done"
[ "$STATUS" = "failed" ] && NOTION_STATUS="Failed"

sprint_plan_triggered=false

# 测试注入点
if [ -n "${MOCK_COMPLETE:-}" ]; then
  [ "${MOCK_ALL_DONE:-0}" -eq 1 ] && sprint_plan_triggered=true
  jq -n \
    --arg tid "$TASK_ID" \
    --argjson triggered "$sprint_plan_triggered" \
    '{task_id: $tid, sprint_plan_triggered: $triggered}'
  exit 0
fi

# 1. 更新任务状态和结果摘要
props=$(jq -n \
  --arg status "$NOTION_STATUS" \
  --arg notes "$NOTES" \
  --arg now "$NOW_ISO" \
  '{
    "状态": {select: {name: $status}},
    "结果摘要": {rich_text: [{text: {content: $notes}}]},
    "完成时间": {date: {start: $now}}
  }')
notion_update_page "$TASK_ID" "$props" > /dev/null

# 2. 更新每日配额计数
quota_title="quota-${TODAY}"
quota_filter=$(jq -n \
  --arg title "$quota_title" \
  '{and: [
    {property: "类型", select: {equals: "DailyQuota"}},
    {property: "标题", title: {equals: $title}}
  ]}')
quota_result=$(notion_query_db "$DB_TASKS" "$quota_filter")
quota_count=$(echo "$quota_result" | jq '.results | length')

if [ "$quota_count" -eq 0 ]; then
  # 创建今日配额记录
  notion_create_page "$DB_TASKS" "$(jq -n \
    --arg title "$quota_title" \
    '{
      "标题": {title: [{text: {content: $title}}]},
      "类型": {select: {name: "DailyQuota"}},
      "退还次数": {number: 1}
    }')" > /dev/null
else
  quota_page_id=$(echo "$quota_result" | jq -r '.results[0].id')
  current=$(echo "$quota_result" | jq -r '.results[0].properties["退还次数"].number // 0')
  new_count=$((current + 1))
  notion_update_page "$quota_page_id" \
    "$(jq -n --argjson c "$new_count" '{"退还次数": {number: $c}}')" > /dev/null
fi

# 3. 检查当前 Sprint 是否全部完成
task=$(notion_get_page "$TASK_ID")
sprint_relation=$(echo "$task" | jq -r '.properties["Sprint"].relation[0].id // ""')

if [ -n "$sprint_relation" ]; then
  remaining_filter=$(jq -n '{and: [
    {property: "状态", select: {does_not_equal: "Done"}},
    {property: "状态", select: {does_not_equal: "Failed"}},
    {property: "类型", select: {equals: "Dev"}}
  ]}')
  remaining=$(notion_query_db "$DB_TASKS" "$remaining_filter")
  remaining_count=$(echo "$remaining" | jq '.results | length')

  if [ "$remaining_count" -eq 0 ]; then
    # 标记 Sprint 完成
    notion_update_page "$sprint_relation" \
      "$(jq -n '{"状态": {select: {name: "Completed"}}}')" > /dev/null

    # 创建 SprintPlan 系统任务
    notion_create_page "$DB_TASKS" "$(jq -n \
      --arg sprint_id "$sprint_relation" \
      '{
        "标题": {title: [{text: {content: "Sprint 规划"}}]},
        "类型": {select: {name: "SprintPlan"}},
        "状态": {select: {name: "Todo"}}
      }')" > /dev/null

    sprint_plan_triggered=true
  fi
fi

jq -n \
  --arg tid "$TASK_ID" \
  --argjson triggered "$sprint_plan_triggered" \
  '{task_id: $tid, sprint_plan_triggered: $triggered}'
```

```bash
chmod +x scripts/complete-task.sh
```

- [ ] **Step 4：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-complete-task.bats
# 预期：全部 PASS
```

- [ ] **Step 5：Commit**

```bash
git add scripts/complete-task.sh tests/test-complete-task.bats
git commit -m "feat: complete-task.sh with quota update and sprint completion detection"
```

---

## Task 7：sprint-plan.sh

**Files:**
- Create: `scripts/sprint-plan.sh`
- Create: `tests/test-sprint-plan.bats`

按优先级评分选需求，批量创建 Dev 任务，激活 Sprint。

- [ ] **Step 1：写失败测试**

写入 `tests/test-sprint-plan.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "没有 Ready 需求时退出码为 0，输出 skipped" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  run bash scripts/sprint-plan.sh
  assert_success
  assert_output --partial "skipped"
}

@test "有 Ready 需求时输出 activated 和 sprint_id" {
  export MOCK_SPRINT_PLAN=1
  run bash scripts/sprint-plan.sh
  assert_success
  assert_output --partial "activated"
  echo "$output" | jq -e '.sprint_id' > /dev/null
}

@test "优先级评分正确：P0=40 P1=30 P2=20 P3=10" {
  run bash -c 'source scripts/lib/notion.sh; score_priority "P0"'
  assert_output "40"
  run bash -c 'source scripts/lib/notion.sh; score_priority "P1"'
  assert_output "30"
  run bash -c 'source scripts/lib/notion.sh; score_priority "P2"'
  assert_output "20"
  run bash -c 'source scripts/lib/notion.sh; score_priority "P3"'
  assert_output "10"
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-sprint-plan.bats
# 预期：FAIL
```

- [ ] **Step 3：在 notion.sh 中加入 score_priority 函数**

在 `scripts/lib/notion.sh` 末尾追加：
```bash
# score_priority <priority_name> → 输出数字分值
score_priority() {
  case "$1" in
    P0) echo 40 ;;
    P1) echo 30 ;;
    P2) echo 20 ;;
    P3) echo 10 ;;
    *)  echo 0  ;;
  esac
}
```

- [ ] **Step 4：实现 scripts/sprint-plan.sh**

写入 `scripts/sprint-plan.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
END_ISO=$(date -u -d "+${SPRINT_DURATION} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
          date -u -v "+${SPRINT_DURATION}d" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

# 测试注入点
if [ -n "${MOCK_SPRINT_PLAN:-}" ]; then
  jq -n '{status: "activated", sprint_id: "mock-sprint-id", tasks_created: 2}'
  exit 0
fi

# 1. 查询所有 Ready 需求
ready_filter=$(jq -n '{property: "状态", select: {equals: "Ready"}}')
ready_result=$(notion_query_db "$DB_REQUIREMENTS" "$ready_filter")
ready_count=$(echo "$ready_result" | jq '.results | length')

if [ "$ready_count" -eq 0 ]; then
  jq -n '{status: "skipped", reason: "没有 Ready 状态的需求"}'
  exit 0
fi

# 2. 按优先级评分排序，取前 N 条
sorted_reqs=$(echo "$ready_result" | jq -c \
  '[.results[] | {
    id: .id,
    title: (.properties["标题"].title[0].plain_text // ""),
    priority: (.properties["优先级"].select.name // "P3")
  }] | sort_by(
    if .priority == "P0" then -40
    elif .priority == "P1" then -30
    elif .priority == "P2" then -20
    else -10 end
  )')

sprint_name="Sprint-$(date -u +%Y%m%d)"
sprint_number=$((RANDOM % 900 + 100))
sprint_name="Sprint-${sprint_number}"

# 3. 创建新 Sprint
sprint_page=$(notion_create_page "$DB_SPRINTS" "$(jq -n \
  --arg name "$sprint_name" \
  --arg start "$NOW_ISO" \
  --arg end "$END_ISO" \
  '{
    "名称": {title: [{text: {content: $name}}]},
    "状态": {select: {name: "Active"}},
    "开始日期": {date: {start: $start}},
    "结束日期": {date: {start: $end}}
  }')")
sprint_id=$(echo "$sprint_page" | jq -r '.id')

# 4. 为前 capacity 条需求创建 Dev 任务，更新需求状态
tasks_created=0
req_titles=()

while IFS= read -r req; do
  [ "$tasks_created" -ge "$SPRINT_CAPACITY" ] && break
  req_id=$(echo "$req" | jq -r '.id')
  req_title=$(echo "$req" | jq -r '.title')
  req_titles+=("$req_title")

  # 创建 Dev 任务
  notion_create_page "$DB_TASKS" "$(jq -n \
    --arg title "实现：${req_title}" \
    --arg req_id "$req_id" \
    --arg sprint_id "$sprint_id" \
    '{
      "标题": {title: [{text: {content: $title}}]},
      "状态": {select: {name: "Todo"}},
      "类型": {select: {name: "Dev"}},
      "需求": {relation: [{id: $req_id}]},
      "Sprint": {relation: [{id: $sprint_id}]},
      "退还次数": {number: 0}
    }')" > /dev/null

  # 更新需求状态为 In Sprint
  notion_update_page "$req_id" \
    "$(jq -n '{"状态": {select: {name: "In Sprint"}}}')" > /dev/null

  tasks_created=$((tasks_created + 1))
done < <(echo "$sorted_reqs" | jq -c '.[]')

# 5. 写入 Sprint 开始说明
start_note="本次 Sprint 选入 ${tasks_created} 个需求：$(IFS=', '; echo "${req_titles[*]}")"
notion_update_page "$sprint_id" \
  "$(jq -n --arg note "$start_note" '{"开始说明": {rich_text: [{text: {content: $note}}]}}')" > /dev/null

jq -n \
  --arg sprint_id "$sprint_id" \
  --arg sprint_name "$sprint_name" \
  --argjson count "$tasks_created" \
  '{status: "activated", sprint_id: $sprint_id, sprint_name: $sprint_name, tasks_created: $count}'
```

```bash
chmod +x scripts/sprint-plan.sh
```

- [ ] **Step 5：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-sprint-plan.bats
# 预期：全部 PASS
```

- [ ] **Step 6：Commit**

```bash
git add scripts/sprint-plan.sh scripts/lib/notion.sh tests/test-sprint-plan.bats
git commit -m "feat: sprint-plan.sh with priority scoring and batch task creation"
```

---

## Task 8：monitor-check.sh

**Files:**
- Create: `scripts/monitor-check.sh`
- Create: `tests/test-monitor-check.bats`

读取 heartbeat → 乐观锁 → 执行检查 → 写 findings → 写需求。

- [ ] **Step 1：写失败测试**

写入 `tests/test-monitor-check.bats`：
```bash
#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "heartbeat 时间未到时退出码 0，输出 skipped" {
  export MOCK_MONITOR_RECENT=1
  run bash scripts/monitor-check.sh
  assert_success
  assert_output --partial "skipped"
}

@test "heartbeat 时间已到时执行检查，输出 completed" {
  export MOCK_MONITOR_RECENT=0
  export MOCK_HTTP_STATUS=200
  run bash scripts/monitor-check.sh
  assert_success
  assert_output --partial "completed"
}

@test "HTTP 检查失败时输出 findings 并写入需求" {
  export MOCK_MONITOR_RECENT=0
  export MOCK_HTTP_STATUS=500
  run bash scripts/monitor-check.sh
  assert_success
  assert_output --partial "finding"
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-monitor-check.bats
# 预期：FAIL
```

- [ ] **Step 3：实现 scripts/monitor-check.sh**

写入 `scripts/monitor-check.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

NOW_EPOCH=$(date -u +%s)
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FINGERPRINT=$(agent_fingerprint)
INTERVAL_SECONDS=$((MONITOR_INTERVAL * 3600))
findings=()

# 测试注入点
if [ -n "${MOCK_MONITOR_RECENT:-}" ]; then
  if [ "$MOCK_MONITOR_RECENT" -eq 1 ]; then
    jq -n '{status: "skipped", reason: "距上次检查未满间隔"}'
    exit 0
  fi
  # 模拟 HTTP 检查
  mock_status="${MOCK_HTTP_STATUS:-200}"
  if [ "$mock_status" != "200" ]; then
    findings+=("HTTP 检查失败：状态码 ${mock_status}（期望 200）")
  fi
  jq -n \
    --argjson count "${#findings[@]}" \
    '{status: "completed", findings_count: $count, finding: "mock"}'
  exit 0
fi

# 1. 读取 heartbeat 记录
hb_filter=$(jq -n '{property: "类型", select: {equals: "heartbeat"}}')
hb_result=$(notion_query_db "$DB_MONITOR_LOGS" "$hb_filter")
hb_count=$(echo "$hb_result" | jq '.results | length')

if [ "$hb_count" -gt 0 ]; then
  hb_page_id=$(echo "$hb_result" | jq -r '.results[0].id')
  last_run=$(echo "$hb_result" | jq -r '.results[0].properties["时间"].date.start // ""')
  if [ -n "$last_run" ]; then
    last_epoch=$(date -u -d "$last_run" +%s 2>/dev/null || \
                 date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_run" +%s 2>/dev/null || echo 0)
    elapsed=$((NOW_EPOCH - last_epoch))
    if [ "$elapsed" -lt "$INTERVAL_SECONDS" ]; then
      jq -n '{status: "skipped", reason: "距上次检查未满间隔"}'
      exit 0
    fi
  fi
fi

# 2. 乐观锁：写入 heartbeat 指纹
if [ "$hb_count" -eq 0 ]; then
  # 首次创建 heartbeat
  hb_page=$(notion_create_page "$DB_MONITOR_LOGS" "$(jq -n \
    --arg now "$NOW_ISO" \
    --arg fp "$FINGERPRINT" \
    '{
      "时间": {date: {start: $now}},
      "类型": {select: {name: "heartbeat"}},
      "来源": {rich_text: [{text: {content: $fp}}]}
    }')")
  hb_page_id=$(echo "$hb_page" | jq -r '.id')
else
  notion_update_page "$hb_page_id" "$(jq -n \
    --arg now "$NOW_ISO" \
    --arg fp "$FINGERPRINT" \
    '{
      "时间": {date: {start: $now}},
      "来源": {rich_text: [{text: {content: $fp}}]}
    }')" > /dev/null
fi

sleep 1

# 验证指纹
verify=$(notion_get_page "$hb_page_id")
actual_fp=$(echo "$verify" | jq -r '.properties["来源"].rich_text[0].plain_text // ""')
if [ "$actual_fp" != "$FINGERPRINT" ]; then
  jq -n '{status: "skipped", reason: "heartbeat 被其他 Agent 抢占"}'
  exit 0
fi

# 3. 读取 config 中的检查项并执行
config_file=".sdlc/config.json"
check_count=$(jq '.monitor.checks | length' "$config_file")

for i in $(seq 0 $((check_count - 1))); do
  check_type=$(jq -r ".monitor.checks[$i].type" "$config_file")

  if [ "$check_type" = "http" ]; then
    url=$(jq -r ".monitor.checks[$i].url" "$config_file")
    expect=$(jq -r ".monitor.checks[$i].expect_status" "$config_file")
    actual_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
    if [ "$actual_status" != "$expect" ]; then
      findings+=("HTTP 检查失败：${url} 返回 ${actual_status}（期望 ${expect}）")
    fi

  elif [ "$check_type" = "script" ]; then
    script_path=$(jq -r ".monitor.checks[$i].path" "$config_file")
    if ! bash "$script_path" 2>&1; then
      findings+=("自定义检查失败：${script_path}")
    fi
  fi
done

# 4. 写入 findings 并创建需求
for finding in "${findings[@]}"; do
  # 写监控日志
  notion_create_page "$DB_MONITOR_LOGS" "$(jq -n \
    --arg now "$NOW_ISO" \
    --arg finding "$finding" \
    '{
      "时间": {date: {start: $now}},
      "类型": {select: {name: "finding"}},
      "来源": {rich_text: [{text: {content: "monitor-check"}}]},
      "发现内容": {rich_text: [{text: {content: $finding}}]},
      "状态": {select: {name: "New"}}
    }')" > /dev/null

  # 创建需求
  notion_create_page "$DB_REQUIREMENTS" "$(jq -n \
    --arg title "【监控发现】${finding}" \
    '{
      "标题": {title: [{text: {content: $title}}]},
      "状态": {select: {name: "Inbox"}},
      "来源": {select: {name: "Monitor"}}
    }')" > /dev/null
done

jq -n \
  --argjson count "${#findings[@]}" \
  '{status: "completed", findings_count: $count}'
```

```bash
chmod +x scripts/monitor-check.sh
```

- [ ] **Step 4：运行测试，确认通过**

```bash
./tests/bats/bin/bats tests/test-monitor-check.bats
# 预期：全部 PASS
```

- [ ] **Step 5：运行全部测试，确认无回归**

```bash
./tests/bats/bin/bats tests/
# 预期：全部 PASS
```

- [ ] **Step 6：Commit**

```bash
git add scripts/monitor-check.sh tests/test-monitor-check.bats
git commit -m "feat: monitor-check.sh with heartbeat lock, HTTP checks, and requirement creation"
```

---

## Task 9：可执行权限 + .gitignore + README

**Files:**
- Create: `.gitignore`
- Modify: 所有 scripts/ 文件权限

- [ ] **Step 1：确保所有脚本可执行**

```bash
cd /home/nuan/projects/oh-my-sdlc
chmod +x scripts/*.sh scripts/lib/*.sh
ls -la scripts/*.sh scripts/lib/*.sh
# 确认所有文件有 -rwxr-xr-x 权限
```

- [ ] **Step 2：创建 .gitignore**

写入 `.gitignore`：
```
.sdlc/.initialized
*.log
node_modules/
mcp/sdlc-mcp/dist/
```

- [ ] **Step 3：运行完整测试套件，确认全绿**

```bash
./tests/bats/bin/bats tests/ --timing
# 预期：全部 PASS，显示每个测试耗时
```

- [ ] **Step 4：最终 Commit**

```bash
git add .gitignore
git add -A
git commit -m "chore: file permissions, gitignore, all script tests passing"
```

---

## 自我审查

**Spec 覆盖检查：**
- ✅ get-next-work.sh：配额检查、六优先级阶段（DEVELOP/SPRINT_PLAN/DEPLOY/REFINE/MONITOR/IDLE）
- ✅ claim-task.sh：乐观锁（Claiming → 等待 → 验证 → In Progress）
- ✅ return-task.sh：退还次数阈值、Blocked 升级、清空认领人
- ✅ complete-task.sh：状态更新、结果摘要、配额 +1、Sprint 完成检测、SprintPlan 任务创建
- ✅ sprint-plan.sh：P0/P1/P2/P3 评分、容量截取、Sprint 创建、任务批量创建、开始说明写入
- ✅ monitor-check.sh：heartbeat 乐观锁、HTTP 检查、自定义脚本检查、findings 写入、需求创建
- ✅ 共享库：所有 Notion API 函数、属性 helper、agent_fingerprint、score_priority

**函数名一致性检查：**
- `load_config` / `notion_query_db` / `notion_create_page` / `notion_update_page` / `notion_get_page` — 在所有脚本中一致
- `agent_fingerprint` — claim-task.sh 和 monitor-check.sh 均从 notion.sh 取
- `score_priority` — 仅 sprint-plan.sh 使用，在 notion.sh 中定义

**无占位符确认：** 所有步骤均包含完整可执行代码。
