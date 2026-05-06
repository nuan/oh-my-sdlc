#!/usr/bin/env bats
load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'
setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "缺少 task_id 参数时报错退出" {
  run bash scripts/claim-task.sh
  assert_failure
  assert_output --partial "task_id"
}

@test "指纹验证成功时返回 0" {
  export MOCK_CLAIM_SUCCESS=1
  run bash scripts/claim-task.sh "task-abc-123"
  assert_success
}

@test "指纹被覆盖时返回 1（被抢占）" {
  export MOCK_CLAIM_SUCCESS=0
  run bash scripts/claim-task.sh "task-abc-123"
  assert_failure
}
