#!/usr/bin/env bash
set -euo pipefail

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

load_config() {
  if [ -z "${NOTION_TOKEN:-}" ]; then
    echo "Error: NOTION_TOKEN environment variable not set" >&2
    exit 1
  fi

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

notion_get_page() {
  local page_id="$1"
  curl -s -X GET \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    "${NOTION_API}/pages/${page_id}"
}

prop_title() { jq -n --arg v "$1" '{title: [{text: {content: $v}}]}'; }
prop_select() { jq -n --arg v "$1" '{select: {name: $v}}'; }
prop_text() { jq -n --arg v "$1" '{rich_text: [{text: {content: $v}}]}'; }
prop_number() { jq -n --argjson v "$1" '{number: $v}'; }
prop_date() { jq -n --arg v "$1" '{date: {start: $v}}'; }
prop_relation() { jq -n --arg v "$1" '{relation: [{id: $v}]}'; }

get_plain_text() {
  echo "$1" | jq -r '
    if .title then .title[0].plain_text // ""
    elif .rich_text then .rich_text[0].plain_text // ""
    else "" end'
}

get_select_name() { echo "$1" | jq -r '.select.name // ""'; }
get_number() { echo "$1" | jq -r '.number // 0'; }
get_date_start() { echo "$1" | jq -r '.date.start // ""'; }

agent_fingerprint() {
  echo "${HOSTNAME:-$(hostname)}-$$-$(date +%s)"
}

score_priority() {
  case "$1" in
    P0) echo 40 ;;
    P1) echo 30 ;;
    P2) echo 20 ;;
    P3) echo 10 ;;
    *)  echo 0  ;;
  esac
}

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
  local body
  body=$(jq -n --argjson props "$properties_json" '{properties: $props}')
  curl -s -X PATCH \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${NOTION_API}/databases/${db_id}"
}
