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

if ! "${ADB[@]}" shell cmd notification post --help 2>&1 | grep -q 'usage:.*notification post'; then
  die "this build does not expose the expected 'cmd notification post' shell command"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-c-rear-notifications"
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
  "${ADB[@]}" shell dumpsys display > "$OUT/$label-dumpsys-display.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power.txt" 2>&1 || true
}

post_test_notification() {
  local phase="$1"
  local tag="sable_section_c_${phase}"
  local text="rear_notification_${phase}_test"

  echo
  echo "Posting local Android shell notification:"
  echo "  title=SableSectionC"
  echo "  text=$text"

  "${ADB[@]}" shell cmd notification post \
    -t SableSectionC \
    "$tag" \
    "$text" > "$OUT/$phase-notification-post.txt" 2>&1 || {
      cat "$OUT/$phase-notification-post.txt" >&2
      die "failed to post local test notification"
    }

  sleep 1
  "${ADB[@]}" shell cmd notification list > "$OUT/$phase-notification-list-after-post.txt" 2>&1 || true
}

wait_for_dismissal() {
  local phase="$1"

  echo
  echo "Dismiss the SableSectionC notification from the MAIN notification shade."
  echo "Do this before changing the rear-notification setting, so an old active"
  echo "notification cannot leak into the next phase."
  echo "Press ENTER here after it has been dismissed."
  read -r

  "${ADB[@]}" shell cmd notification list > "$OUT/$phase-notification-list-after-dismiss.txt" 2>&1 || true
}

run_phase() {
  local phase="$1"
  local ui_state="$2"

  echo
  echo "============================================================"
  echo "PHASE: rear notifications $ui_state"
  echo
  echo "In the STOCK rear/SubScreen settings, set rear notifications $ui_state."
  echo "Then turn the rear SubScreen OFF."
  echo "Leave the main display available so you can observe/dismiss notifications."
  echo "When ready, press ENTER."
  read -r

  snapshot "$phase-before"
  post_test_notification "$phase"

  observe "$phase-rear-auto-woke" \
    "After the local notification was posted, did the dark rear SubScreen wake automatically? Answer yes/no/other."

  echo
  echo "Now press Func1 once to wake the rear SubScreen manually."
  echo "Inspect the stock rear notification UI/presentation."
  echo "When you have checked it, press ENTER."
  read -r

  observe "$phase-notification-visible-on-rear" \
    "Was the SableSectionC test notification visible/presented on the rear SubScreen? Answer yes/no/other."

  observe "$phase-rear-behavior-note" \
    "Optional short note about what the rear UI showed (type '-' for none)."

  snapshot "$phase-after"
  wait_for_dismissal "$phase"
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided stock rear-notification toggle test plus local shell notifications"
  echo "collector=tools/section-c-rear-notifications.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "notification_source=com.android.shell"
  echo "notification_channel=shell_cmd"
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section C — rear notification presentation"
echo
echo "This helper changes NO rear setting itself."
echo "You change the stock rear-notification toggle manually when prompted."
echo "It posts a benign LOCAL notification using Android's shell notification command."
echo
echo "Important:"
echo "  - no network message is sent"
echo "  - the test notification package is com.android.shell"
echo "  - dismiss the OFF-phase notification before enabling rear notifications"
echo "  - if stock settings expose an app allow-list and com.android.shell is not"
echo "    selectable, record that in the observation note; a normal-app probe can"
echo "    be used afterward if necessary"
echo

run_phase off OFF
run_phase on ON

snapshot final-on

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Rear-notification capture complete:"
echo "  $OUT"
echo

echo "Visible observations:"
cat "$OUT/OBSERVATIONS.tsv" 2>/dev/null || true

echo
echo "Candidate stock setting diff (OFF -> ON):"
diff -u "$OUT/off-before-settings-all.txt" "$OUT/on-before-settings-all.txt" \
  | grep -Ei '^[-+].*(notif|sub|mini|rear|display|screen)' \
  | grep -Ev '^---|^\+\+\+' || true

echo
echo "SubScreen notification-owner summary:"
grep -nEi \
  'notification|NotificationService|listener|permission|service|subdisplay' \
  "$OUT/on-before-package-subdisplay-launcher.txt" \
  "$OUT/on-before-services-subdisplay-launcher.txt" \
  | head -n 220 || true

echo
echo "Local notification command used by this helper:"
echo 'adb -s "$TITAN_SERIAL" shell cmd notification post -t SableSectionC sable_manual_test rear_notification_manual_test'
