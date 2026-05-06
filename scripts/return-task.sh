#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TASK_ID="${1:?Error: task_id 参数必填}"
REASON="${2:?Error: reason 参数必填}"

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
