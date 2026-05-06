#!/usr/bin/env bats
load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'
setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "没有 Ready 需求时退出码为 0，输出 skipped" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  run bash scripts/sprint-plan.sh
  assert_success
  assert_output --partial "skipped"
}

@test "有 Ready 需求时输出 activated 和 sprint_id" {
  export MOCK_SPRINT_PLAN=1
  run bash scripts/sprint-plan.sh
  assert_success
  assert_output --partial "activated"
  echo "$output" | jq -e '.sprint_id' > /dev/null
}

@test "优先级评分正确：P0=40 P1=30 P2=20 P3=10" {
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
