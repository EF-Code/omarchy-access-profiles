#!/usr/bin/env bats

setup() {
  export TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/mock"
  cp tests/fixtures/mock-values.json "$TEST_ROOT/mock/values.json"
  export ACCESSCTL_MOCK_DIR="$TEST_ROOT/mock"
  export ACCESSCTL_CONFIG_HOME="$TEST_ROOT/config"
  export ACCESSCTL_STATE_HOME="$TEST_ROOT/state"
  export ACCESSCTL_RUNTIME_HOME="$TEST_ROOT/runtime"
}

teardown() { rm -rf "$TEST_ROOT"; }

@test "plan is read-only and reports all requested settings" {
  run scripts/accessctl plan comfortable
  [ "$status" -eq 0 ]
  [ "$(jq '.changes | length' <<< "$output")" -eq 8 ]
  [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ]
}

@test "forced partial failure rolls the mock desktop back" {
  export ACCESSCTL_MOCK_FAIL_AFTER=2
  run scripts/accessctl apply comfortable --operation-id 11111111-1111-4111-8111-111111111111
  [ "$status" -ne 0 ]
  diff -u tests/fixtures/mock-values.json "$TEST_ROOT/mock/values.json"
  [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/pending.json" ]
}

@test "restore reports external drift instead of overwriting it" {
  run scripts/accessctl apply comfortable --operation-id 11111111-1111-4111-8111-111111111111
  [ "$status" -eq 0 ]
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  run scripts/accessctl restore --operation-id 22222222-2222-4222-8222-222222222222
  [ "$status" -ne 0 ]
  [ "$(jq -r '.details.conflicts[0].id' <<< "$output")" = "hypr.border_size" ]
}
