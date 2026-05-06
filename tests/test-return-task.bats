#!/usr/bin/env bats
load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'
setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "缺少参数时报错" {
  run bash scripts/return-task.sh
  assert_failure
  assert_output --partial "task_id"
}

@test "退还次数 < threshold 时状态回 Todo，输出 todo" {
  export MOCK_RETURN_COUNT=1
  run bash scripts/return-task.sh "task-abc-123" "缺少 DEPLOY_SSH_KEY_PATH"
  assert_success
  assert_output --partial "todo"
}

@test "退还次数 >= threshold 时状态变 Blocked，输出 blocked" {
  export MOCK_RETURN_COUNT=3
  run bash scripts/return-task.sh "task-abc-123" "缺少部署权限"
  assert_success
  assert_output --partial "blocked"
}
