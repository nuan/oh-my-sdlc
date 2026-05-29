#!/usr/bin/env bash
set -euo pipefail

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

notion_request() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local response

  if [ -n "$body" ]; then
    response=$(curl -s -X "$method" \
      -H "Authorization: Bearer ${NOTION_TOKEN}" \
      -H "Notion-Version: ${NOTION_VERSION}" \
      -H "Content-Type: application/json" \
      -d "$body" \
      "$url")
  else
    response=$(curl -s -X "$method" \
      -H "Authorization: Bearer ${NOTION_TOKEN}" \
      -H "Notion-Version: ${NOTION_VERSION}" \
      "$url")
  fi

  if ! echo "$response" | jq -e . >/dev/null 2>&1; then
    echo "Error: Notion API returned non-JSON response" >&2
    echo "$response" >&2
    return 1
  fi

  if echo "$response" | jq -e '.object == "error"' >/dev/null; then
    local status code message
    status=$(echo "$response" | jq -r '.status // "unknown"')
    code=$(echo "$response" | jq -r '.code // "unknown_error"')
    message=$(echo "$response" | jq -r '.message // "No error message"')
    echo "Error: Notion API request failed (${status} ${code}): ${message}" >&2
    return 1
  fi

  echo "$response"
}

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
  DB_BUGS=$(jq -r '.databases.bugs // ""' "$config_file")
  DB_TEST_REPORTS=$(jq -r '.databases.test_reports // ""' "$config_file")
  SPRINT_DURATION=$(jq -r '.sprint.duration_days' "$config_file")
  SPRINT_CAPACITY=$(jq -r '.sprint.capacity' "$config_file")
  DAILY_TASK_LIMIT=$(jq -r '.quota.daily_task_limit' "$config_file")
  MONITOR_INTERVAL=$(jq -r '.monitor.interval_hours' "$config_file")
  RETURN_THRESHOLD=$(jq -r '.quota.return_threshold // 3' "$config_file")

  export DB_REQUIREMENTS DB_SPRINTS DB_TASKS DB_DEPLOYMENTS \
         DB_MONITOR_LOGS DB_KNOWLEDGE DB_BUGS DB_TEST_REPORTS \
         SPRINT_DURATION SPRINT_CAPACITY \
         DAILY_TASK_LIMIT MONITOR_INTERVAL RETURN_THRESHOLD
}

notion_database_exists() {
  local db_id="$1"
  if [ -z "$db_id" ]; then return 1; fi
  local response
  response=$(curl -s -X GET \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    "${NOTION_API}/databases/${db_id}")
  if echo "$response" | jq -e '.object == "database" and .archived == false' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

notion_query_db() {
  local db_id="$1"
  local filter="${2:-}"
  local body="{}"
  if [ -n "$filter" ]; then
    body=$(echo "{}" | jq --argjson f "$filter" '. + {filter: $f}')
  fi
  notion_request POST "${NOTION_API}/databases/${db_id}/query" "$body"
}

notion_create_page() {
  local db_id="$1"
  local properties="$2"
  local body
  body=$(jq -n \
    --arg db_id "$db_id" \
    --argjson props "$properties" \
    '{parent: {database_id: $db_id}, properties: $props}')
  notion_request POST "${NOTION_API}/pages" "$body"
}

notion_update_page() {
  local page_id="$1"
  local properties="$2"
  local body
  body=$(jq -n --argjson props "$properties" '{properties: $props}')
  notion_request PATCH "${NOTION_API}/pages/${page_id}" "$body"
}

notion_get_page() {
  local page_id="$1"
  notion_request GET "${NOTION_API}/pages/${page_id}"
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
  notion_request POST "${NOTION_API}/databases" "$payload"
}

notion_update_database() {
  local db_id="$1"
  local properties_json="$2"
  local body
  body=$(jq -n --argjson props "$properties_json" '{properties: $props}')
  notion_request PATCH "${NOTION_API}/databases/${db_id}" "$body"
}
