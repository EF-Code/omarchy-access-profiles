#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
FIXTURE="$SCRIPT_DIR/fixtures/mock-values.json"
PASS=0
FAIL=0

record_pass() { PASS=$((PASS + 1)); printf 'ok - %s\n' "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'not ok - %s\n' "$1" >&2; }

new_env() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/mock"
  cp "$FIXTURE" "$TEST_ROOT/mock/values.json"
  export ACCESSCTL_MOCK_DIR="$TEST_ROOT/mock"
  export ACCESSCTL_CONFIG_HOME="$TEST_ROOT/config"
  export ACCESSCTL_STATE_HOME="$TEST_ROOT/state"
  export ACCESSCTL_RUNTIME_HOME="$TEST_ROOT/runtime"
  unset ACCESSCTL_MOCK_FAIL_AFTER ACCESSCTL_MOCK_UNSUPPORTED
}

cleanup_env() { rm -rf -- "$TEST_ROOT"; }

call() {
  OUTPUT=$("$PROJECT_ROOT/scripts/accessctl" "$@")
  STATUS=$?
  return 0
}

json_has() { jq -e "$1" <<< "$OUTPUT" >/dev/null 2>&1; }

test_plan_read_only() {
  new_env
  call plan comfortable
  local ok=$([ "$STATUS" -eq 0 ] && [ "$(jq '.changes | length' <<< "$OUTPUT")" -eq 8 ] && [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "plan is read-only"; else record_fail "plan is read-only"; fi
  cleanup_env
}

test_capabilities_and_unsupported() {
  new_env
  call capabilities
  local ok=$([ "$STATUS" -eq 0 ] && json_has '.ok and (.capabilities | length == 12)' && echo yes || echo no)
  export ACCESSCTL_MOCK_UNSUPPORTED=gtk.text.scale
  call plan comfortable
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && jq -e '.warnings[0].id == "gtk.text.scale"' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "capability probe and partial support"; else record_fail "capability probe and partial support"; fi
  cleanup_env
}

test_apply_restore() {
  new_env
  local initial
  initial=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  call apply comfortable --operation-id 11111111-1111-4111-8111-111111111111
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.activeProfile == "comfortable"' "$TEST_ROOT/state/omarchy-access-profiles/state.json" >/dev/null 2>&1 && echo yes || echo no)
  call restore --operation-id 22222222-2222-4222-8222-222222222222
  local restored
  restored=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 && "$initial" == "$restored" ]] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "apply and exact baseline restore"; else record_fail "apply and exact baseline restore"; fi
  cleanup_env
}

test_rollback() {
  new_env
  export ACCESSCTL_MOCK_FAIL_AFTER=2
  call apply comfortable --operation-id 33333333-3333-4333-8333-333333333333
  local ok=$([ "$STATUS" -ne 0 ] && [ "$(jq -S -c . "$FIXTURE")" = "$(jq -S -c . "$TEST_ROOT/mock/values.json")" ] && [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/pending.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "transaction rollback after forced failure"; else record_fail "transaction rollback after forced failure"; fi
  cleanup_env
}

test_preview_recovery() {
  new_env
  call preview reduced-motion --seconds 30 --operation-id 44444444-4444-4444-8444-444444444444
  jq '.preview.deadline = 0' "$TEST_ROOT/state/omarchy-access-profiles/state.json" > "$TEST_ROOT/state/expired"
  mv "$TEST_ROOT/state/expired" "$TEST_ROOT/state/omarchy-access-profiles/state.json"
  call recover
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.recoveredPreview == true' <<< "$OUTPUT" >/dev/null 2>&1 && jq -e '.preview == null' "$TEST_ROOT/state/omarchy-access-profiles/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "expired preview recovery"; else record_fail "expired preview recovery"; fi
  cleanup_env
}

test_status_recovers_expired_preview() {
  new_env
  call preview comfortable --seconds 30 --operation-id 45454545-4545-4454-8454-545454545454
  jq '.preview.deadline = 0' "$TEST_ROOT/state/omarchy-access-profiles/state.json" > "$TEST_ROOT/state/expired-status"
  mv "$TEST_ROOT/state/expired-status" "$TEST_ROOT/state/omarchy-access-profiles/state.json"
  call status
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.preview == null and .activeProfile == null' <<< "$OUTPUT" >/dev/null 2>&1 && jq -e '.preview == null' "$TEST_ROOT/state/omarchy-access-profiles/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "status recovers expired preview"; else record_fail "status recovers expired preview"; fi
  cleanup_env
}

test_conflict_resolution() {
  new_env
  call apply comfortable --operation-id 55555555-5555-4555-8555-555555555555
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 66666666-6666-4666-8666-666666666666
  call resolve-conflict hypr.border_size --keep-external
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.activeProfile == null and (.conflicts | length == 0)' "$TEST_ROOT/state/omarchy-access-profiles/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "external conflict resolution"; else record_fail "external conflict resolution"; fi
  cleanup_env
}

test_idempotency_and_diagnostics() {
  new_env
  call apply comfortable --operation-id 77777777-7777-4777-8777-777777777777
  call apply comfortable --operation-id 77777777-7777-4777-8777-777777777777
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.idempotent == true' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  call export-diagnostics
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && jq -e '.ok and (.notes | length == 1)' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "operation idempotency and redacted diagnostics"; else record_fail "operation idempotency and redacted diagnostics"; fi
  cleanup_env
}

test_profile_validation() {
  new_env
  mkdir -p "$TEST_ROOT/config/omarchy-access-profiles"
  jq -n '{schemaVersion:1,profiles:[{id:"bad",name:"Bad",description:"",settings:{"not-registered":true}}]}' > "$TEST_ROOT/config/omarchy-access-profiles/profiles.json"
  call list-profiles
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error == "profile data is invalid"' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "user profile schema validation"; else record_fail "user profile schema validation"; fi
  cleanup_env
}

test_invalid_and_symlink_state() {
  new_env
  call plan 'comfortable;touch /tmp/accessctl-should-not-exist'
  local ok=$([ "$STATUS" -ne 0 ] && echo yes || echo no)
  local link_root="$TEST_ROOT/symlink-state"
  mkdir -p "$link_root/omarchy-access-profiles" "$TEST_ROOT/target"
  ln -s "$TEST_ROOT/target/state.json" "$link_root/omarchy-access-profiles/state.json"
  ACCESSCTL_STATE_HOME="$link_root" call list-profiles
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "strict input and symlink rejection"; else record_fail "strict input and symlink rejection"; fi
  cleanup_env
}

test_malformed_state() {
  new_env
  mkdir -p "$TEST_ROOT/state/omarchy-access-profiles"
  printf '%s\n' '{not-json' > "$TEST_ROOT/state/omarchy-access-profiles/state.json"
  call status
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error | contains("malformed")' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "malformed state fails closed"; else record_fail "malformed state fails closed"; fi
  cleanup_env
}

test_plan_read_only
test_capabilities_and_unsupported
test_apply_restore
test_rollback
test_preview_recovery
test_status_recovers_expired_preview
test_conflict_resolution
test_idempotency_and_diagnostics
test_profile_validation
test_invalid_and_symlink_state
test_malformed_state

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
