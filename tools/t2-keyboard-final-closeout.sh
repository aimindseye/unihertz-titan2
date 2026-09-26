#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 ADB serial}"
ADB=(adb -s "$TITAN_SERIAL")
EQ="${1:-/srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence}"
state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || { echo "error: Titan ADB target not ready (state=${state:-none})" >&2; exit 1; }
model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d "\r" || true)"
[[ "$model" == "Titan 2" ]] || { echo "error: selected device is not Titan 2 (model=$model)" >&2; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-final-closeout"
WORK="$OUT/work"
mkdir -p "$WORK/framework" "$WORK/dex" "$WORK/dlkm" "$WORK/boot"
adbsh() { "${ADB[@]}" shell "$@"; }

# Reliable input inventory from /proc.
adbsh cat /proc/bus/input/devices > "$OUT/proc-input-devices.txt" 2>&1 || true
python3 - "$OUT/proc-input-devices.txt" > "$OUT/input-targets.txt" <<'PY'
import re,sys
txt=open(sys.argv[1],errors="replace").read()
for block in re.split(r"\n\s*\n",txt):
    m=re.search(r'N: Name="([^"]+)"',block)
    if m and m.group(1) in {"ff_key","gpio_key-func","TitanKey","touchPad"}:
        print("===== "+m.group(1)+" =====")
        print(block.strip())
        hm=re.search(r"H: Handlers=(.*)",block)
        if hm:
            ev=[x for x in hm.group(1).split() if x.startswith("event")]
            print("EVENTS="+" ".join(ev))
        print()
PY

{
  cat "$OUT/input-targets.txt"
  echo "===== sysfs ancestry for discovered events ====="
  grep "^EVENTS=" "$OUT/input-targets.txt" | cut -d= -f2- | tr " " "\n" | sort -u | while IFS= read -r ev; do
    [[ -n "$ev" ]] || continue
    echo "--- $ev ---"
    adbsh "p=/sys/class/input/$ev/device; echo realpath=\$(readlink -f \$p); cur=\$(readlink -f \$p); i=0; while [ \$i -lt 8 ] && [ -n \"\$cur\" ] && [ \"\$cur\" != / ]; do echo parent[\$i]=\$cur; [ -L \$cur/driver ] && echo driver[\$i]=\$(readlink -f \$cur/driver); [ -L \$cur/subsystem ] && echo subsystem[\$i]=\$(readlink -f \$cur/subsystem); cur=\$(dirname \$cur); i=\$((i+1)); done" 2>/dev/null || true
  done
  echo "===== virtual input dir ====="
  adbsh "ls -la /sys/devices/virtual/input 2>/dev/null || true"
  echo "===== dumpsys input ====="
  adbsh "dumpsys input 2>/dev/null | grep -n -E 'ff_key|gpio_key-func|TitanKey|touchPad' | head -n 300 || true"
  echo "===== visible uinput/input users ====="
  adbsh "toybox lsof 2>/dev/null | grep -E '/dev/(uinput|input/event)' | head -n 300 || true"
} > "$OUT/input-owner-closeout.txt" 2>&1 || true

# Targeted keyboard-light paths; no broad sysfs search.
{
  echo "===== key-related class/platform nodes ====="
  adbsh "ls -ld /sys/class/misc/*key* /sys/devices/virtual/misc/*key* /sys/bus/platform/devices/*key* /sys/devices/platform/*key* 2>/dev/null || true"
  echo "===== direct keyled probes ====="
  adbsh 'for p in /sys/class/misc/keypad_led/keyled_brightness /sys/class/misc/keypad_led/device/keyled_brightness /sys/devices/virtual/misc/keypad_led/keyled_brightness /sys/devices/virtual/misc/keypad_led/device/keyled_brightness /sys/bus/platform/devices/keypad_led/keyled_brightness /sys/devices/platform/keypad_led/keyled_brightness; do if [ -e "$p" ]; then echo node=$p; ls -l "$p" 2>/dev/null; echo value=$(cat "$p" 2>/dev/null); d=$(dirname "$p"); echo parent=$(readlink -f "$d"); ls -la "$d" 2>/dev/null; echo; fi; done'
  echo "===== keypad_led nodes ====="
  adbsh 'for p in /sys/bus/platform/devices/keypad_led /sys/devices/platform/keypad_led /sys/class/misc/keypad_led /sys/devices/virtual/misc/keypad_led; do [ -e "$p" ] || continue; echo ---$p---; ls -la "$p" 2>/dev/null; [ -L "$p/driver" ] && echo driver=$(readlink -f "$p/driver"); [ -r "$p/uevent" ] && cat "$p/uevent"; done'
} > "$OUT/keyled-targeted.txt" 2>&1 || true

# Decode cap_tkpd and other keyboard DTBO properties from the existing 8 MiB image.
if [[ -f "$EQ/TEE13-source/dtbo.img" ]]; then
  python3 "$ROOT/tools/t2-dtbo-keyboard-props.py" "$EQ/TEE13-source/dtbo.img" > "$OUT/dtbo-final.txt" 2>&1 || true
fi

# Search all small DLKM sets for ff_key / key404 ownership.
for part in vendor_dlkm system_dlkm odm_dlkm; do
  img="$EQ/TEE13-large-source/$part.img"; [[ -f "$img" ]] || continue
  dest="$WORK/dlkm/$part"; mkdir -p "$dest"
  command -v fsck.erofs >/dev/null 2>&1 && fsck.erofs --extract="$dest" "$img" > "$OUT/$part-erofs.log" 2>&1 || true
done
{
  for d in "$WORK"/dlkm/*; do
    [[ -d "$d" ]] || continue
    while IFS= read -r ko; do
      hits="$(strings "$ko" 2>/dev/null | grep -Ei 'ff[_ -]?key|key.?code.?404|404.?key' | head -n 100 || true)"
      if [[ -n "$hits" ]]; then echo "--- ${ko#"$WORK/"} ---"; printf "%s\n" "$hits"; fi
    done < <(find "$d" -type f -name "*.ko" 2>/dev/null | sort)
  done
} > "$OUT/ff-dlkm-search.txt" 2>&1 || true

# Bounded built-in-kernel search from the existing 64 MiB boot image.
BOOT="$EQ/TEE13-source/boot.img"
if [[ -f "$BOOT" ]]; then
  strings "$BOOT" 2>/dev/null | grep -Ei 'ff_key|gpio_key-func|TitanKey|keypad_led' | sort -u | head -n 500 > "$OUT/ff-boot-search.txt" || true
  if command -v unpack_bootimg >/dev/null 2>&1; then
    unpack_bootimg --boot_img "$BOOT" --out "$WORK/boot" > "$OUT/boot-unpack.log" 2>&1 || true
    kernel="$(find "$WORK/boot" -maxdepth 1 -type f -name "kernel*" -print -quit 2>/dev/null || true)"
    [[ -n "$kernel" ]] && { echo "kernel=$(file "$kernel" 2>/dev/null)"; strings "$kernel" 2>/dev/null | grep -Ei 'ff_key|gpio_key-func|TitanKey|keypad_led' | sort -u | head -n 1000; } >> "$OUT/ff-boot-search.txt" || true
  fi
fi

# Pull a bounded set of framework containers likely to own key 404.
framework_paths=(/system/framework/services.jar /system/framework/framework.jar /system_ext/framework/framework-ext.jar /system_ext/framework/services-ext.jar /system_ext/framework/mediatek-framework.jar /vendor/framework/mediatek-framework.jar /vendor/framework/mtk-framework.jar)
for remote in "${framework_paths[@]}"; do
  if adbsh "[ -f '$remote' ]" >/dev/null 2>&1; then
    name="$(echo "$remote" | sed 's#^/##; s#/#__#g')"
    "${ADB[@]}" pull "$remote" "$WORK/framework/$name" >/dev/null 2>&1 || true
  fi
done

# Reuse keyboard-policy APKs from the newest residual pass.
PREV="$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-residual-closeout 2>/dev/null | head -n1 || true)"
[[ -n "$PREV" && -d "$PREV/apks" ]] && cp -a "$PREV/apks" "$WORK/" 2>/dev/null || true

# Locate an existing dexdump if available.
DEXDUMP="$(command -v dexdump 2>/dev/null || true)"
if [[ -z "$DEXDUMP" ]]; then
  for base in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk"; do
    [[ -n "$base" ]] || continue
    for x in "$base"/build-tools/*/dexdump; do [[ -x "$x" ]] && DEXDUMP="$x"; done
  done
fi

{
  for container in "$WORK"/framework/* "$WORK"/apks/*.apk; do
    [[ -f "$container" ]] || continue
    echo "===== $(basename "$container") ====="
    unzip -Z1 "$container" 2>/dev/null | grep -E '^classes([0-9]+)?\.dex$' | while IFS= read -r dexname; do
      [[ -n "$dexname" ]] || continue
      dex="$WORK/dex/$(basename "$container").$(basename "$dexname")"
      unzip -p "$container" "$dexname" > "$dex" 2>/dev/null || continue
      python3 "$ROOT/tools/dex-find-int404.py" "$dex" || true
      if [[ -n "$DEXDUMP" ]]; then
        "$DEXDUMP" -d "$dex" 2>/dev/null | grep -E -C 10 '404|0x0194|KeyboardLED|BrightnessPreference|keyled_brightness' | head -n 1800 || true
      fi
    done
    echo
  done
} > "$OUT/dex-404-closeout.txt" 2>&1 || true

# Try AArch64-aware disassembly of keypad LED functions if tooling is present.
MODROOT="$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-dtbo-erofs/vendor_dlkm/root 2>/dev/null | head -n1 || true)"
{
  ko=""; [[ -n "$MODROOT" ]] && ko="$(find "$MODROOT" -type f -name keypad_led.ko -print -quit 2>/dev/null || true)"
  tool="$(command -v aarch64-linux-gnu-objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null || true)"
  echo "objdump=${tool:-<none>}"
  if [[ -n "$ko" && -n "$tool" ]]; then
    "$tool" -dr --disassemble=keyled_brightness_store "$ko" 2>/dev/null || true
    "$tool" -dr --disassemble=keyled_pwm_config "$ko" 2>/dev/null || true
  fi
} > "$OUT/keypad-led-disassembly.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
) || true

echo "Keyboard final closeout complete:"
echo "  $OUT"
echo
echo "Input / ff_key ownership:"; cat "$OUT/input-owner-closeout.txt" | head -n 1400
echo
echo "keyled_brightness:"; cat "$OUT/keyled-targeted.txt" | head -n 1200
echo
echo "DTBO cap_tkpd / keyboard properties:"; grep -Ei -C 1 'cap_tkpd|touch_pad|synaptics|aw9523|keypad_led|mt6363keys|agold_gpio_key' "$OUT/dtbo-final.txt" 2>/dev/null | head -n 1600 || true
echo
echo "ff_key DLKM search:"; cat "$OUT/ff-dlkm-search.txt" | head -n 800
echo
echo "ff_key boot/kernel search:"; cat "$OUT/ff-boot-search.txt" 2>/dev/null | head -n 800 || true
echo
echo "DEX key-404 ownership:"; cat "$OUT/dex-404-closeout.txt" | head -n 2600
echo
echo "Keypad LED disassembly:"; cat "$OUT/keypad-led-disassembly.txt" | head -n 1600