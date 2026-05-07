#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() {
  setup_test_env
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
}

teardown() {
  teardown_test_env
  rm -rf "$TMPDIR_TEST"
}

@test "init.sh Mode A: 正常退出码 0" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR_TEST' bash scripts/init.sh"
  assert_success
}

@test "init.sh Mode A: 生成 .sdlc/config.json" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  run bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR_TEST' bash scripts/init.sh"
  assert_success
  [ -f "$TMPDIR_TEST/.sdlc/config.json" ]
}

@test "init.sh Mode A: config.json 包含所有数据库 ID" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR_TEST' bash scripts/init.sh"
  run jq -r '.databases.requirements' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.sprints' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.tasks' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.knowledge' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.deployments' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "test-db-000"
  run jq -r '.databases.monitor_logs' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "test-db-000"
}

@test "init.sh Mode A: config.json 包含正确的项目名和 Sprint 配置" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR_TEST' bash scripts/init.sh"
  run jq -r '.project_name' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "MyProject"
  run jq -r '.sprint.duration_days' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "14"
  run jq -r '.sprint.capacity' "$TMPDIR_TEST/.sdlc/config.json"
  assert_output "10"
}

@test "init.sh Mode A: 生成 .claude/mcp.json" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR_TEST' bash scripts/init.sh"
  [ -f "$TMPDIR_TEST/.claude/mcp.json" ]
  run jq -r '.mcpServers.sdlc.command' "$TMPDIR_TEST/.claude/mcp.json"
  assert_output "npx"
}

@test "init.sh Mode A: 生成 .gemini/mcp.json" {
  export MOCK_CURL_RESPONSE='{"id":"test-db-000","object":"database"}'
  bash -c "printf 'test-page-id\nMyProject\n14\n10\n3\nA\n' | PROJECT_ROOT='$TMPDIR_TEST' bash scripts/init.sh"
  [ -f "$TMPDIR_TEST/.gemini/mcp.json" ]
  run jq -r '.mcpServers.sdlc.command' "$TMPDIR_TEST/.gemini/mcp.json"
  assert_output "npx"
}
