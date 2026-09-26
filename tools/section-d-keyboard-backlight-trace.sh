#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")
PKG="com.agui.settings"

die() { echo "error: $*" >&2; exit 1; }

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"

model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$model" == "Titan 2" ]] || die "selected device reports '${model:-unknown}', expected Titan 2"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-d-keyboard-backlight"
mkdir -p "$OUT"

snapshot() {
  local label="$1"

  "${ADB[@]}" shell '
    echo "===== system ====="; settings list system
    echo "===== secure ====="; settings list secure
    echo "===== global ====="; settings list global
  ' > "$OUT/$label-settings-all.txt" 2>&1 || true

  "${ADB[@]}" shell dumpsys lights > "$OUT/$label-dumpsys-lights.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-dumpsys-input.txt" 2>&1 || true

  "${ADB[@]}" shell '
    for d in /sys/class/leds/* /sys/class/backlight/*; do
      [ -d "$d" ] || continue
      echo "===== $d ====="
      for f in brightness actual_brightness max_brightness trigger delay_on delay_off; do
        if [ -r "$d/$f" ]; then
          printf "%s=" "$f"
          cat "$d/$f"
        fi
      done
    done
  ' > "$OUT/$label-class-light-state.txt" 2>&1 || true

  "${ADB[@]}" shell '
    find /sys -type f \( -name brightness -o -name actual_brightness -o -name max_brightness \) -readable 2>/dev/null |
      grep -Ei "key|kbd|keyboard|led|light" |
      sort |
      while read -r f; do
        printf "%s=" "$f"
        cat "$f" 2>/dev/null || true
      done
  ' > "$OUT/$label-readable-light-files.txt" 2>&1 || true
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided keyboard-backlight minimum-vs-maximum trace"
  echo "collector=tools/section-d-keyboard-backlight-trace.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

"${ADB[@]}" shell dumpsys package "$PKG" > "$OUT/com-agui-settings-dumpsys.txt" 2>&1 || true
"${ADB[@]}" shell pm path "$PKG" > "$OUT/com-agui-settings-path.txt" 2>&1 || true

echo
echo "Titan 2 Section D — keyboard backlight backend trace"
echo
echo "This test uses the actual stock UI semantics: Automatic / duration / brightness."
echo "No boolean keyboard-light ON/OFF is assumed."
echo

echo "STEP 1 — minimum"
echo "Open Keyboard backlight settings."
echo "Turn 'Automatic keyboard light' OFF so ambient light cannot change the result."
echo "Move 'Backlight brightness' to MINIMUM."
echo "When stable, press ENTER."
read -r
snapshot min

"${ADB[@]}" shell logcat -c >/dev/null 2>&1 || true

echo
echo "STEP 2 — maximum"
echo "Move ONLY 'Backlight brightness' to MAXIMUM."
echo "Do not change Automatic mode or duration."
echo "When the keyboard is visibly at maximum brightness, press ENTER."
read -r

"${ADB[@]}" shell logcat -d -v threadtime > "$OUT/min-to-max-logcat.txt" 2>&1 || true
snapshot max

echo
echo "Return brightness to your preferred value, then press ENTER."
read -r

# Keep a private APK copy for strings-only ownership/path inspection.
apk_path="$("${ADB[@]}" shell pm path "$PKG" 2>/dev/null | sed -n 's/^package://p' | head -n1 | tr -d '\r')"
if [[ -n "$apk_path" ]]; then
  "${ADB[@]}" pull "$apk_path" "$OUT/AguiSettings.apk" >/dev/null 2>&1 || true
  if [[ -f "$OUT/AguiSettings.apk" ]]; then
    strings "$OUT/AguiSettings.apk" |
      grep -Ei 'keyboard.{0,40}(led|light|backlight)|/sys/.{0,120}(key|kbd|led|light)|writeDataToFile' |
      sort -u > "$OUT/apk-strings-keyboard-light.txt" || true
  fi
fi

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Keyboard-backlight targeted trace complete:"
echo "  $OUT"

echo
echo "Settings diff (MIN -> MAX):"
diff -u "$OUT/min-settings-all.txt" "$OUT/max-settings-all.txt" |
  grep -Ei '^[-+].*(keyboard|key|led|backlight|light|brightness)' |
  grep -Ev '^---|^\+\+\+' || true

echo
echo "Readable light/sysfs diff (MIN -> MAX):"
diff -u "$OUT/min-class-light-state.txt" "$OUT/max-class-light-state.txt" || true
diff -u "$OUT/min-readable-light-files.txt" "$OUT/max-readable-light-files.txt" || true

echo
echo "Input/lights service clues:"
for f in "$OUT/min-dumpsys-input.txt" "$OUT/max-dumpsys-input.txt" "$OUT/min-dumpsys-lights.txt" "$OUT/max-dumpsys-lights.txt"; do
  echo
  echo "===== $(basename "$f") ====="
  grep -nEi -A8 -B4 'keyboard.{0,20}backlight|backlight|light' "$f" | head -n 140 || true
done

echo
echo "Vendor log clues during MIN -> MAX:"
grep -Ei 'KeyboardLED|keyboard.*(led|light|backlight)|AguiUtilsTools|writeDataToFile|brightness|backlight'   "$OUT/min-to-max-logcat.txt" | tail -n 220 || true

echo
echo "AguiSettings APK string clues:"
cat "$OUT/apk-strings-keyboard-light.txt" 2>/dev/null | head -n 220 || true
