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

test_baseline_covers_profile_switches() {
  new_env
  local initial
  initial=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  call apply comfortable --operation-id 56565656-5656-4565-8565-656565656565
  call apply focus --operation-id 57575757-5757-4575-8575-757575757575
  call restore --operation-id 58585858-5858-4585-8585-858585858585
  local restored
  restored=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  local ok=$([ "$STATUS" -eq 0 ] && [ "$initial" = "$restored" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "baseline restores settings introduced by later profiles"; else record_fail "baseline restores settings introduced by later profiles"; fi
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

test_failed_apply_does_not_leave_a_new_baseline() {
  new_env
  export ACCESSCTL_MOCK_FAIL_AFTER=1
  call apply comfortable --operation-id 34343434-3434-4343-8343-343434343434
  local ok=$([ "$STATUS" -ne 0 ] && [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "failed apply removes its uncommitted baseline"; else record_fail "failed apply removes its uncommitted baseline"; fi
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

test_restore_does_not_overwrite_unmanaged_baseline_value() {
  new_env
  call apply comfortable --operation-id 67676767-6767-4676-8676-676767676767
  jq '.values."hypr.blur.enabled" = true' "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" > "$TEST_ROOT/state/omarchy-access-profiles/baseline-with-unmanaged"
  mv "$TEST_ROOT/state/omarchy-access-profiles/baseline-with-unmanaged" "$TEST_ROOT/state/omarchy-access-profiles/baseline.json"
  jq '."hypr.blur.enabled" = false' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 68686868-6868-4686-8686-686868686868
  local ok=$([ "$STATUS" -eq 0 ] && [ "$(jq -r '."hypr.blur.enabled"' "$TEST_ROOT/mock/values.json")" = false ] && [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "restore leaves unmanaged baseline values untouched"; else record_fail "restore leaves unmanaged baseline values untouched"; fi
  cleanup_env
}

test_restore_applies_safe_values_before_conflict_resolution() {
  new_env
  call apply comfortable --operation-id 69696969-6969-4696-8696-696969696969
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 70707070-7070-4707-8707-707070707070
  local ok=$([ "$STATUS" -ne 0 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ] && [ -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ] && jq -e '.conflicts | length == 1' "$TEST_ROOT/state/omarchy-access-profiles/state.json" >/dev/null 2>&1 && echo yes || echo no)
  call resolve-conflict hypr.border_size --keep-external
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 9 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ] && [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "safe restore continues while external conflict is pending"; else record_fail "safe restore continues while external conflict is pending"; fi
  cleanup_env
}

test_restore_tracks_managed_values_across_profile_switches() {
  new_env
  call apply comfortable --operation-id 71717171-7171-4717-8717-717171717171
  call apply focus --operation-id 72727272-7272-4727-8727-727272727272
  jq '."gtk.text.scale" = 1.5' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 73737373-7373-4737-8737-737373737373
  local ok=$([ "$STATUS" -ne 0 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.5 ] && [ "$(jq -r '.details.conflicts[0].id' <<< "$OUTPUT")" = "gtk.text.scale" ] && echo yes || echo no)
  call resolve-conflict gtk.text.scale --keep-external
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.5 ] && [ ! -e "$TEST_ROOT/state/omarchy-access-profiles/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "restore tracks settings managed by earlier profiles"; else record_fail "restore tracks settings managed by earlier profiles"; fi
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
test_baseline_covers_profile_switches
test_rollback
test_failed_apply_does_not_leave_a_new_baseline
test_preview_recovery
test_status_recovers_expired_preview
test_conflict_resolution
test_restore_does_not_overwrite_unmanaged_baseline_value
test_restore_applies_safe_values_before_conflict_resolution
test_restore_tracks_managed_values_across_profile_switches
test_idempotency_and_diagnostics
test_profile_validation
test_invalid_and_symlink_state
test_malformed_state

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
