#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 ADB serial}"
ADB=(adb -s "$TITAN_SERIAL")
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier2/$STAMP-sable-n0-smoke"
REPORT="$OUT/REPORT.txt"
mkdir -p "$OUT"

if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  echo "error: target is not reachable through adb" >&2
  exit 2
fi

cap() {
  local name="$1"; shift
  {
    echo "# $*"
    timeout 90 "${ADB[@]}" shell "$*" 2>&1 || true
  } > "$OUT/$name"
}

cap identity.txt "getprop | grep -E 'ro.product|ro.build|ro.system|ro.vendor|ro.boot|ro.vndk|sys.boot_completed' | sort"
cap display.txt "dumpsys display"
cap window.txt "dumpsys window displays"
cap input.txt "dumpsys input"
cap proc-input.txt "cat /proc/bus/input/devices"
cap services.txt "service list"
cap lshal.txt "lshal 2>/dev/null || true"
cap power.txt "dumpsys power"
cap camera.txt "dumpsys media.camera 2>/dev/null || true"
cap audio.txt "dumpsys audio 2>/dev/null || true"
cap sensors.txt "dumpsys sensorservice 2>/dev/null || true"
cap network.txt "dumpsys wifi 2>/dev/null; dumpsys bluetooth_manager 2>/dev/null"
cap boot-logcat.txt "logcat -b all -d"

secs="${T2_N0_GETEVENT_SECONDS:-0}"
if [[ "$secs" =~ ^[0-9]+$ ]] && (( secs > 0 )); then
  echo "Capturing getevent for $secs seconds."
  echo "During this window press: Q, Space, Enter, Shift, Alt, Sym, Func1, Func2."
  {
    echo "# bounded getevent capture: $secs seconds"
    timeout "$secs" "${ADB[@]}" shell getevent -lt 2>&1 || true
  } > "$OUT/getevent.txt"
fi

boot_completed="$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
build="$("${ADB[@]}" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
slot="$("${ADB[@]}" shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r')"
vbstate="$("${ADB[@]}" shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r')"

status=0
{
  echo "Titan 2 Sable N0 smoke capture"
  echo "timestamp_utc=$STAMP"
  echo "build=$build"
  echo "slot=$slot"
  echo "verified_boot=$vbstate"
  echo "boot_completed=$boot_completed"
  echo
  if [[ "$boot_completed" == "1" ]]; then echo "PASS boot completed"; else echo "FAIL boot not completed"; status=1; fi
  if grep -q "TitanKey" "$OUT/input.txt" "$OUT/proc-input.txt"; then echo "PASS TitanKey present"; else echo "FAIL TitanKey missing"; status=1; fi
  if grep -q "touchPad" "$OUT/input.txt" "$OUT/proc-input.txt"; then echo "PASS touchPad present"; else echo "FAIL touchPad missing"; status=1; fi
  if grep -Eq "1440[ x,]+1440|1440 x 1440" "$OUT/display.txt"; then echo "PASS primary 1440x1440 evidence present"; else echo "CHECK primary display geometry manually"; fi
  if grep -Eq "410[ x,]+502|410 x 502" "$OUT/display.txt"; then echo "PASS rear 410x502 display evidence present"; else echo "CHECK rear display availability manually"; fi
  echo
  echo "GETEVENT_CAPTURE=$([[ -f "$OUT/getevent.txt" ]] && echo PRESENT || echo SKIPPED)"
  echo "RESULT=$([[ $status -eq 0 ]] && echo PASS_BASIC || echo NEEDS_TRIAGE)"
  echo
  echo "Raw logcat and subsystem dumps are private evidence."
} > "$REPORT"

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo "Sable N0 smoke report written:"
echo "  $REPORT"
echo "  evidence=$OUT"
echo "  result=$([[ $status -eq 0 ]] && echo PASS_BASIC || echo NEEDS_TRIAGE)"
exit "$status"
