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
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-c-subscreen"
mkdir -p "$OUT"

cleanup_pid=""
remote_getevent_pid=""
remote_getevent_pidfile=""

stop_event_capture() {
  if [[ -n "$remote_getevent_pid" ]]; then
    "${ADB[@]}" shell "kill -INT $remote_getevent_pid" >/dev/null 2>&1 || \
      "${ADB[@]}" shell "kill -TERM $remote_getevent_pid" >/dev/null 2>&1 || true
  fi

  if [[ -n "$cleanup_pid" ]] && kill -0 "$cleanup_pid" 2>/dev/null; then
    wait "$cleanup_pid" 2>/dev/null || true
  fi

  if [[ -n "$remote_getevent_pidfile" ]]; then
    "${ADB[@]}" shell "rm -f $remote_getevent_pidfile" >/dev/null 2>&1 || true
  fi

  cleanup_pid=""
  remote_getevent_pid=""
  remote_getevent_pidfile=""
}

cleanup() {
  stop_event_capture
}
trap cleanup EXIT INT TERM

{
  echo "# Titan 2 Section C guided SubScreen capture"
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=observational capture with user-controlled stock display/power-state changes"
  echo "collector=tools/section-c-subscreen-capture.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo
  adb version 2>/dev/null || true
  echo
  for key in \
    ro.build.display.id \
    ro.build.version.incremental \
    ro.build.version.release \
    ro.build.version.security_patch \
    ro.boot.slot_suffix \
    ro.boot.flash.locked \
    ro.boot.verifiedbootstate \
    ro.boot.vbmeta.device_state
  do
    value="$("${ADB[@]}" shell getprop "$key" 2>/dev/null | tr -d '\r')"
    printf '%-36s %s\n' "$key" "$value"
  done
} > "$OUT/METADATA.txt"

snapshot() {
  local label="$1"

  "${ADB[@]}" shell dumpsys display > "$OUT/$label-dumpsys-display.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window displays > "$OUT/$label-window-displays.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window policy > "$OUT/$label-window-policy.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-dumpsys-input.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys SurfaceFlinger --display-id > "$OUT/$label-surfaceflinger-display-id.txt" 2>&1 || true
  "${ADB[@]}" shell wm size > "$OUT/$label-wm-size.txt" 2>&1 || true
  "${ADB[@]}" shell wm density > "$OUT/$label-wm-density.txt" 2>&1 || true

  "${ADB[@]}" shell '
    for ns in system secure global; do
      echo "===== $ns ====="
      settings list "$ns" 2>/dev/null |
        grep -Ei "subscreen|sub_screen|secondary|mini|display|brightness|rotation|touch|wake" || true
    done
  ' > "$OUT/$label-settings.txt" 2>&1 || true
}

event_capture() {
  local label="$1"
  local instruction="$2"
  local i

  echo
  echo "============================================================"
  echo "$instruction"
  echo
  echo "Press ENTER here to START. There is NO timer."
  read -r

  remote_getevent_pidfile="/data/local/tmp/sable-section-c-getevent-$.pid"
  remote_getevent_pid=""

  "${ADB[@]}" shell "rm -f $remote_getevent_pidfile" >/dev/null 2>&1 || true

  echo "Capture running."
  echo "Perform the phone action, then come back and press ENTER to STOP."
  echo

  {
    echo '$ adb -s <redacted> shell getevent -lt'
    "${ADB[@]}" shell "sh -c 'echo \$\$ > $remote_getevent_pidfile; exec getevent -lt'"
  } > "$OUT/$label-events.txt" 2>&1 &
  cleanup_pid=$!

  for i in {1..30}; do
    remote_getevent_pid="$("${ADB[@]}" shell "cat $remote_getevent_pidfile 2>/dev/null" 2>/dev/null | tr -d '\r\n' || true)"
    [[ "$remote_getevent_pid" =~ ^[0-9]+$ ]] && break
    remote_getevent_pid=""
    sleep 0.1
  done

  if [[ -z "$remote_getevent_pid" ]]; then
    echo "warning: could not obtain remote getevent PID; stopping this capture for safety" >&2
    stop_event_capture
    return 1
  fi

  read -r
  stop_event_capture

  echo "Stopped cleanly: $label"
}

observe_yes_no_other() {
  local label="$1"
  local question="$2"
  local answer

  echo
  echo "$question"
  echo "  y = yes"
  echo "  n = no"
  echo "  o = other / unsure"
  read -r -p "[y/n/o]: " answer
  printf '%s\t%s\n' "$label" "$answer" >> "$OUT/OBSERVATIONS.tsv"
}

echo
echo "Titan 2 Section C — guided rear SubScreen core capture"
echo
echo "This session has no timed input windows."
echo "It will ask for one physical action at a time."
echo "Raw output stays private under artifacts/private/t2-tier1/."
echo
echo "Do not use the Pixel 7 during this session."
echo

echo "STEP 1 — rear display OFF baseline"
echo "Make the rear SubScreen OFF using the normal stock controls."
echo "Leave the main display awake/unlocked so you can verify the rear is dark."
echo "When the rear display is definitely OFF, press ENTER here."
read -r
snapshot rear-off-baseline

event_capture rear-off-single-tap \
  "STEP 2 — with the rear SubScreen OFF, tap the REAR screen once. Do not press Func1."
observe_yes_no_other rear-off-single-tap-woke \
  "Did that single rear-screen tap wake/light the rear SubScreen?"

echo
echo "Return the rear SubScreen to OFF if it woke."
echo "When it is OFF again, press ENTER."
read -r

event_capture rear-off-double-tap \
  "STEP 3 — with the rear SubScreen OFF, double-tap the REAR screen once. Do not press Func1."
observe_yes_no_other rear-off-double-tap-woke \
  "Did that double-tap wake/light the rear SubScreen?"

echo
echo "Return the rear SubScreen to OFF if it woke."
echo "When it is OFF again, press ENTER."
read -r

event_capture rear-func1-wake \
  "STEP 4 — press the UPPER red side button (Func1) once and wait for the rear SubScreen to light."
observe_yes_no_other rear-func1-woke \
  "Did Func1 wake/light the rear SubScreen?"

echo
echo "Leave the rear SubScreen ON."
echo "When it is visibly ON and showing the stock rear UI, press ENTER."
read -r
snapshot rear-on-baseline

event_capture rear-on-touch \
  "STEP 5 — on the LIT rear SubScreen: tap once, then make one slow horizontal swipe. Do not touch the main screen."
snapshot rear-on-after-touch

echo
echo "STEP 6 — screen coupling"
echo "With the rear SubScreen currently ON, press the normal Power button once to turn the MAIN screen off."
echo "Then look at the rear SubScreen without touching it."
echo "Press ENTER here after observing the result."
read -r
snapshot main-off-after-rear-on
observe_yes_no_other rear-stayed-on-after-main-off \
  "After the main screen was turned off, did the rear SubScreen remain visibly ON?"

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Section C core capture complete:"
echo "  $OUT"
echo
echo "Visible observations:"
cat "$OUT/OBSERVATIONS.tsv" 2>/dev/null || true

echo
echo "Rear-touch raw event summary:"
for f in "$OUT"/*-events.txt; do
  echo
  echo "===== $(basename "$f") ====="
  grep -E '/dev/input/event4:|/dev/input/event1:|EV_KEY|EV_ABS' "$f" || true
done

echo
echo "Input association summary:"
for f in "$OUT"/rear-*-dumpsys-input.txt "$OUT"/main-off-*-dumpsys-input.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -nEi -A20 -B4 'sub_touch|AssociatedDisplay|Viewport|Enabled:' "$f" | head -n 180 || true
done
