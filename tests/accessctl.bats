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
  diff -u <(jq -S . tests/fixtures/mock-values.json) <(jq -S . "$TEST_ROOT/mock/values.json")
  [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/pending.json" ]
}

@test "failed apply does not leave a new baseline" {
  export ACCESSCTL_MOCK_FAIL_AFTER=1
  run scripts/accessctl apply comfortable --operation-id 77777777-7777-4777-8777-777777777777
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ]
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

@test "restore leaves an unmanaged baseline value untouched" {
  run scripts/accessctl apply comfortable --operation-id 33333333-3333-4333-8333-333333333333
  [ "$status" -eq 0 ]
  jq '.values."hypr.blur.enabled" = true' "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" > "$TEST_ROOT/state/omarchy-access-profiles/baseline-with-unmanaged"
  mv "$TEST_ROOT/state/omarchy-access-profiles/baseline-with-unmanaged" "$TEST_ROOT/state/omarchy-access-profiles/baseline.json"
  jq '."hypr.blur.enabled" = false' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  run scripts/accessctl restore --operation-id 44444444-4444-4444-8444-444444444444
  [ "$status" -eq 0 ]
  [ "$(jq -r '."hypr.blur.enabled"' "$TEST_ROOT/mock/values.json")" = false ]
}

@test "restore applies safe values before requiring conflict resolution" {
  run scripts/accessctl apply comfortable --operation-id 55555555-5555-4555-8555-555555555555
  [ "$status" -eq 0 ]
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  run scripts/accessctl restore --operation-id 66666666-6666-4666-8666-666666666666
  [ "$status" -ne 0 ]
  [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ]
  [ -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ]
  run scripts/accessctl resolve-conflict hypr.border_size --keep-external
  [ "$status" -eq 0 ]
  [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 9 ]
  [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ]
}

@test "recovery rolls back only settings listed as applied" {
  mkdir -p "$TEST_ROOT/state/omarchy-access-profiles"
  jq '."hypr.border_size" = 3 | ."gtk.text.scale" = 1.6' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  jq -n '{schemaVersion:1,operationId:"77777777-7777-4777-8777-777777777777",kind:"apply",profileId:"comfortable",before:{"hypr.border_size":2,"gtk.text.scale":1.0},target:{"hypr.border_size":3,"gtk.text.scale":1.25},applied:["hypr.border_size"],phase:"applying",baselineChanged:false,baselinePrevious:null}' > "$TEST_ROOT/state/omarchy-access-profiles/pending.json"
  run scripts/accessctl recover
  [ "$status" -eq 0 ]
  [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 2 ]
  [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.6 ]
}

@test "preview revert preserves a concurrent external change" {
  run scripts/accessctl preview comfortable --seconds 30 --operation-id 88888888-8888-4888-8888-888888888888
  [ "$status" -eq 0 ]
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  run scripts/accessctl cancel-preview --operation-id 88888888-8888-4888-8888-888888888888
  [ "$status" -eq 0 ]
  [ "$(jq -r '.preservedExternal[0]' <<< "$output")" = "hypr.border_size" ]
  [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 9 ]
  [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ]
}

@test "apply is rejected while restore conflicts are pending" {
  run scripts/accessctl apply comfortable --operation-id 99999999-9999-4999-8999-999999999999
  [ "$status" -eq 0 ]
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  run scripts/accessctl restore --operation-id aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
  [ "$status" -ne 0 ]
  run scripts/accessctl apply focus --operation-id bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb
  [ "$status" -ne 0 ]
  [ "$(jq -r '.error' <<< "$output")" = "external-drift-pending" ]
}
