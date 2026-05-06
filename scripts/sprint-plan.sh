#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
END_ISO=$(date -u -d "+${SPRINT_DURATION} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
          date -u -v "+${SPRINT_DURATION}d" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
          { echo "Error: unable to compute sprint end date" >&2; exit 1; })

if [ -n "${MOCK_SPRINT_PLAN:-}" ]; then
  jq -n '{status: "activated", sprint_id: "mock-sprint-id", tasks_created: 2}'
  exit 0
fi

ready_filter=$(jq -n '{property: "状态", select: {equals: "Ready"}}')
ready_result=$(notion_query_db "$DB_REQUIREMENTS" "$ready_filter")
ready_count=$(echo "$ready_result" | jq '.results | length')

if [ "$ready_count" -eq 0 ]; then
  jq -n '{status: "skipped", reason: "没有 Ready 状态的需求"}'
  exit 0
fi

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

sprint_number=$((RANDOM % 900 + 100))
sprint_name="Sprint-${sprint_number}"

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

tasks_created=0
req_titles=()

while IFS= read -r req; do
  [ "$tasks_created" -ge "$SPRINT_CAPACITY" ] && break
  req_id=$(echo "$req" | jq -r '.id')
  req_title=$(echo "$req" | jq -r '.title')
  req_titles+=("$req_title")

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

  notion_update_page "$req_id" \
    "$(jq -n '{"状态": {select: {name: "In Sprint"}}}')" > /dev/null

  tasks_created=$((tasks_created + 1))
done < <(echo "$sorted_reqs" | jq -c '.[]')

start_note="本次 Sprint 选入 ${tasks_created} 个需求：$(IFS=', '; echo "${req_titles[*]}")"
notion_update_page "$sprint_id" \
  "$(jq -n --arg note "$start_note" '{"开始说明": {rich_text: [{text: {content: $note}}]}}')" > /dev/null

jq -n \
  --arg sprint_id "$sprint_id" \
  --arg sprint_name "$sprint_name" \
  --argjson count "$tasks_created" \
  '{status: "activated", sprint_id: $sprint_id, sprint_name: $sprint_name, tasks_created: $count}'
