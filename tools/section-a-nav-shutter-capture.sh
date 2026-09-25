#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")
PROBE="org.sableos.research.inputprobe"

die() { echo "error: $*" >&2; exit 1; }

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"

model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$model" == "Titan 2" ]] || die "selected device reports '${model:-unknown}', expected Titan 2"

"${ADB[@]}" shell pm path "$PROBE" >/dev/null 2>&1 ||
  die "Input Probe is not installed."

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-a-nav-shutter"
mkdir -p "$OUT"

host_pid=""
remote_pid=""
remote_pidfile=""

stop_capture() {
  if [[ -n "$remote_pid" ]]; then
    "${ADB[@]}" shell "kill -INT $remote_pid" >/dev/null 2>&1 ||
      "${ADB[@]}" shell "kill -TERM $remote_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
    wait "$host_pid" 2>/dev/null || true
  fi
  if [[ -n "$remote_pidfile" ]]; then
    "${ADB[@]}" shell "rm -f $remote_pidfile" >/dev/null 2>&1 || true
  fi
  host_pid=""
  remote_pid=""
  remote_pidfile=""
}
trap stop_capture EXIT INT TERM

snapshot() {
  local label="$1"
  "${ADB[@]}" shell dumpsys activity activities > "$OUT/$label-activities.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window > "$OUT/$label-window.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-input.txt" 2>&1 || true
}

start_probe() {
  "${ADB[@]}" shell am force-stop "$PROBE" >/dev/null 2>&1 || true
  "${ADB[@]}" shell monkey -p "$PROBE" 1 >/dev/null 2>&1 || true
  sleep 1
}

start_camera() {
  "${ADB[@]}" shell am start -a android.media.action.STILL_IMAGE_CAMERA     > "$OUT/camera-launch.txt" 2>&1 || true
  sleep 1
}

capture_one() {
  local label="$1"
  local prompt="$2"
  local i

  echo
  echo "============================================================"
  echo "$prompt"
  echo
  echo "Press ENTER here to START the isolated capture."
  read -r

  "${ADB[@]}" shell logcat -c >/dev/null 2>&1 || true
  snapshot "$label-before"

  remote_pidfile="/data/local/tmp/sable-nav-shutter-$$.pid"
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

  echo "Capture running. Perform ONLY the requested phone action once."
  echo "Then return here and press ENTER to STOP."
  read -r

  stop_capture
  sleep 0.3
  "${ADB[@]}" shell logcat -d -v threadtime > "$OUT/$label-logcat.txt" 2>&1 || true
  snapshot "$label-after"
}

observe() {
  local key="$1"
  local prompt="$2"
  local answer
  echo
  echo "$prompt"
  read -r -p "> " answer
  printf '%s\t%s\n' "$key" "$answer" >> "$OUT/OBSERVATIONS.tsv"
}

optional_nav_test() {
  local label="$1"
  local description="$2"
  local answer

  echo
  read -r -p "Test $description? [y/s(skip)]: " answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    printf '%s\tSKIPPED\n' "$label" >> "$OUT/OBSERVATIONS.tsv"
    return
  fi

  start_probe
  capture_one "$label"     "Input Probe is foreground. Use the physical/emulated control you normally associate with: $description."
  observe "$label-result"     "Visible result? Use: probe=stayed in Input Probe, previous=went back, home=home/launcher, recents=recent-apps UI, cursor=cursor/focus moved, other=<short note>."
}

camera_test() {
  local label="$1"
  local description="$2"

  start_camera
  capture_one "$label"     "Stock Camera should be foreground. Press ONLY: $description."
  observe "$label-result"     "Camera result? Use: photo=photo captured, zoom=zoom/other camera adjustment, none=no visible camera action, switched=left/switched display/app, other=<short note>."
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided navigation/system-key capture plus state-changing stock-Camera shutter candidate test"
  echo "collector=tools/section-a-nav-shutter-capture.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "note=camera phase may create photos in stock Camera"
  "${ADB[@]}" shell cmd package resolve-activity --brief -a android.media.action.STILL_IMAGE_CAMERA 2>/dev/null |
    sed 's/^/resolved_stock_camera=/' || true
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section A — remaining navigation/system keys + shutter candidates"
echo
echo "Important:"
echo "  - Printed labels are only physical prompts; semantics come from captured evidence."
echo "  - Navigation tests are observational."
echo "  - Camera tests MAY SAVE PHOTOS. Delete test photos afterward if desired."
echo "  - No timer is used."
echo

optional_nav_test nav-back "Back / Escape candidate"
optional_nav_test nav-home "Home candidate"
optional_nav_test nav-recents "Recents candidate"
echo
echo "CURSOR/NAVIGATION NOTE:"
echo "  Do NOT use the main touchscreen."
echo "  Do NOT enable keyboard Mouse Mode just to move the pointer."
echo "  These four tests are only for a keyboard-originated arrow/navigation"
echo "  control or gesture that stock firmware presents as Up/Down/Left/Right."
echo "  If you do not know of such a control, SKIP all four; that is a valid result."
echo
optional_nav_test cursor-up "keyboard-originated cursor/navigation Up candidate (not touchscreen or Mouse Mode)"
optional_nav_test cursor-down "keyboard-originated cursor/navigation Down candidate (not touchscreen or Mouse Mode)"
optional_nav_test cursor-left "keyboard-originated cursor/navigation Left candidate (not touchscreen or Mouse Mode)"
optional_nav_test cursor-right "keyboard-originated cursor/navigation Right candidate (not touchscreen or Mouse Mode)"

echo
echo "============================================================"
echo "CAMERA SHUTTER CANDIDATES"
echo
echo "The next steps may create test photos in the stock Camera app."
read -r -p "Continue with shutter candidates? [y/s(skip)]: " camera_go

if [[ "$camera_go" == "y" || "$camera_go" == "Y" ]]; then
  camera_test camera-volume-up "Volume Up once"
  camera_test camera-volume-down "Volume Down once"
  camera_test camera-space "Space once"
  camera_test camera-enter "Enter once"
  camera_test camera-func1 "upper red Func1 once"
  camera_test camera-func2 "lower red Func2 once"
else
  printf 'camera-phase\tSKIPPED\n' >> "$OUT/OBSERVATIONS.tsv"
fi

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Section A navigation/shutter capture complete:"
echo "  $OUT"

echo
echo "Visible observations:"
cat "$OUT/OBSERVATIONS.tsv" 2>/dev/null || true

echo
echo "Raw key/event summary:"
for f in "$OUT"/*-events.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -E 'EV_KEY|/dev/input/event[0-9]+:' "$f" | head -n 120 || true
done

echo
echo "Input Probe / framework key summary:"
for f in "$OUT"/nav-*-logcat.txt "$OUT"/cursor-*-logcat.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -Ei 'SableInputProbe|KeyEvent|interceptKey|PhoneWindowManager|AguiKeyboardShortcut|ActivityTaskManager|WindowManager' "$f" |
    tail -n 180 || true
done

echo
echo "Stock Camera key/action summary:"
for f in "$OUT"/camera-*-logcat.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -Ei 'camera|shutter|capture|KeyEvent|interceptKey|PhoneWindowManager|AguiKeyboardShortcut|volume|FUNC1|FUNC2' "$f" |
    tail -n 180 || true
done
