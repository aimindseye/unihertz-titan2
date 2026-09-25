#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")

die(){ echo "error: $*" >&2; exit 1; }
state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"
model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d "\r")"
[[ "$model" == "Titan 2" ]] || die "selected device reports \"${model:-unknown}\", expected Titan 2"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-driver-followup"
mkdir -p "$OUT"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=read-only keyboard driver/module/DT follow-up"
  echo "collector=tools/t2-keyboard-driver-followup.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

# Map Linux driver names to the actual kernel module objects when sysfs exposes
# a module symlink.
"${ADB[@]}" shell '
  for d in \
    /sys/bus/i2c/drivers/TitanKey \
    /sys/bus/i2c/drivers/synaptics_dsx_pad \
    /sys/bus/platform/drivers/gpio-keys \
    /sys/bus/platform/drivers/mtk-pmic-keys
  do
    echo "===== $d ====="
    if [ -d "$d" ]; then
      printf "module="; readlink -f "$d/module" 2>/dev/null || true
      echo "bound_devices:"
      ls -1 "$d" 2>/dev/null | grep -E "^[0-9]+-[0-9a-fA-F]+$|^[^[:space:]]+$" | head -n 120
    else
      echo "missing"
    fi
    echo
  done
' > "$OUT/driver-to-module.txt" 2>&1 || true

# Dump property-level evidence from the exact DT candidates. Binary cells are
# shown as both short printable strings and hex; no mutation is performed.
"${ADB[@]}" shell '
  nodes="
/sys/firmware/devicetree/base/soc/i2c@11e01000/aw9523b_led@58
/sys/firmware/devicetree/base/keypad_led
/sys/firmware/devicetree/base/soc/i2c@11c22000/hynitron@15
/sys/firmware/devicetree/base/soc/i2c@11c22000/hynitron1@5a
/sys/firmware/devicetree/base/soc/spmi@1cc04000/pmic@4/mt6363keys
/sys/firmware/devicetree/base/agold_gpio_key
"
  for n in $nodes; do
    echo "===== $n ====="
    [ -d "$n" ] || { echo missing; echo; continue; }
    find "$n" -maxdepth 2 -type f 2>/dev/null | sort | while read -r f; do
      echo "--- $f ---"
      printf "strings: "
      strings "$f" 2>/dev/null | tr "\n" " " | head -c 400
      echo
      printf "hex: "
      od -An -tx1 -N96 "$f" 2>/dev/null | tr "\n" " " | sed "s/[[:space:]]\+/ /g"
      echo
    done
    echo
  done
' > "$OUT/device-tree-properties.txt" 2>&1 || true

# Search visible kernel symbols for likely virtual-input producers. Symbol
# addresses may be masked; names alone are what we care about.
"${ADB[@]}" shell '
  if [ -r /proc/kallsyms ]; then
    grep -Ei "ff_key|gpio[_-]?key[_-]?func|func[_-]?key|TitanKey|synaptics_dsx_pad|aw9523|keypad_led|keyboard_led|touchpad" /proc/kallsyms |
      head -n 1200
  fi
' > "$OUT/kallsyms-keyboard-candidates.txt" 2>&1 || true

# Inspect candidate module files in place for literal input-device/driver names.
# This is useful for virtual input devices whose sysfs root has no bus driver.
"${ADB[@]}" shell '
  for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules /odm/lib/modules; do
    [ -d "$base" ] || continue
    for stem in aw9523_key hynitron_touchpad keypad_led gpio_key mtk_pmic_keys mtk_disp_notify synaptics_1403_touch; do
      for f in "$base"/$stem.ko "$base"/$stem.ko.zst "$base"/$stem.ko.gz; do
        [ -r "$f" ] || continue
        echo "===== $f ====="
        case "$f" in
          *.ko)
            grep -aEo "ff_key|gpio_key-func|gpio[_-]?key[_-]?func|TitanKey|synaptics_dsx_pad|aw9523[^[:space:]\\x00]*|keypad_led|keyboard_led|touchPad|hynitron[^[:space:]\\x00]*" "$f" 2>/dev/null |
              sort -u | head -n 300 || true
            ;;
          *) echo "compressed_module";;
        esac
      done
    done
  done
' > "$OUT/module-literal-hits.txt" 2>&1 || true

# Capture all direct attributes around the two key I2C devices, which may expose
# vendor-specific debug/control files omitted by generic sysfs scanning.
"${ADB[@]}" shell '
  for d in /sys/bus/i2c/devices/6-0058 /sys/bus/i2c/devices/2-0020; do
    echo "===== $d ====="
    [ -d "$d" ] || continue
    find "$d" -maxdepth 2 -type f 2>/dev/null | sort | while read -r f; do
      case "$f" in
        */uevent|*/modalias|*/name|*/phys|*/wakeup|*/control|*/runtime_status|*/power_state|*/enable|*/state|*/mode|*/version|*/fw*|*/debug*)
          printf "%s=" "$f"
          cat "$f" 2>/dev/null | tr "\n" " " | head -c 500
          echo
          ;;
      esac
    done
  done
' > "$OUT/i2c-device-attributes.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "Keyboard driver follow-up complete:"
echo "  $OUT"
echo
echo "Driver -> module mapping:"
cat "$OUT/driver-to-module.txt" 2>/dev/null || true
echo
echo "Device-tree properties:"
cat "$OUT/device-tree-properties.txt" 2>/dev/null | head -n 1200 || true
echo
echo "Virtual-input / module symbol clues:"
cat "$OUT/kallsyms-keyboard-candidates.txt" "$OUT/module-literal-hits.txt" 2>/dev/null | head -n 1200 || true
echo
echo "I2C device attributes:"
cat "$OUT/i2c-device-attributes.txt" 2>/dev/null | head -n 600 || true
