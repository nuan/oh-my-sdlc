#!/usr/bin/env bats
load 'lib/test-helpers'
load '../tests/bats-support/load'
load '../tests/bats-assert/load'
setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "heartbeat 时间未到时退出码 0，输出 skipped" {
  export MOCK_MONITOR_RECENT=1
  run bash scripts/monitor-check.sh
  assert_success
  assert_output --partial "skipped"
}

@test "heartbeat 时间已到时执行检查，输出 completed" {
  export MOCK_MONITOR_RECENT=0
  export MOCK_HTTP_STATUS=200
  run bash scripts/monitor-check.sh
  assert_success
  assert_output --partial "completed"
}

@test "HTTP 检查失败时输出 finding" {
  export MOCK_MONITOR_RECENT=0
  export MOCK_HTTP_STATUS=500
  run bash scripts/monitor-check.sh
  assert_success
  assert_output --partial "finding"
}
