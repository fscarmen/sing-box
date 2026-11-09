#!/usr/bin/env bash
# Offline regression tests for the registration JSON parser; no VPS changes or API calls.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$SCRIPT_DIR/../sing-box.sh"

# Source just the two functions: sourcing the full installer would execute its main menu.
source <(sed -n '/^jq_exec() {/,/^}/p' "$SCRIPT")
source <(sed -n '/^warp_account_register() {/,/^}/p' "$SCRIPT")
WORK_DIR=/does-not-exist
TEMP_DIR=/does-not-exist
KEY='YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY='
IPV6='2606:4700:110:8a36:df92:102a:9602:fa18'
PASSED=0

account() {
  jq -cn --arg key "$KEY" --arg v6 "$IPV6" --argjson bytes "$1" \
    '{id:"account-id",config:{interface:{addresses:{v6:$v6},private_key:$key},reserved:$bytes}}'
}
expect_success() {
  local label="$1" data="$2" expected="$3"
  if ! warp_account_register "$data"; then echo "FAIL: $label unexpectedly rejected" >&2; exit 1; fi
  if [[ "$WARP_ADDRESS6" != "$IPV6" || "$WARP_PRIVATE_KEY" != "$KEY" || "${WARP_RESERVED[1]},${WARP_RESERVED[2]},${WARP_RESERVED[3]}" != "$expected" ]]; then
    echo "FAIL: $label wrong parsed values" >&2; exit 1
  fi
  printf 'PASS: %s\n' "$label"; ((PASSED+=1))
}
expect_failure() {
  local label="$1" data="$2"
  WARP_ADDRESS6=stale WARP_PRIVATE_KEY=stale WARP_RESERVED[1]=99
  if warp_account_register "$data"; then echo "FAIL: $label unexpectedly accepted" >&2; exit 1; fi
  if [[ -n "${WARP_ADDRESS6-}" || -n "${WARP_PRIVATE_KEY-}" || -n "${WARP_RESERVED[1]-}" ]]; then
    echo "FAIL: $label left stale data" >&2; exit 1
  fi
  printf 'PASS: %s\n' "$label"; ((PASSED+=1))
}

expect_success 'compact JSON' "$(account '[213,57,137]')" '213,57,137'
expect_success 'pretty printed JSON' "$(account '[0,255,128]' | jq .)" '0,255,128'
expect_success 'all boundary values' "$(account '[255,0,255]')" '255,0,255'
expect_failure 'original failing reserved 1371' "$(account '[213,57,1371]')"
expect_failure 'negative reserved' "$(account '[-1,57,71]')"
expect_failure 'fractional reserved' "$(account '[13.5,57,71]')"
expect_failure 'string instead of number' "$(account '["13",57,71]')"
expect_failure 'two reserved entries' "$(account '[13,57]')"
expect_failure 'four reserved entries' "$(account '[13,57,71,1]')"
expect_failure 'null reserved' "$(account 'null')"
expect_failure 'missing id' "$(account '[13,57,71]' | jq 'del(.id)')"
expect_failure 'missing private key' "$(account '[13,57,71]' | jq 'del(.config.interface.private_key)')"
expect_failure 'invalid private key' "$(account '[13,57,71]' | jq '.config.interface.private_key="invalid"')"
expect_failure 'missing IPv6' "$(account '[13,57,71]' | jq 'del(.config.interface.addresses.v6)')"
expect_failure 'invalid IPv6' "$(account '[13,57,71]' | jq '.config.interface.addresses.v6="not-an-address"')"
expect_failure 'truncated JSON' '{"id":"oops","reserved":[1,2,3]'
expect_failure 'empty response' ' '
# Simulate online registration without fetching or executing the remote script.
MOCK_REGISTER_RESPONSE="$(account '[7,18,99]')"
timeout() { printf '%s\n' "$MOCK_REGISTER_RESPONSE"; }
wget() { :; }
if ! warp_account_register; then echo 'FAIL: mocked online registration' >&2; exit 1; fi
[[ "${WARP_RESERVED[1]},${WARP_RESERVED[2]},${WARP_RESERVED[3]}" == '7,18,99' ]] || exit 1
printf 'PASS: mocked online registration\n'; ((PASSED+=1))

# Exercise the unchanged installer fallback path and generated endpoint JSON.
source <(sed -n '/^generate_sing_box_base_conf() {/,/^# 生成 sing-box 配置文件/p' "$SCRIPT" | sed '$d')
find_free_api_port() { printf '9090\n'; }
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
WORK_DIR="$TEST_DIR/work"
TEMP_DIR="$TEST_DIR/temp"
mkdir -p "$WORK_DIR/conf" "$TEMP_DIR"
IS_TUN=is_tun
IS_PREFER_GO=true
STRATEGY=prefer_ipv4
unset BIND_INTERFACE CHATGPT_OUT

# Invalid cached JSON + valid online registration: use newly registered bytes.
account '[213,57,1371]' > "$TEMP_DIR/warp_account.json"
MOCK_REGISTER_RESPONSE="$(account '[1,2,3]')"
generate_sing_box_base_conf
[[ $(jq -c '.endpoints[0].peers[0].reserved' "$WORK_DIR/conf/02_endpoints.json") == '[1,2,3]' ]] || { echo 'FAIL: online retry after invalid cache' >&2; exit 1; }
echo 'PASS: invalid cache -> valid online retry'; ((PASSED+=1))

# Both paths fail: keep original shared-account fallback (without 1371).
account '[213,57,1371]' > "$TEMP_DIR/warp_account.json"
MOCK_REGISTER_RESPONSE="$(account '[213,57,1371]')"
generate_sing_box_base_conf
[[ $(jq -c '.endpoints[0].peers[0].reserved' "$WORK_DIR/conf/02_endpoints.json") == '[78,135,76]' ]] || { echo 'FAIL: original fallback was not used' >&2; exit 1; }
echo 'PASS: invalid cache + invalid online -> shared-account fallback'; ((PASSED+=1))

# Valid cached registration: use the cache instead of the invalid online response.
account '[200,201,202]' > "$TEMP_DIR/warp_account.json"
generate_sing_box_base_conf
[[ $(jq -c '.endpoints[0].peers[0].reserved' "$WORK_DIR/conf/02_endpoints.json") == '[200,201,202]' ]] || { echo 'FAIL: valid cache not used' >&2; exit 1; }
echo 'PASS: valid registration cache is reused'; ((PASSED+=1))

# On machines without TUN support no WARP endpoint should be created.
IS_TUN=no_tun
rm -f "$WORK_DIR/conf/02_endpoints.json"
generate_sing_box_base_conf
[[ ! -f "$WORK_DIR/conf/02_endpoints.json" ]] || { echo 'FAIL: endpoint was generated without TUN' >&2; exit 1; }
echo 'PASS: no-TUN configuration unchanged'; ((PASSED+=1))

echo "All $PASSED WARP regression tests passed."
