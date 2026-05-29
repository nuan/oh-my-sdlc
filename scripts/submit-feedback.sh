#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"

TITLE="${1:?Error: title 参数必填}"
DESCRIPTION="${2:?Error: description 参数必填}"
CATEGORY="${3:?Error: category 参数必填 (bug|feature|improvement|question)}"

# 验证 category
case "$CATEGORY" in
  bug|feature|improvement|question) ;;
  *) echo "Error: category 必须是 bug, feature, improvement 或 question" >&2; exit 1 ;;
esac

# 读取 upstream 反馈 DB ID（与项目 config.json 完全隔离）
UPSTREAM_CONFIG="${SCRIPT_DIR}/../.sdlc/upstream.json"
if [ ! -f "$UPSTREAM_CONFIG" ]; then
  echo "Error: ${UPSTREAM_CONFIG} not found. oh-my-sdlc upstream feedback not configured." >&2
  exit 1
fi

FEEDBACK_DB=$(jq -r '.feedback_db' "$UPSTREAM_CONFIG")
if [ -z "$FEEDBACK_DB" ] || [ "$FEEDBACK_DB" = "null" ]; then
  echo "Error: feedback_db not set in upstream.json" >&2
  exit 1
fi

# 尝试从项目 config.json 读取来源项目名（可选）
PROJECT_CONFIG=".sdlc/config.json"
if [ -f "$PROJECT_CONFIG" ]; then
  SOURCE_PROJECT=$(jq -r '.project_name // "unknown"' "$PROJECT_CONFIG")
else
  SOURCE_PROJECT="unknown"
fi

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

page=$(notion_create_page "$FEEDBACK_DB" "$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg cat "$CATEGORY" \
  --arg src "$SOURCE_PROJECT" \
  --arg now "$NOW_ISO" \
  '{
    "标题": {title: [{text: {content: $title}}]},
    "描述": {rich_text: [{text: {content: $desc}}]},
    "分类": {select: {name: $cat}},
    "来源项目": {rich_text: [{text: {content: $src}}]},
    "状态": {select: {name: "New"}}
  }')")

feedback_id=$(echo "$page" | jq -r '.id')
jq -n --arg id "$feedback_id" --arg src "$SOURCE_PROJECT" \
  '{feedback_id: $id, source_project: $src}'
