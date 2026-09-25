#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_FASTBOOT_SERIAL:?Set TITAN_FASTBOOT_SERIAL to the Titan 2 fastboot serial}"
MODE="${1:-}"
if [[ "$MODE" != "bootloader" && "$MODE" != "fastbootd" ]]; then
  echo "usage: TITAN_FASTBOOT_SERIAL=... $0 {bootloader|fastbootd}" >&2
  exit 2
fi

FB=(fastboot -s "$TITAN_FASTBOOT_SERIAL")
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier2/$STAMP-$MODE-fastboot-preflight"
REPORT="$OUT/REPORT-${STAMP}-${MODE}-fastboot-preflight.txt"
mkdir -p "$OUT"

if ! "${FB[@]}" devices 2>/dev/null | grep -q .; then
  echo "error: selected Titan 2 is not visible to fastboot" >&2
  exit 3
fi

getvar() {
  local name="$1"
  "${FB[@]}" getvar "$name" 2>&1 | tr -d '\r'
}

value() {
  local name="$1"
  getvar "$name" | sed -n -E "s/.*$name:[[:space:]]*//p" | tail -n1
}

host_product="$(value product || true)"
is_userspace="$(value is-userspace || true)"
expected_userspace="no"
[[ "$MODE" == "fastbootd" ]] && expected_userspace="yes"

{
  echo "# fastboot getvar all"
  "${FB[@]}" getvar all 2>&1 || true
} > "$OUT/getvar-all.txt"

VARS=(
  product current-slot slot-count unlocked secure is-userspace
  super-partition-name partition-size:super
  snapshot-update-status version-bootloader
)
{
  for v in "${VARS[@]}"; do
    echo "===== $v ====="
    getvar "$v" || true
  done
} > "$OUT/selected-vars.txt"

if [[ "$MODE" == "fastbootd" ]]; then
  {
    slot="$(value current-slot || true)"
    [[ -n "$slot" ]] || slot="a"
    for p in system system_ext product vendor vendor_dlkm odm_dlkm system_dlkm; do
      for suffix in "_$slot" ""; do
        name="$p$suffix"
        echo "===== $name ====="
        getvar "partition-size:$name" || true
        getvar "is-logical:$name" || true
      done
    done
  } > "$OUT/logical-partitions.txt"
fi

status=0
{
  echo "Titan 2 Tier 2 fastboot preflight"
  echo "timestamp_utc=$STAMP"
  echo "requested_mode=$MODE"
  echo "product=$host_product"
  echo "is_userspace=$is_userspace"
  echo "expected_is_userspace=$expected_userspace"
  echo "current_slot=$(value current-slot || true)"
  echo "unlocked=$(value unlocked || true)"
  echo "secure=$(value secure || true)"
  echo "snapshot_update_status=$(value snapshot-update-status || true)"
  echo "super_size=$(value partition-size:super || true)"
  echo

  if [[ "$host_product" != "g71v78c2k_dfl_tee" ]]; then
    echo "FAIL product mismatch"
    status=1
  else
    echo "PASS product identity"
  fi

  if [[ "$is_userspace" != "$expected_userspace" ]]; then
    echo "FAIL mode mismatch: expected is-userspace=$expected_userspace"
    status=1
  else
    echo "PASS fastboot mode"
  fi

  unlocked="$(value unlocked || true)"
  if [[ "$unlocked" == "yes" ]]; then
    echo "PASS bootloader unlocked"
  else
    echo "FAIL bootloader is not reported unlocked"
    status=1
  fi

  snap="$(value snapshot-update-status || true)"
  if [[ -z "$snap" || "$snap" == "none" ]]; then
    echo "PASS no active snapshot update reported"
  else
    echo "BLOCK snapshot-update-status=$snap"
    status=1
  fi

  echo
  echo "This script performs getvar queries only. It does not reboot or flash."
} > "$REPORT"

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo "Fastboot preflight written:"
echo "  $REPORT"
echo "  mode=$MODE result=$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
