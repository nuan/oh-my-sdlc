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

if [ -n "${MOCK_COMPLETE:-}" ]; then
  [ "${MOCK_ALL_DONE:-0}" -eq 1 ] && sprint_plan_triggered=true
  jq -n \
    --arg tid "$TASK_ID" \
    --argjson triggered "$sprint_plan_triggered" \
    '{task_id: $tid, sprint_plan_triggered: $triggered}'
  exit 0
fi

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
    notion_update_page "$sprint_relation" \
      "$(jq -n '{"状态": {select: {name: "Completed"}}}')" > /dev/null
    notion_create_page "$DB_TASKS" "$(jq -n \
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
