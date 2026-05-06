#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TASK_ID="${1:?Error: task_id 参数必填}"
FINGERPRINT=$(agent_fingerprint)

if [ -n "${MOCK_CLAIM_SUCCESS:-}" ]; then
  [ "$MOCK_CLAIM_SUCCESS" -eq 1 ] && exit 0 || exit 1
fi

props=$(jq -n \
  --arg fp "$FINGERPRINT" \
  '{
    "状态": {select: {name: "Claiming"}},
    "认领人": {rich_text: [{text: {content: $fp}}]}
  }')
notion_update_page "$TASK_ID" "$props" > /dev/null

sleep 0.5

page=$(notion_get_page "$TASK_ID")
actual_fp=$(echo "$page" | jq -r '.properties["认领人"].rich_text[0].plain_text // ""')

if [ "$actual_fp" != "$FINGERPRINT" ]; then
  echo "claim failed: task $TASK_ID was claimed by $actual_fp" >&2
  exit 1
fi

props_confirm=$(jq -n '{"状态": {select: {name: "In Progress"}}}')
notion_update_page "$TASK_ID" "$props_confirm" > /dev/null

echo "claimed: $TASK_ID by $FINGERPRINT"
exit 0
