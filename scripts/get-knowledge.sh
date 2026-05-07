#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

result=$(notion_query_db "$DB_KNOWLEDGE" "")

modules=$(echo "$result" | jq '[.results[] | {
  name: (.properties["模块名称"].title[0].plain_text // ""),
  description: (.properties["功能描述"].rich_text[0].plain_text // ""),
  key_files: (.properties["关键文件"].rich_text[0].plain_text // ""),
  tech_stack: (.properties["技术栈"].rich_text[0].plain_text // "")
}]')

jq -n --argjson modules "$modules" '{modules: $modules}'
