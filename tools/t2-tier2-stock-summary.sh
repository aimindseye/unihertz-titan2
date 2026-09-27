#!/usr/bin/env bash
set -euo pipefail

# Emit the minimum normalized Titan 2 Tier 2 stock-baseline summary.
#
# This helper performs only read-only ADB property reads. T2_MUTATION_LEVEL must
# describe the highest mutation level used by the *manual test session* whose
# results are being summarized.
#
# Required environment:
#   TITAN_SERIAL
#   T2_K_STATUS=PASS|PARTIAL
#   T2_J_STATUS=PASS|PARTIAL
#   T2_I_STATUS=PASS|PARTIAL
#   T2_L_STATUS=PASS|PARTIAL
#   T2_MUTATION_LEVEL=READ_ONLY|USER_SETTING_CHANGE|STATE_CHANGING

: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 adb serial}"
: "${T2_K_STATUS:?Set T2_K_STATUS=PASS or PARTIAL}"
: "${T2_J_STATUS:?Set T2_J_STATUS=PASS or PARTIAL}"
: "${T2_I_STATUS:?Set T2_I_STATUS=PASS or PARTIAL}"
: "${T2_L_STATUS:?Set T2_L_STATUS=PASS or PARTIAL}"
: "${T2_MUTATION_LEVEL:?Set T2_MUTATION_LEVEL=READ_ONLY, USER_SETTING_CHANGE, or STATE_CHANGING}"

require_section_status() {
  local name="$1"
  local value="$2"
  case "$value" in
    PASS|PARTIAL) ;;
    *)
      echo "ERROR: $name must be PASS or PARTIAL (got: $value)" >&2
      exit 2
      ;;
  esac
}

require_mutation_level() {
  case "$1" in
    READ_ONLY|USER_SETTING_CHANGE|STATE_CHANGING) ;;
    *)
      echo "ERROR: T2_MUTATION_LEVEL must be READ_ONLY, USER_SETTING_CHANGE, or STATE_CHANGING" >&2
      exit 2
      ;;
  esac
}

require_section_status T2_K_STATUS "$T2_K_STATUS"
require_section_status T2_J_STATUS "$T2_J_STATUS"
require_section_status T2_I_STATUS "$T2_I_STATUS"
require_section_status T2_L_STATUS "$T2_L_STATUS"
require_mutation_level "$T2_MUTATION_LEVEL"

adb -s "$TITAN_SERIAL" get-state >/dev/null

prop() {
  adb -s "$TITAN_SERIAL" shell getprop "$1" 2>/dev/null | tr -d '\r'
}

model="$(prop ro.product.model)"
vendor_model="$(prop ro.vendor.product.model)"
if [[ "$model" != "Titan 2" && "$vendor_model" != "Titan 2" ]]; then
  echo "ERROR: selected adb target is not identified as Titan 2" >&2
  exit 3
fi

build="$(prop ro.build.display.id)"
if [[ -z "$build" ]]; then
  build="$(prop ro.build.version.incremental)"
fi
if [[ -z "$build" ]]; then
  echo "ERROR: unable to determine stock build" >&2
  exit 3
fi

slot="$(prop ro.boot.slot_suffix)"
slot="${slot#_}"
if [[ -z "$slot" ]]; then
  slot="$(prop ro.boot.slot)"
fi
case "$slot" in
  a|b) ;;
  *)
    echo "ERROR: unable to determine active slot a/b (got: $slot)" >&2
    exit 3
    ;;
esac

flash_locked="$(prop ro.boot.flash.locked)"
case "$flash_locked" in
  0) lock_state="unlocked" ;;
  1) lock_state="locked" ;;
  *)
    echo "ERROR: unable to determine lock state from ro.boot.flash.locked (got: $flash_locked)" >&2
    exit 3
    ;;
esac

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="artifacts/private/t2-tier2/${timestamp}-stock-baseline-summary"
mkdir -p "$out_dir"
report="$out_dir/REPORT-${timestamp}-stock-baseline-summary.txt"

cat >"$report" <<EOF
Titan 2 Tier 2 normalized stock baseline summary
timestamp_utc=$timestamp

TITAN2_TIER2_K_STOCK_BASELINE=$T2_K_STATUS
TITAN2_TIER2_J_STOCK_BASELINE=$T2_J_STATUS
TITAN2_TIER2_I_STOCK_BASELINE=$T2_I_STATUS
TITAN2_TIER2_L_STOCK_BASELINE=$T2_L_STATUS

BUILD=$build
ACTIVE_SLOT=$slot
LOCK_STATE=$lock_state
MUTATION_LEVEL=$T2_MUTATION_LEVEL
PRIVATE_IDENTIFIERS_REDACTED=YES
EOF

echo "Titan 2 Tier 2 stock summary written:"
echo "  $report"
cat "$report"
