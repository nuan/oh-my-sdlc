#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TODAY=$(date -u +%Y-%m-%d)
NOW_EPOCH=$(date -u +%s)

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

  if [ -n "$sprint_end" ]; then
    sprint_end_epoch=$(date -u -d "$sprint_end" +%s 2>/dev/null || \
      date -u -j -f "%Y-%m-%d" "$sprint_end" +%s 2>/dev/null || {
        echo "Warning: unable to parse sprint end date '${sprint_end}', assuming not expired" >&2
        echo $((NOW_EPOCH + 86400))
      })
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

  if [ "$NOW_EPOCH" -ge "$sprint_end_epoch" ]; then
    sprint_name=$(echo "$sprint_result" | jq -r '.results[0].properties["名称"].title[0].plain_text // ""')
    result "DEPLOY" "$sprint_id" "部署 Sprint ${sprint_name}" "deploy"
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

# 5. 检查监控窗口（测试模式下跳过）
if [ -z "${MOCK_QUOTA_COMPLETED:-}" ]; then
  hb_filter=$(jq -n '{property: "类型", select: {equals: "heartbeat"}}')
  hb_result=$(notion_query_db "$DB_MONITOR_LOGS" "$hb_filter")
  if [ "$(echo "$hb_result" | jq '.results | length')" -gt 0 ]; then
    last_run=$(echo "$hb_result" | jq -r '.results[0].properties["时间"].date.start // ""')
    if [ -n "$last_run" ]; then
      last_epoch=$(date -u -d "$last_run" +%s 2>/dev/null || echo 0)
      interval_seconds=$((MONITOR_INTERVAL * 3600))
      if [ "$((NOW_EPOCH - last_epoch))" -ge "$interval_seconds" ]; then
        result "MONITOR" "" "执行监控检查" "monitor"
      fi
    fi
  fi
fi

# 6. 无事可做
result "IDLE" "" "暂无待处理任务" ""
