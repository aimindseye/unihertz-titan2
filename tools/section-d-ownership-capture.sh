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
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-d-ownership"
mkdir -p "$OUT"

PACKAGES=(
  com.agui.settings
  com.agui.subdisplay.launcher
  com.agui.shortcutsettings
  com.agui.keyboard
  com.agui.spacebarkey
  com.iqqijni.bbkeyboard
  com.agui.rotationcontrol
  com.android.settings
  com.android.systemui
)

capture_settings() {
  local label="$1"
  "${ADB[@]}" shell '
    echo "===== system ====="
    settings list system
    echo "===== secure ====="
    settings list secure
    echo "===== global ====="
    settings list global
  ' > "$OUT/$label-settings-all.txt" 2>&1 || true
}

capture_leds() {
  local label="$1"
  "${ADB[@]}" shell '
    for d in /sys/class/leds/*; do
      [ -d "$d" ] || continue
      echo "===== $d ====="
      for f in brightness max_brightness trigger delay_on delay_off; do
        if [ -r "$d/$f" ]; then
          printf "%s=" "$f"
          cat "$d/$f"
        fi
      done
    done
  ' > "$OUT/$label-leds.txt" 2>&1 || true

  "${ADB[@]}" shell dumpsys lights > "$OUT/$label-dumpsys-lights.txt" 2>&1 || true
}

capture_static() {
  "${ADB[@]}" shell dumpsys input > "$OUT/static-dumpsys-input.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys input_method > "$OUT/static-dumpsys-input-method.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys accessibility > "$OUT/static-dumpsys-accessibility.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window policy > "$OUT/static-window-policy.txt" 2>&1 || true
  "${ADB[@]}" shell cmd overlay list > "$OUT/static-overlays.txt" 2>&1 || true
  "${ADB[@]}" shell service list > "$OUT/static-services.txt" 2>&1 || true
  "${ADB[@]}" shell pm list packages -f > "$OUT/static-packages-with-paths.txt" 2>&1 || true

  for pkg in "${PACKAGES[@]}"; do
    safe="${pkg//./_}"
    "${ADB[@]}" shell pm path "$pkg" > "$OUT/pkg-$safe-path.txt" 2>&1 || true
    "${ADB[@]}" shell dumpsys package "$pkg" > "$OUT/pkg-$safe-dumpsys.txt" 2>&1 || true
    "${ADB[@]}" shell dumpsys activity services "$pkg" > "$OUT/pkg-$safe-services.txt" 2>&1 || true
  done
}

snapshot_backlight() {
  local label="$1"
  capture_settings "$label"
  capture_leds "$label"
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-dumpsys-input.txt" 2>&1 || true
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=read-only ownership inventory plus manual stock keyboard-backlight toggle"
  echo "collector=tools/section-d-ownership-capture.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section D — stock implementation ownership"
echo
echo "Phase 1 captures known package/service/overlay owners."
echo "Phase 2 performs one guided keyboard-backlight minimum -> higher comparison."
echo "Only normal stock UI toggles are changed manually."
echo

echo "Capturing static ownership inventory..."
capture_static
capture_settings static
capture_leds static

echo
echo "============================================================"
echo "KEYBOARD BACKLIGHT — minimum baseline"
echo
echo "Open the stock Keyboard backlight page, turn Automatic keyboard light OFF,"
echo "and move Backlight brightness to MINIMUM. Do not change unrelated settings."
echo "When the slider is at minimum, press ENTER."
read -r
snapshot_backlight backlight-min

"${ADB[@]}" shell logcat -c >/dev/null 2>&1 || true

echo
echo "============================================================"
echo "KEYBOARD BACKLIGHT — higher brightness"
echo
echo "Move the same Backlight brightness slider to a clearly higher value."
echo "Wait until the keyboard brightness changes, then press ENTER."
read -r

"${ADB[@]}" shell logcat -d -v threadtime > "$OUT/backlight-on-logcat.txt" 2>&1 || true
snapshot_backlight backlight-high

echo
echo "For cleanup, return the keyboard backlight to your preferred state."
echo "Press ENTER when done."
read -r

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0     | sort -z     | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Section D ownership capture complete:"
echo "  $OUT"

echo
echo "Known-owner package summary:"
for pkg in "${PACKAGES[@]}"; do
  safe="${pkg//./_}"
  echo
  echo "===== $pkg ====="
  cat "$OUT/pkg-$safe-path.txt" 2>/dev/null || true
  grep -nEi     'codePath=|resourcePath=|versionName=|versionCode=|requested permissions:|granted=true|service|receiver|provider|notification|brightness|input|keyboard|shortcut|display'     "$OUT/pkg-$safe-dumpsys.txt"     | head -n 120 || true
done

echo
echo "Keyboard-backlight candidate setting diff:"
diff -u "$OUT/backlight-min-settings-all.txt" "$OUT/backlight-high-settings-all.txt"   | grep -Ei '^[-+].*(keyboard|key|led|backlight|light)'   | grep -Ev '^---|^\+\+\+' || true

echo
echo "Keyboard-backlight LED/sysfs diff:"
diff -u "$OUT/backlight-min-leds.txt" "$OUT/backlight-high-leds.txt" || true

echo
echo "Keyboard-backlight framework/light-service diff:"
diff -u "$OUT/backlight-min-dumpsys-lights.txt" "$OUT/backlight-high-dumpsys-lights.txt" || true

echo
echo "Keyboard-backlight log summary:"
grep -Ei   'keyboard|key.*led|led|backlight|light|agui|input'   "$OUT/backlight-on-logcat.txt"   | tail -n 220 || true

echo
echo "Overlay candidates:"
grep -Ei 'agui|input|keyboard|subdisplay|display' "$OUT/static-overlays.txt" || true

echo
echo "Runtime service candidates:"
grep -Ei 'agui|input|keyboard|subdisplay|shortcut|display|light' "$OUT/static-services.txt" || true
