#!/usr/bin/env bats

load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "配额耗尽时返回 IDLE" {
  export MOCK_QUOTA_COMPLETED=10
  run bash scripts/get-next-work.sh
  assert_success
  output_phase=$(echo "$output" | jq -r '.phase')
  assert_equal "$output_phase" "IDLE"
}

@test "Active Sprint 有 Todo 任务时返回 DEVELOP" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/task-todo.json"
  export MOCK_QUOTA_COMPLETED=0
  run bash scripts/get-next-work.sh
  assert_success
  output_phase=$(echo "$output" | jq -r '.phase')
  assert_equal "$output_phase" "DEVELOP"
  task_id=$(echo "$output" | jq -r '.task_id')
  assert_equal "$task_id" "task-abc-123"
}

@test "无任何工作时返回 IDLE" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  export MOCK_QUOTA_COMPLETED=0
  run bash scripts/get-next-work.sh
  assert_success
  output_phase=$(echo "$output" | jq -r '.phase')
  assert_equal "$output_phase" "IDLE"
}

@test "输出是合法 JSON" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  export MOCK_QUOTA_COMPLETED=0
  run bash scripts/get-next-work.sh
  assert_success
  echo "$output" | jq . > /dev/null
}
