#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")

die() {
  echo "error: $*" >&2
  exit 1
}

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"

model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$model" == "Titan 2" ]] || die "selected device reports '${model:-unknown}', expected Titan 2"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-c-touch-verify"
mkdir -p "$OUT"

remote_pid=""
remote_pidfile=""
host_pid=""

stop_capture() {
  if [[ -n "$remote_pid" ]]; then
    "${ADB[@]}" shell "kill -INT $remote_pid" >/dev/null 2>&1 || \
      "${ADB[@]}" shell "kill -TERM $remote_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
    wait "$host_pid" 2>/dev/null || true
  fi
  if [[ -n "$remote_pidfile" ]]; then
    "${ADB[@]}" shell "rm -f $remote_pidfile" >/dev/null 2>&1 || true
  fi
  remote_pid=""
  remote_pidfile=""
  host_pid=""
}
trap stop_capture EXIT INT TERM

snapshot_input() {
  local label="$1"
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-dumpsys-input.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys display > "$OUT/$label-dumpsys-display.txt" 2>&1 || true
}

capture_touch() {
  local label="$1"
  local instruction="$2"
  local i

  echo
  echo "============================================================"
  echo "$instruction"
  echo
  echo "Press ENTER here to START. There is NO timer."
  read -r

  remote_pidfile="/data/local/tmp/sable-section-c-touch-$$.pid"
  "${ADB[@]}" shell "rm -f $remote_pidfile" >/dev/null 2>&1 || true

  {
    echo '$ adb -s <redacted> shell getevent -lt'
    "${ADB[@]}" shell "sh -c 'echo \$\$ > $remote_pidfile; exec getevent -lt'"
  } > "$OUT/$label-events.txt" 2>&1 &
  host_pid=$!

  for i in {1..30}; do
    remote_pid="$("${ADB[@]}" shell "cat $remote_pidfile 2>/dev/null" 2>/dev/null | tr -d '\r\n' || true)"
    [[ "$remote_pid" =~ ^[0-9]+$ ]] && break
    remote_pid=""
    sleep 0.1
  done

  [[ -n "$remote_pid" ]] || die "could not obtain remote getevent PID"

  echo "Capture running. Perform the requested rear-screen action."
  echo "Then come back and press ENTER to STOP."
  read -r

  stop_capture
  echo "Stopped cleanly: $label"
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided read-only touch verification"
  echo "collector=tools/section-c-touch-verify.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section C — rear touch verification"
echo "This only re-checks whether sub_touch emits while rear display is OFF vs ON."
echo

echo "STEP 1 — rear display OFF"
echo "Make the rear SubScreen OFF and leave the main display awake."
echo "When rear is definitely dark, press ENTER."
read -r
snapshot_input rear-off-before
capture_touch rear-off-touch \
  "With the rear SubScreen OFF: tap the rear screen once, then make one slow horizontal swipe."
snapshot_input rear-off-after

echo
echo "STEP 2 — rear display ON"
echo "Wake the rear SubScreen with Func1 and leave it visibly ON."
echo "When the stock rear UI is visible, press ENTER."
read -r
snapshot_input rear-on-before
capture_touch rear-on-touch \
  "With the rear SubScreen ON: tap once, then make one slow horizontal swipe."
snapshot_input rear-on-after

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Touch verification complete:"
echo "  $OUT"

echo
echo "Raw event4 comparison:"
for f in "$OUT"/rear-*-events.txt; do
  echo
  echo "===== $(basename "$f") ====="
  grep -E '/dev/input/event4:|EV_KEY|EV_ABS' "$f" || true
done

echo
echo "InputReader sub_touch comparison:"
for f in "$OUT"/rear-*-dumpsys-input.txt; do
  echo
  echo "===== $(basename "$f") ====="
  grep -nA65 -B4 -E '^  Device [0-9]+: sub_touch$' "$f" | head -n 90 || true
done
