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
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-deep-analysis"
DEEP_WORK_ROOT="${T2_DEEP_WORK_ROOT:-$OUT}"
WORK="$DEEP_WORK_ROOT/$STAMP-keyboard-deep-analysis-work"
mkdir -p "$OUT" "$WORK/images" "$WORK/boot" "$WORK/dex"
ln -s "$WORK" "$OUT/work-external" 2>/dev/null || true
adbsh() { "${ADB[@]}" shell "$@"; }

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "operation=deep offline/live keyboard residual analysis"
  echo "collector=tools/t2-keyboard-deep-analysis.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "device_model=$model"
  echo "serial=<redacted>"
  echo "deep_work_root=$DEEP_WORK_ROOT"
  echo "deep_work_dir=$WORK"
  df -h "$ROOT" "$EQ" "$DEEP_WORK_ROOT" 2>/dev/null || true
} > "$OUT/METADATA.txt"

# Tool inventory.
{
  for x in fsck.erofs lz4 ripgrep rg unzip strings file readelf aarch64-linux-gnu-objdump llvm-objdump dexdump jadx; do
    printf "%-28s %s\n" "$x" "$(command -v "$x" 2>/dev/null || echo missing)"
  done
} > "$OUT/tools.txt"

# Live keypad LED: exact path, permissions, policy values, and privileged read attempts when already available.
KEYLED=/sys/devices/platform/keypad_led/keyled_brightness
{
  echo "===== identity ====="
  adbsh "id; getenforce 2>/dev/null || true"
  echo "===== node/context ====="
  adbsh "ls -ldZ /sys/devices/platform/keypad_led /sys/class/misc/keypad_led 2>/dev/null || true; ls -lZ $KEYLED 2>&1 || true; stat $KEYLED 2>&1 || true; cat $KEYLED 2>&1 || true"
  echo "===== su ====="
  adbsh "command -v su 2>/dev/null || true"
  adbsh "if command -v su >/dev/null 2>&1; then su -c 'echo value=$(cat $KEYLED 2>&1); ls -lZ $KEYLED 2>&1' 2>&1; fi" || true
  echo "===== run-as agui.settings ====="
  adbsh "run-as com.agui.settings sh -c 'id; cat $KEYLED' 2>&1 || true"
  echo "===== settings values ====="
  adbsh "for ns in system secure global; do echo ---\$ns---; settings list \$ns 2>/dev/null | grep -Ei 'keyboard|keypad|keyled|light|touchpad|brightness' || true; done"
  echo "===== dumpsys settings clues ====="
  adbsh "dumpsys settings 2>/dev/null | grep -Ei 'keyboard|keypad|keyled|touchpad' | head -n 500 || true"
} > "$OUT/keyled-live-deep.txt" 2>&1 || true

# Live input ownership with multiple independent sources.
{
  echo "===== /proc/bus/input/devices ====="
  adbsh "cat /proc/bus/input/devices 2>&1 || true"
  echo "===== getevent -pl target blocks ====="
  adbsh "getevent -pl 2>/dev/null | grep -B4 -A35 -E 'ff_key|gpio_key-func|TitanKey|touchPad' || true"
  echo "===== virtual input nodes ====="
  adbsh "for p in /sys/devices/virtual/input/input*; do echo ---\$p---; cat \$p/name 2>/dev/null || true; cat \$p/uevent 2>/dev/null || true; ls -la \$p 2>/dev/null | head -n 80; done"
  echo "===== dumpsys input target blocks ====="
  adbsh "dumpsys input 2>/dev/null | grep -n -B8 -A30 -E 'ff_key|gpio_key-func|TitanKey|touchPad' | head -n 1800 || true"
  echo "===== visible uinput users ====="
  adbsh "toybox lsof 2>/dev/null | grep -E '/dev/(uinput|input/event)' | head -n 500 || true"
} > "$OUT/input-live-deep.txt" 2>&1 || true

# Extract the four large EROFS partitions now that the host is free.
for part in vendor system_ext product system; do
  img="$EQ/TEE13-large-source/$part.img"
  [[ -f "$img" ]] || continue
  dest="$WORK/images/$part"
  mkdir -p "$dest"
  if command -v fsck.erofs >/dev/null 2>&1; then
    echo "extracting $part..."
    fsck.erofs --extract="$dest" "$img" > "$OUT/$part-erofs.log" 2>&1 || true
  else
    echo "fsck.erofs missing; cannot extract $part" >> "$OUT/$part-erofs.log"
  fi
done

# Exact string/file attribution across extracted firmware.
{
  echo "===== exact ff_key files ====="
  grep -aRIl --exclude-dir=lost+found -E 'ff_key' "$WORK/images" 2>/dev/null | head -n 1000 || true
  echo "===== keyled_brightness files ====="
  grep -aRIl --exclude-dir=lost+found -E 'keyled_brightness|/sys/devices/platform/keypad_led|keypad_led' "$WORK/images" 2>/dev/null | head -n 1500 || true
  echo "===== key404/keyevent/touch gesture string candidates ====="
  grep -aRIl --exclude-dir=lost+found -E 'KEYCODE[^[:cntrl:]]*404|keyCode[^[:cntrl:]]*404|keycode[^[:cntrl:]]*404|AGUI.*404|touchPad|keyboard_gesture' "$WORK/images" 2>/dev/null | head -n 2000 || true
} > "$OUT/extracted-file-candidates.txt" 2>&1 || true

# Show useful string context for every exact ff_key / keyled candidate.
{
  for needle in ff_key keyled_brightness keypad_led; do
    echo "===== $needle ====="
    grep -aRIl -E "$needle" "$WORK/images" 2>/dev/null | head -n 250 | while IFS= read -r f; do
      echo "--- ${f#"$WORK/images/"} ---"
      strings "$f" 2>/dev/null | grep -Ei -C 5 "$needle|gpio_key-func|touchPad|keyboard|brightness|pwm" | head -n 300 || true
    done
  done
} > "$OUT/extracted-string-context.txt" 2>&1 || true

# Boot kernel: unpack, decompress LZ4, then search built-in strings/source paths.
BOOT="$EQ/TEE13-source/boot.img"
if [[ -f "$BOOT" && -x "$(command -v unpack_bootimg 2>/dev/null || true)" ]]; then
  unpack_bootimg --boot_img "$BOOT" --out "$WORK/boot" > "$OUT/boot-unpack.log" 2>&1 || true
fi
KERNEL="$(find "$WORK/boot" -maxdepth 1 -type f -name "kernel*" -print -quit 2>/dev/null || true)"
{
  echo "kernel=${KERNEL:-<none>}"
  if [[ -n "$KERNEL" ]]; then
    file "$KERNEL" 2>/dev/null || true
    RAW="$WORK/boot/kernel.raw"
    if file "$KERNEL" 2>/dev/null | grep -qi LZ4 && command -v lz4 >/dev/null 2>&1; then
      lz4 -d -f "$KERNEL" "$RAW" >/dev/null 2>&1 || true
    else
      cp "$KERNEL" "$RAW" 2>/dev/null || true
    fi
    echo "raw=$(file "$RAW" 2>/dev/null)"
    echo "-- exact strings --"
    strings -a -t x "$RAW" 2>/dev/null | grep -Ei 'ff_key|gpio_key-func|TitanKey|keypad_led|agold_gpio_key|cap_tkpd|synaptics_dsx_pad' | head -n 3000 || true
    echo "-- likely source paths --"
    strings "$RAW" 2>/dev/null | grep -Ei 'drivers/.+(ff|key|agold|touchpad|synaptics|keypad)' | sort -u | head -n 2000 || true
  fi
} > "$OUT/kernel-deep.txt" 2>&1 || true

# DEX code scan across all extracted APK/JAR containers. This can be CPU-heavy by design.
{
  count=0
  while IFS= read -r container; do
    count=$((count+1))
    unzip -Z1 "$container" 2>/dev/null | grep -E '^classes([0-9]+)?\.dex$' | while IFS= read -r dexname; do
      [[ -n "$dexname" ]] || continue
      tag="$(printf "%s" "${container#"$WORK/images/"}" | tr "/ " "__")"
      dex="$WORK/dex/$tag.$(basename "$dexname")"
      unzip -p "$container" "$dexname" > "$dex" 2>/dev/null || continue
      python3 "$ROOT/tools/dex-find-key404-context.py" "$dex" || true
    done
  done < <(find "$WORK/images" -type f \( -name "*.apk" -o -name "*.jar" \) 2>/dev/null | sort)
  echo "containers_scanned=$count"
} > "$OUT/dex-key404-context.txt" 2>&1 || true

# Optional JADX pass on only exact ff/keyled string candidate APK/JARs.
if command -v jadx >/dev/null 2>&1; then
  mkdir -p "$WORK/jadx"
  grep -aRIl -E 'ff_key|keyled_brightness|keypad_led' "$WORK/images" 2>/dev/null | grep -E '\.(apk|jar)$' | head -n 100 | while IFS= read -r c; do
    tag="$(printf "%s" "${c#"$WORK/images/"}" | tr "/ " "__")"
    jadx --no-res --threads-count 2 -d "$WORK/jadx/$tag" "$c" >/dev/null 2>&1 || true
  done
  grep -RniE 'ff_key|keyled_brightness|keypad_led|keyCode *== *404|case +404|KEYCODE.*404' "$WORK/jadx" 2>/dev/null | head -n 5000 > "$OUT/jadx-candidates.txt" || true
else
  echo "jadx not installed" > "$OUT/jadx-candidates.txt"
fi

# AArch64 disassembly of keypad LED driver if possible.
MODROOT="$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-dtbo-erofs/vendor_dlkm/root 2>/dev/null | head -n1 || true)"
{
  ko=""; [[ -n "$MODROOT" ]] && ko="$(find "$MODROOT" -type f -name keypad_led.ko -print -quit 2>/dev/null || true)"
  tool="$(command -v aarch64-linux-gnu-objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null || true)"
  echo "module=${ko:-<none>}"; echo "objdump=${tool:-<none>}"
  if [[ -n "$ko" && -n "$tool" ]]; then
    "$tool" -dr --disassemble=keyled_brightness_show "$ko" 2>/dev/null || true
    "$tool" -dr --disassemble=keyled_brightness_store "$ko" 2>/dev/null || true
    "$tool" -dr --disassemble=keyled_pwm_config "$ko" 2>/dev/null || true
  fi
} > "$OUT/keypad-led-aarch64.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
) || true

echo
echo "Deep keyboard analysis complete:"
echo "  report: $OUT"
echo "  work:   $WORK"
echo
echo "Tool inventory:"; cat "$OUT/tools.txt"
echo
echo "Live keyled:"; cat "$OUT/keyled-live-deep.txt" | head -n 1200
echo
echo "Live input/ff_key:"; cat "$OUT/input-live-deep.txt" | head -n 1800
echo
echo "Extracted firmware candidates:"; cat "$OUT/extracted-file-candidates.txt" | head -n 2400
echo
echo "Kernel ff/key strings:"; cat "$OUT/kernel-deep.txt" | head -n 2400
echo
echo "DEX key404 contextual hits:"; cat "$OUT/dex-key404-context.txt" | head -n 3000
echo
echo "JADX candidates:"; cat "$OUT/jadx-candidates.txt" | head -n 1800
echo
echo "Keypad LED disassembly:"; cat "$OUT/keypad-led-aarch64.txt" | head -n 2000