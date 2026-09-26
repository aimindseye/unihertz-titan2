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
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-static-map"
mkdir -p "$OUT"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=read-only static keyboard/input stack mapping"
  echo "collector=tools/t2-keyboard-static-map.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo
  adb version 2>/dev/null || true
  echo
  for key in     ro.build.display.id     ro.build.version.incremental     ro.build.version.release     ro.build.version.security_patch     ro.boot.slot_suffix     ro.boot.flash.locked     ro.boot.verifiedbootstate     ro.boot.vbmeta.device_state
  do
    value="$("${ADB[@]}" shell getprop "$key" 2>/dev/null | tr -d '\r')"
    printf '%-36s %s\n' "$key" "$value"
  done
} > "$OUT/METADATA.txt"

"${ADB[@]}" shell cat /proc/bus/input/devices > "$OUT/proc-input-devices.txt" 2>&1 || true
"${ADB[@]}" shell getevent -lp > "$OUT/getevent-capabilities.txt" 2>&1 || true
"${ADB[@]}" shell dumpsys input > "$OUT/dumpsys-input.txt" 2>&1 || true
"${ADB[@]}" shell uname -a > "$OUT/uname.txt" 2>&1 || true
"${ADB[@]}" shell cat /proc/modules > "$OUT/proc-modules.txt" 2>&1 || true
"${ADB[@]}" shell dumpsys input_method > "$OUT/dumpsys-input-method.txt" 2>&1 || true
"${ADB[@]}" shell service list > "$OUT/service-list.txt" 2>&1 || true
"${ADB[@]}" shell cmd overlay list > "$OUT/overlay-list.txt" 2>&1 || true

"${ADB[@]}" shell '
  getprop | grep -Ei "keyboard|touchpad|mouse|shortcut|subdisplay|backlight|keyboard_light|keyboard_led" || true
' > "$OUT/relevant-properties.txt" 2>&1 || true

"${ADB[@]}" shell '
  for e in /sys/class/input/event*; do
    [ -e "$e" ] || continue
    name=$(cat "$e/device/name" 2>/dev/null || true)
    case "$name" in
      TitanKey|touchPad|ff_key|gpio_key-func|mtk-pmic-keys|gpio-keys)
        echo "===== $e ====="
        echo "name=$name"
        printf "device_path="; readlink -f "$e/device" 2>/dev/null || true
        printf "driver="; readlink -f "$e/device/driver" 2>/dev/null || true
        printf "subsystem="; readlink -f "$e/device/subsystem" 2>/dev/null || true
        printf "phys="; cat "$e/device/phys" 2>/dev/null || true
        printf "modalias="; cat "$e/device/modalias" 2>/dev/null || true
        printf "wakeup="; cat "$e/device/power/wakeup" 2>/dev/null || true
        echo "-- uevent --"
        cat "$e/device/uevent" 2>/dev/null || true
        echo
        ;;
    esac
  done
' > "$OUT/sysfs-input-map.txt" 2>&1 || true

"${ADB[@]}" shell '
  for p in     /system/usr/keylayout/TitanKey.kl     /system/usr/keychars/TitanKey.kcm     /system/usr/idc/TitanKey.idc     /system/usr/keylayout/Generic.kl     /vendor/usr/keylayout/TitanKey.kl     /vendor/usr/keychars/TitanKey.kcm     /vendor/usr/idc/TitanKey.idc     /odm/usr/keylayout/TitanKey.kl     /odm/usr/keychars/TitanKey.kcm     /odm/usr/idc/TitanKey.idc
  do
    if [ -r "$p" ]; then
      echo "===== $p ====="
      cat "$p"
      echo
    fi
  done
' > "$OUT/static-input-config.txt" 2>&1 || true

"${ADB[@]}" shell '
  for p in     com.agui.keyboard     com.agui.shortcutsettings     com.agui.settings     com.agui.spacebarkey     com.iqqijni.bbkeyboard     com.android.systemui
  do
    echo "===== $p ====="
    pm path "$p" 2>/dev/null || true
    dumpsys package "$p" 2>/dev/null |
      grep -Ei "codePath=|versionName=|versionCode=|granted=true|permission|service|receiver|provider|keyboard|shortcut|input|backlight|display" |
      head -n 180
    echo
  done
' > "$OUT/vendor-owner-packages.txt" 2>&1 || true

"${ADB[@]}" shell '
  if [ -d /proc/device-tree ]; then
    find /proc/device-tree -maxdepth 6 -type d 2>/dev/null |
      grep -Ei "key|keyboard|gpio|input|touch|hall|led|backlight|wakeup" |
      sort
  fi
' > "$OUT/device-tree-candidate-dirs.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "Keyboard static map complete:"
echo "  $OUT"
echo
echo "Run next:"
echo "  bash tools/t2-keyboard-static-summary.sh"
