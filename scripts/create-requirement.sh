#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TITLE="${1:?Error: title 参数必填}"
DESCRIPTION="${2:?Error: description 参数必填}"
SOURCE="${3:-human}"
SOURCE="$(echo "${SOURCE:0:1}" | tr '[:lower:]' '[:upper:]')${SOURCE:1}"

page=$(notion_create_page "$DB_REQUIREMENTS" "$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg src "$SOURCE" \
  '{
    "标题": {title: [{text: {content: $title}}]},
    "状态": {select: {name: "Inbox"}},
    "来源": {select: {name: $src}},
    "描述": {rich_text: [{text: {content: $desc}}]}
  }')")

req_id=$(echo "$page" | jq -r '.id')
jq -n --arg id "$req_id" '{requirement_id: $id}'
