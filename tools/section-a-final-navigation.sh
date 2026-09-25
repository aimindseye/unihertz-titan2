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

"${ADB[@]}" shell pm path "$PROBE" >/dev/null 2>&1 || die "Input Probe is not installed."

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-a-final-navigation"
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
  [[ -n "$remote_pidfile" ]] && "${ADB[@]}" shell "rm -f $remote_pidfile" >/dev/null 2>&1 || true
  host_pid=""
  remote_pid=""
  remote_pidfile=""
}
trap stop_capture EXIT INT TERM

start_probe() {
  "${ADB[@]}" shell am force-stop "$PROBE" >/dev/null 2>&1 || true
  "${ADB[@]}" shell monkey -p "$PROBE" 1 >/dev/null 2>&1 || true
  sleep 1
}

snapshot() {
  local label="$1"
  "${ADB[@]}" shell dumpsys activity activities > "$OUT/$label-activities.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window > "$OUT/$label-window.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-input.txt" 2>&1 || true
}

capture_one() {
  local label="$1"
  local prompt="$2"
  local i

  echo
  echo "============================================================"
  echo "$prompt"
  echo
  echo "Press ENTER here to START."
  read -r

  "${ADB[@]}" shell logcat -c >/dev/null 2>&1 || true
  snapshot "$label-before"

  remote_pidfile="/data/local/tmp/sable-final-nav-$$.pid"
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

  echo "Capture running. Perform ONLY the requested action once."
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

system_key_test() {
  local label="$1"
  local description="$2"

  start_probe
  capture_one "$label"     "Input Probe is foreground. Press the physical/capacitive system control you normally use for: $description"
  observe "$label-result"     "Visible result? Use one of: probe / previous / home / recents / other=<short note>."
}

keyboard_swipe_test() {
  local label="$1"
  local description="$2"

  start_probe
  capture_one "$label"     "Mouse Mode must remain OFF. Do NOT touch the main screen. On the physical keyboard capacitive surface, make ONE $description swipe."
  observe "$label-result"     "Visible result? Use: none / scroll / focus / cursor / other=<short note>."
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided final navigation capture"
  echo "collector=tools/section-a-final-navigation.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section A — final navigation pass"
echo
echo "This intentionally DOES NOT test mouse-pointer movement."
echo "Main touchscreen input is not part of these tests."
echo

system_key_test nav-back "Back"
system_key_test nav-home "Home"
system_key_test nav-recents "Recents"

echo
echo "============================================================"
echo "OPTIONAL keyboard-surface navigation/scroll test"
echo
echo "These are NOT mouse-mode tests."
echo "Use the capacitive PHYSICAL KEYBOARD surface with Mouse Mode OFF."
echo "If stock firmware has no useful directional/scroll behavior in this mode,"
echo "skip this whole phase."
read -r -p "Test keyboard-surface swipes? [y/s(skip)]: " do_swipes

if [[ "$do_swipes" == "y" || "$do_swipes" == "Y" ]]; then
  keyboard_swipe_test kbd-swipe-up "UPWARD"
  keyboard_swipe_test kbd-swipe-down "DOWNWARD"
  keyboard_swipe_test kbd-swipe-left "LEFT"
  keyboard_swipe_test kbd-swipe-right "RIGHT"
else
  printf 'keyboard-surface-swipes\tSKIPPED\n' >> "$OUT/OBSERVATIONS.tsv"
fi

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Final navigation capture complete:"
echo "  $OUT"

echo
echo "Visible observations:"
cat "$OUT/OBSERVATIONS.tsv" 2>/dev/null || true

echo
echo "Raw navigation event summary:"
for f in "$OUT"/*-events.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -E 'EV_KEY|EV_REL|EV_ABS|/dev/input/event[0-9]+:' "$f" | head -n 160 || true
done

echo
echo "Android/framework navigation summary:"
for f in "$OUT"/*-logcat.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -Ei 'SableInputProbe|KeyEvent|MotionEvent|interceptKey|PhoneWindowManager|AguiKeyboardShortcut|ActivityTaskManager|WindowManager|InputReader' "$f" |
    tail -n 180 || true
done
