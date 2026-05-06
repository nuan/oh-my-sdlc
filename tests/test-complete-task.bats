#!/usr/bin/env bats
load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'
setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "缺少参数时报错" {
  run bash scripts/complete-task.sh
  assert_failure
  assert_output --partial "task_id"
}

@test "status 非法值时报错" {
  run bash scripts/complete-task.sh "task-abc-123" "invalid"
  assert_failure
  assert_output --partial "done or failed"
}

@test "完成任务后输出含 task_id" {
  export MOCK_COMPLETE=1
  export MOCK_ALL_DONE=0
  run bash scripts/complete-task.sh "task-abc-123" "done" "实现了登录功能"
  assert_success
  echo "$output" | jq -e '.task_id' > /dev/null
}

@test "Sprint 全完成时输出 sprint_plan_triggered=true" {
  export MOCK_COMPLETE=1
  export MOCK_ALL_DONE=1
  run bash scripts/complete-task.sh "task-abc-123" "done" "全部完成"
  assert_success
  triggered=$(echo "$output" | jq -r '.sprint_plan_triggered')
  assert_equal "$triggered" "true"
}
