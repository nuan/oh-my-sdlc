#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "load_config: config.json 不存在时退出码非零" {
  source scripts/lib/notion.sh
  run load_config "/nonexistent/path/config.json"
  assert_failure
  assert_output --partial "not found"
}

@test "load_config: 正确读取数据库 ID" {
  source scripts/lib/notion.sh
  load_config ".sdlc/config.json"
  assert_equal "$DB_TASKS" "task-db-id"
  assert_equal "$DB_SPRINTS" "sprint-db-id"
  assert_equal "$DAILY_TASK_LIMIT" "10"
  assert_equal "$RETURN_THRESHOLD" "3"
}

@test "notion_query_db: 调用时返回 JSON" {
  export MOCK_CURL_RESPONSE='{"object":"list","results":[]}'
  source scripts/lib/notion.sh
  load_config ".sdlc/config.json"
  run notion_query_db "test-db-id" ""
  assert_success
  assert_output --partial '"object":"list"'
}

@test "score_priority: P0=40 P1=30 P2=20 P3=10" {
  source scripts/lib/notion.sh
  run score_priority "P0"
  assert_output "40"
  run score_priority "P1"
  assert_output "30"
  run score_priority "P2"
  assert_output "20"
  run score_priority "P3"
  assert_output "10"
}

@test "prop_title: 返回合法 Notion title JSON" {
  source scripts/lib/notion.sh
  result=$(prop_title "测试标题")
  echo "$result" | jq -e '.title[0].text.content == "测试标题"' > /dev/null
}

@test "prop_select: 返回合法 Notion select JSON" {
  source scripts/lib/notion.sh
  result=$(prop_select "Todo")
  echo "$result" | jq -e '.select.name == "Todo"' > /dev/null
}

@test "agent_fingerprint: 返回非空字符串" {
  source scripts/lib/notion.sh
  result=$(agent_fingerprint)
  [ -n "$result" ]
}

@test "create-requirement.sh: 缺少参数时报错" {
  run bash scripts/create-requirement.sh
  assert_failure
  assert_output --partial "title"
}

@test "create-requirement.sh: 输出含 requirement_id" {
  export MOCK_CURL_RESPONSE='{"object":"page","id":"req-new-999"}'
  run bash scripts/create-requirement.sh "测试需求" "需求描述" "human"
  assert_success
  echo "$output" | jq -e '.requirement_id' > /dev/null
}

@test "get-knowledge.sh: 返回含 modules 数组的 JSON" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  run bash scripts/get-knowledge.sh
  assert_success
  echo "$output" | jq -e '.modules' > /dev/null
}

@test "upsert-knowledge.sh: 缺少参数时报错" {
  run bash scripts/upsert-knowledge.sh
  assert_failure
  assert_output --partial "module_name"
}

@test "upsert-knowledge.sh: 新增场景退出成功" {
  export MOCK_CURL_RESPONSE='{"object":"page","id":"entry-new-111","results":[]}'
  run bash scripts/upsert-knowledge.sh "auth" "JWT 登录" "src/auth.ts" "TypeScript,Express"
  assert_success
  echo "$output" | jq -e '.entry_id' > /dev/null
}
