#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

MODULE_NAME="${1:?Error: module_name 参数必填}"
DESCRIPTION="${2:?Error: description 参数必填}"
KEY_FILES="${3:?Error: key_files 参数必填}"
TECH_STACK="${4:?Error: tech_stack 参数必填}"

search_filter=$(jq -n \
  --arg name "$MODULE_NAME" \
  '{property: "模块名称", title: {equals: $name}}')
existing=$(notion_query_db "$DB_KNOWLEDGE" "$search_filter")
count=$(echo "$existing" | jq '.results | length')

if [ "$count" -gt 0 ]; then
  entry_id=$(echo "$existing" | jq -r '.results[0].id')
  notion_update_page "$entry_id" "$(jq -n \
    --arg desc "$DESCRIPTION" \
    --arg files "$KEY_FILES" \
    --arg stack "$TECH_STACK" \
    '{
      "功能描述": {rich_text: [{text: {content: $desc}}]},
      "关键文件": {rich_text: [{text: {content: $files}}]},
      "技术栈": {rich_text: [{text: {content: $stack}}]}
    }')" > /dev/null
else
  page=$(notion_create_page "$DB_KNOWLEDGE" "$(jq -n \
    --arg name "$MODULE_NAME" \
    --arg desc "$DESCRIPTION" \
    --arg files "$KEY_FILES" \
    --arg stack "$TECH_STACK" \
    '{
      "模块名称": {title: [{text: {content: $name}}]},
      "功能描述": {rich_text: [{text: {content: $desc}}]},
      "关键文件": {rich_text: [{text: {content: $files}}]},
      "技术栈": {rich_text: [{text: {content: $stack}}]}
    }')")
  entry_id=$(echo "$page" | jq -r '.id')
fi

jq -n --arg id "$entry_id" '{entry_id: $id}'
