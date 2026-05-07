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
