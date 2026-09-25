#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")
PKG="org.sableos.research.inputprobe"
RECEIVER="$PKG/.ResearchNotificationReceiver"
ACTION_POST="$PKG.POST_TEST_NOTIFICATION"
ACTION_CANCEL="$PKG.CANCEL_TEST_NOTIFICATION"

die() {
  echo "error: $*" >&2
  exit 1
}

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"

model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$model" == "Titan 2" ]] || die "selected device reports '${model:-unknown}', expected Titan 2"

"${ADB[@]}" shell pm path "$PKG" >/dev/null 2>&1 ||
  die "Input Probe is not installed. Rebuild/install tools/input-probe first."

if ! "${ADB[@]}" shell dumpsys package "$PKG" 2>/dev/null |
  grep -q 'android.permission.POST_NOTIFICATIONS: granted=true'; then
  die "Input Probe notification permission is not granted. Rebuild/install the updated Input Probe first."
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-c-rear-notifications-app"
mkdir -p "$OUT"

observe() {
  local key="$1"
  local prompt="$2"
  local answer

  echo
  echo "$prompt"
  read -r -p "> " answer
  printf '%s\t%s\n' "$key" "$answer" >> "$OUT/OBSERVATIONS.tsv"
}

snapshot() {
  local label="$1"

  "${ADB[@]}" shell '
    echo "===== system ====="
    settings list system
    echo "===== secure ====="
    settings list secure
    echo "===== global ====="
    settings list global
  ' > "$OUT/$label-settings-all.txt" 2>&1 || true

  "${ADB[@]}" shell dumpsys notification > "$OUT/$label-dumpsys-notification.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys package com.agui.subdisplay.launcher > "$OUT/$label-package-subdisplay-launcher.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys activity services com.agui.subdisplay.launcher > "$OUT/$label-services-subdisplay-launcher.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys package "$PKG" > "$OUT/$label-package-input-probe.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys display > "$OUT/$label-dumpsys-display.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power.txt" 2>&1 || true
}

post_test_notification() {
  local phase="$1"

  "${ADB[@]}" shell logcat -c >/dev/null 2>&1 || true

  echo
  echo "Posting LOCAL notification from installed Input Probe:"
  echo "  package=$PKG"
  echo "  phase=$phase"

  "${ADB[@]}" shell am broadcast     -n "$RECEIVER"     -a "$ACTION_POST"     --es phase "$phase"     > "$OUT/$phase-broadcast-post.txt" 2>&1 || {
      cat "$OUT/$phase-broadcast-post.txt" >&2
      die "failed to ask Input Probe to post notification"
    }

  sleep 1
  "${ADB[@]}" shell cmd notification list > "$OUT/$phase-notification-list-after-post.txt" 2>&1 || true
  "${ADB[@]}" shell logcat -d -v threadtime > "$OUT/$phase-logcat-after-post.txt" 2>&1 || true
}

cancel_test_notification() {
  local phase="$1"

  "${ADB[@]}" shell am broadcast     -n "$RECEIVER"     -a "$ACTION_CANCEL"     > "$OUT/$phase-broadcast-cancel.txt" 2>&1 || true
  sleep 0.5
  "${ADB[@]}" shell cmd notification list > "$OUT/$phase-notification-list-after-cancel.txt" 2>&1 || true
}

run_phase() {
  local phase="$1"
  local allowed="$2"

  echo
  echo "============================================================"
  echo "PHASE: Input Probe rear-notification access = $allowed"
  echo
  echo "In the STOCK SubScreen notification settings:"
  echo "  1. Leave the overall rear-notification feature ENABLED."
  echo "  2. Set Input Probe specifically to $allowed in the app allow-list."
  echo "  3. Turn the rear SubScreen OFF."
  echo
  echo "When ready, press ENTER."
  read -r

  snapshot "$phase-before"
  post_test_notification "$phase"

  observe "$phase-rear-auto-woke"     "After Input Probe posted the notification, did the dark rear SubScreen wake automatically? Answer yes/no/other."

  echo
  echo "Now press Func1 once to wake the rear SubScreen manually."
  echo "Inspect the rear notification UI."
  echo "When you have checked it, press ENTER."
  read -r

  observe "$phase-notification-visible-on-rear"     "Was the SableSectionC Input Probe notification visible/presented on the rear SubScreen? Answer yes/no/other."

  observe "$phase-rear-behavior-note"     "Optional short note about what the rear UI showed (type '-' for none)."

  snapshot "$phase-after"
  cancel_test_notification "$phase"
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided rear notification app allow-list test"
  echo "collector=tools/section-c-rear-notifications.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "notification_source=$PKG"
  echo "notification_channel=sable_research"
  echo "state_change=manual stock SubScreen allow-list toggle plus local app notification"
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section C — rear notification app allow-list"
echo
echo "This version uses the installed Input Probe as the notification source."
echo "It does NOT use com.android.shell."
echo
echo "The helper expects the overall rear-notification feature to remain ON."
echo "Only Input Probe's per-app allow-list entry changes between phases."
echo

run_phase blocked BLOCKED
run_phase allowed ALLOWED

snapshot final-allowed

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0     | sort -z     | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Rear-notification app test complete:"
echo "  $OUT"
echo

echo "Visible observations:"
cat "$OUT/OBSERVATIONS.tsv" 2>/dev/null || true

echo
echo "Candidate setting diff (Input Probe BLOCKED -> ALLOWED):"
diff -u "$OUT/blocked-before-settings-all.txt" "$OUT/allowed-before-settings-all.txt"   | grep -Ei '^[-+].*(notif|sub|mini|rear|display|screen|inputprobe|sable)'   | grep -Ev '^---|^\+\+\+' || true

echo
echo "SubScreen notification decision/log summary:"
for f in "$OUT"/blocked-logcat-after-post.txt "$OUT"/allowed-logcat-after-post.txt; do
  echo
  echo "===== $(basename "$f") ====="
  grep -Ei 'subdisplay|notification|inputprobe|SableSectionC|sable_research' "$f" | tail -n 160 || true
done

echo
echo "SubScreen notification-owner summary:"
grep -nEi   'notification|NotificationService|listener|CONTROL_DISPLAY_BRIGHTNESS|ASSOCIATE_INPUT_DEVICE_TO_DISPLAY|service|subdisplay'   "$OUT/allowed-before-package-subdisplay-launcher.txt"   "$OUT/allowed-before-services-subdisplay-launcher.txt"   | head -n 240 || true

echo
echo "Manual Input Probe notification command:"
echo 'adb -s "$TITAN_SERIAL" shell am broadcast -n org.sableos.research.inputprobe/.ResearchNotificationReceiver -a org.sableos.research.inputprobe.POST_TEST_NOTIFICATION --es phase manual'
