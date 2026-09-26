#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 ADB serial}"
ADB=(adb -s "$TITAN_SERIAL")

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || { echo "error: selected Titan ADB target is not ready (state=${state:-none})" >&2; exit 1; }
model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
[[ "$model" == "Titan 2" ]] || { echo "error: selected device is not Titan 2 (model=$model)" >&2; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-residual-closeout"
mkdir -p "$OUT/apks" "$OUT/dex"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "operation=read-only residual keyboard ownership closeout"
  echo "collector=tools/t2-keyboard-residual-closeout.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "device_model=$model"
  echo "serial=<redacted>"
} > "$OUT/METADATA.txt"

adbsh() {
  "${ADB[@]}" shell "$@"
}

# Resolve selected input devices to event nodes and walk only their own sysfs ancestry.
{
  for wanted in ff_key gpio_key-func TitanKey touchPad; do
    echo "===== $wanted ====="
    found=0
    for ev in $(adbsh 'for e in /sys/class/input/event*; do [ "$(cat "$e/device/name" 2>/dev/null)" = "'"$wanted"'" ] && basename "$e"; done' | tr -d '\r'); do
      found=1
      echo "event=$ev"
      adbsh "p=/sys/class/input/$ev/device; echo realpath=\$(readlink -f \$p);         echo name=\$(cat \$p/name 2>/dev/null); echo phys=\$(cat \$p/phys 2>/dev/null);         echo uniq=\$(cat \$p/uniq 2>/dev/null); echo modalias=\$(cat \$p/modalias 2>/dev/null);         echo uevent:; cat \$p/uevent 2>/dev/null;         cur=\$(readlink -f \$p); i=0; while [ \$i -lt 8 ] && [ -n \"\$cur\" ] && [ \"\$cur\" != / ]; do           echo parent[\$i]=\$cur; [ -L \$cur/driver ] && echo driver[\$i]=\$(readlink -f \$cur/driver);           [ -L \$cur/subsystem ] && echo subsystem[\$i]=\$(readlink -f \$cur/subsystem);           [ -r \$cur/power/wakeup ] && echo wakeup[\$i]=\$(cat \$cur/power/wakeup);           cur=\$(dirname \$cur); i=\$((i+1)); done"
    done
    [[ "$found" -eq 1 ]] || echo "not-found"
    echo
  done
} > "$OUT/live-input-ownership.txt" 2>&1 || true

# The ff_key stanza plus targeted live kernel/module clues.
{
  echo "===== /proc/bus/input/devices stanza for ff_key ====="
  adbsh "awk 'BEGIN{RS=""} /N: Name="ff_key"/{print}' /proc/bus/input/devices" 2>/dev/null || true
  echo
  echo "===== loaded modules with key/ff/agold names ====="
  adbsh "cat /proc/modules 2>/dev/null | grep -Ei '(^|_)(ff|key|agold|aw9523|synaptics|keypad)' || true" 2>/dev/null || true
  echo
  echo "===== kallsyms targeted names ====="
  adbsh "cat /proc/kallsyms 2>/dev/null | grep -Ei 'ff_key|gpio_key|agold.*key|keypad_led' | head -n 500 || true" 2>/dev/null || true
  echo
  echo "===== /dev/uinput users if visible ====="
  adbsh "toybox lsof 2>/dev/null | grep -E '/dev/(uinput|input/event)' | head -n 300 || true" 2>/dev/null || true
} > "$OUT/ff-owner-live.txt" 2>&1

# Resolve the exact Synaptics firmware/DT node from the live I2C device.
{
  for dev in /sys/bus/i2c/devices/2-0020 /sys/bus/i2c/devices/6-0058; do
    echo "===== $dev ====="
    adbsh "echo realpath=\$(readlink -f $dev);       for n in of_node firmware_node; do         if [ -e $dev/\$n ]; then echo \$n=\$(readlink -f $dev/\$n);           p=\$(readlink -f $dev/\$n); ls -la \$p 2>/dev/null;           for q in compatible reg status name wakeup-source; do             [ -e \$p/\$q ] || continue; echo --\$q--;             od -An -tx1 \$p/\$q 2>/dev/null; strings \$p/\$q 2>/dev/null;           done; fi; done"
    echo
  done
} > "$OUT/live-dt-origin.txt" 2>&1 || true

# Locate the live keypad LED sysfs control and read it only.
{
  echo "===== keyled_brightness nodes ====="
  (adbsh "find /sys -xdev -name keyled_brightness -print 2>/dev/null" 2>/dev/null || true) | tr -d '\r' | while IFS= read -r node; do
    [[ -n "$node" ]] || continue
    echo "node=$node"
    adbsh "ls -l '$node'; echo value=\$(cat '$node' 2>/dev/null);       p=\$(dirname '$node'); echo parent=\$(readlink -f \$p);       [ -L \$p/driver ] && echo driver=\$(readlink -f \$p/driver);       [ -r \$p/uevent ] && { echo uevent:; cat \$p/uevent; };       echo siblings:; ls -la \$p"
    echo
  done
} > "$OUT/keyled-live.txt" 2>&1 || true

# Small Android input configuration dirs only.
adbsh "for d in /system/usr/keylayout /vendor/usr/keylayout /product/usr/keylayout /system_ext/usr/keylayout; do   [ -d \$d ] || continue; echo ===== \$d =====; grep -RniE '(^|[[:space:]])404([[:space:]]|$)|ff_key|gpio_key-func|AGUI' \$d 2>/dev/null || true; done"   > "$OUT/keylayout-404-ff.txt" 2>&1 || true

# Reuse the newest already-extracted 18 MiB vendor_dlkm tree.
MODROOT="$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-dtbo-erofs/vendor_dlkm/root 2>/dev/null | head -n1 || true)"
{
  echo "module_root=${MODROOT:-<none>}"
  if [[ -n "$MODROOT" && -d "$MODROOT" ]]; then
    echo "===== exact/near ff_key strings across vendor modules ====="
    while IFS= read -r ko; do
      hits="$(strings "$ko" 2>/dev/null | grep -Ei 'ff[_ -]?key|fast.?forward|key.*404|404.*key' | head -n 80 || true)"
      if [[ -n "$hits" ]]; then
        echo "--- ${ko#"$MODROOT"/} ---"
        printf '%s\n' "$hits"
      fi
    done < <(find "$MODROOT" -type f -name '*.ko' 2>/dev/null | sort)

    for stem in synaptics_1403_touch gpio_key keypad_led aw9523_key; do
      ko="$(find "$MODROOT" -type f -name "$stem.ko" -print -quit 2>/dev/null || true)"
      [[ -n "$ko" ]] || continue
      echo "===== $stem extended strings ====="
      strings "$ko" 2>/dev/null | grep -Ei '404|gesture|swipe|left|right|keycode|input_report_key|ff[_ -]?key|keyled|brightness|pwm|sysfs|wakeup' | sort -u | head -n 1000 || true
      if [[ "$stem" == keypad_led ]]; then
        echo "-- symbols --"
        readelf -sW "$ko" 2>/dev/null | grep -E 'keyled_brightness|keyled_pwm_config|keypad_led' || true
        if command -v llvm-objdump >/dev/null 2>&1; then
          echo "-- keyled_brightness_store disassembly --"
          llvm-objdump -dr --disassemble-symbols=keyled_brightness_store "$ko" 2>/dev/null || true
          echo "-- keyled_pwm_config disassembly --"
          llvm-objdump -dr --disassemble-symbols=keyled_pwm_config "$ko" 2>/dev/null || true
        elif command -v objdump >/dev/null 2>&1; then
          echo "-- keyled_brightness_store disassembly --"
          objdump -dr --disassemble=keyled_brightness_store "$ko" 2>/dev/null || true
          echo "-- keyled_pwm_config disassembly --"
          objdump -dr --disassemble=keyled_pwm_config "$ko" 2>/dev/null || true
        fi
      fi
      echo
    done
  fi
} > "$OUT/module-residuals.txt" 2>&1 || true

# Pull only the known keyboard-policy APKs and inspect their DEX/string constants.
packages=(
  com.agui.settings
  com.agui.keyboard
  com.agui.shortcutsettings
  com.agui.spacebarkey
  com.iqqijni.bbkeyboard
)

for pkg in "${packages[@]}"; do
  mapfile -t paths < <(adbsh "pm path '$pkg' 2>/dev/null" | sed 's/^package://' | tr -d '\r')
  [[ "${#paths[@]}" -gt 0 ]] || continue
  idx=0
  for remote in "${paths[@]}"; do
    name="${pkg//./_}-$idx.apk"
    "${ADB[@]}" pull "$remote" "$OUT/apks/$name" >/dev/null 2>&1 || true
    idx=$((idx+1))
  done
done

{
  for apk in "$OUT"/apks/*.apk; do
    [[ -f "$apk" ]] || continue
    echo "===== $(basename "$apk") ====="
    echo "-- archive/string hits --"
    strings "$apk" 2>/dev/null | grep -Ei 'ff_key|gpio_key-func|keyled_brightness|keyboard[_ -]?light|keycode.?404|KEYCODE.*404|touchpad|swipe|gesture' | sort -u | head -n 600 || true
    while IFS= read -r dexname; do
      [[ -n "$dexname" ]] || continue
      dex="$OUT/dex/$(basename "$apk").$(basename "$dexname")"
      unzip -p "$apk" "$dexname" > "$dex" 2>/dev/null || continue
      echo "-- $dexname string hits --"
      strings "$dex" 2>/dev/null | grep -Ei 'ff_key|gpio_key-func|keyled_brightness|keyboard[_ -]?light|touchpad|swipe|gesture|KEYCODE' | sort -u | head -n 800 || true
      if command -v dexdump >/dev/null 2>&1; then
        echo "-- $dexname dexdump 404 contexts --"
        dexdump -d "$dex" 2>/dev/null | grep -E -C 8 '#int 404|#0194|0x00000194' | head -n 1200 || true
      fi
    done < <(unzip -Z1 "$apk" 2>/dev/null | grep -E '^classes([0-9]+)?\.dex$' || true)
    echo
  done
} > "$OUT/apk-residuals.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
) || true

echo "collector_status=complete" > "$OUT/COLLECTOR_STATUS.txt"

echo
echo "Keyboard residual closeout complete:"
echo "  $OUT"
echo
echo "Live input ownership:"
cat "$OUT/live-input-ownership.txt" | head -n 900
echo
echo "ff_key owner clues:"
cat "$OUT/ff-owner-live.txt" | head -n 900
echo
echo "Synaptics/DT origin:"
cat "$OUT/live-dt-origin.txt" | head -n 900
echo
echo "keyled_brightness live node/value:"
cat "$OUT/keyled-live.txt" | head -n 900
echo
echo "Keylayout 404/ff hits:"
cat "$OUT/keylayout-404-ff.txt" | head -n 600
echo
echo "Module residuals:"
cat "$OUT/module-residuals.txt" | head -n 1800
echo
echo "APK residuals:"
cat "$OUT/apk-residuals.txt" | head -n 2200
