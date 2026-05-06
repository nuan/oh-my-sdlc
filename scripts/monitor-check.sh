#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

NOW_EPOCH=$(date -u +%s)
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FINGERPRINT=$(agent_fingerprint)
INTERVAL_SECONDS=$((MONITOR_INTERVAL * 3600))
findings=()

if [ -n "${MOCK_MONITOR_RECENT:-}" ]; then
  if [ "$MOCK_MONITOR_RECENT" -eq 1 ]; then
    jq -n '{status: "skipped", reason: "距上次检查未满间隔"}'
    exit 0
  fi
  mock_status="${MOCK_HTTP_STATUS:-200}"
  if [ "$mock_status" != "200" ]; then
    findings+=("HTTP 检查失败：状态码 ${mock_status}（期望 200）")
    jq -n \
      --argjson count "${#findings[@]}" \
      '{status: "completed", findings_count: $count, finding: "mock"}'
  else
    jq -n '{status: "completed", findings_count: 0}'
  fi
  exit 0
fi

hb_filter=$(jq -n '{property: "类型", select: {equals: "heartbeat"}}')
hb_result=$(notion_query_db "$DB_MONITOR_LOGS" "$hb_filter")
hb_count=$(echo "$hb_result" | jq '.results | length')

if [ "$hb_count" -gt 0 ]; then
  hb_page_id=$(echo "$hb_result" | jq -r '.results[0].id')
  last_run=$(echo "$hb_result" | jq -r '.results[0].properties["时间"].date.start // ""')
  if [ -n "$last_run" ]; then
    last_epoch=$(date -u -d "$last_run" +%s 2>/dev/null || echo 0)
    elapsed=$((NOW_EPOCH - last_epoch))
    if [ "$elapsed" -lt "$INTERVAL_SECONDS" ]; then
      jq -n '{status: "skipped", reason: "距上次检查未满间隔"}'
      exit 0
    fi
  fi
fi

if [ "$hb_count" -eq 0 ]; then
  hb_page=$(notion_create_page "$DB_MONITOR_LOGS" "$(jq -n \
    --arg now "$NOW_ISO" \
    --arg fp "$FINGERPRINT" \
    '{
      "时间": {date: {start: $now}},
      "类型": {select: {name: "heartbeat"}},
      "来源": {rich_text: [{text: {content: $fp}}]}
    }')")
  hb_page_id=$(echo "$hb_page" | jq -r '.id')
else
  notion_update_page "$hb_page_id" "$(jq -n \
    --arg now "$NOW_ISO" \
    --arg fp "$FINGERPRINT" \
    '{
      "时间": {date: {start: $now}},
      "来源": {rich_text: [{text: {content: $fp}}]}
    }')" > /dev/null
fi

sleep 1

verify=$(notion_get_page "$hb_page_id")
actual_fp=$(echo "$verify" | jq -r '.properties["来源"].rich_text[0].plain_text // ""')
if [ "$actual_fp" != "$FINGERPRINT" ]; then
  jq -n '{status: "skipped", reason: "heartbeat 被其他 Agent 抢占"}'
  exit 0
fi

config_file=".sdlc/config.json"
check_count=$(jq '.monitor.checks | length' "$config_file")

for i in $(seq 0 $((check_count - 1))); do
  check_type=$(jq -r ".monitor.checks[$i].type" "$config_file")

  if [ "$check_type" = "http" ]; then
    url=$(jq -r ".monitor.checks[$i].url" "$config_file")
    expect=$(jq -r ".monitor.checks[$i].expect_status" "$config_file")
    actual_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
    if [ "$actual_status" != "$expect" ]; then
      findings+=("HTTP 检查失败：${url} 返回 ${actual_status}（期望 ${expect}）")
    fi

  elif [ "$check_type" = "script" ]; then
    script_path=$(jq -r ".monitor.checks[$i].path" "$config_file")
    if ! bash "$script_path" 2>&1; then
      findings+=("自定义检查失败：${script_path}")
    fi
  fi
done

for finding in "${findings[@]}"; do
  notion_create_page "$DB_MONITOR_LOGS" "$(jq -n \
    --arg now "$NOW_ISO" \
    --arg finding "$finding" \
    '{
      "时间": {date: {start: $now}},
      "类型": {select: {name: "finding"}},
      "来源": {rich_text: [{text: {content: "monitor-check"}}]},
      "发现内容": {rich_text: [{text: {content: $finding}}]},
      "状态": {select: {name: "New"}}
    }')" > /dev/null

  notion_create_page "$DB_REQUIREMENTS" "$(jq -n \
    --arg title "【监控发现】${finding}" \
    '{
      "标题": {title: [{text: {content: $title}}]},
      "状态": {select: {name: "Inbox"}},
      "来源": {select: {name: "Monitor"}}
    }')" > /dev/null
done

jq -n \
  --argjson count "${#findings[@]}" \
  '{status: "completed", findings_count: $count}'
