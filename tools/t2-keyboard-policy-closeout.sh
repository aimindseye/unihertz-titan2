#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 ADB serial}"
ADB=(adb -s "$TITAN_SERIAL")
DEEP="${T2_DEEP_WORK_DIR:-$(ls -1dt /srv/data/sable-build/titan2/deep-work/*-keyboard-deep-analysis-work 2>/dev/null | head -n1 || true)}"
[[ -n "$DEEP" && -d "$DEEP" ]] || { echo "error: no deep-analysis work tree found" >&2; exit 1; }
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-policy-closeout"
mkdir -p "$OUT"
adbsh() { "${ADB[@]}" shell "$@"; }

# 1. SELinux domains allowed to touch sysfs_agold / keyled.
{
  echo "===== exact keyled label ====="
  grep -Rni -E 'keyled_brightness|keypad_led' "$DEEP/images/system_ext/etc/selinux" "$DEEP/images/vendor/etc/selinux" "$DEEP/images/system/system/etc/selinux" 2>/dev/null | head -n 1200 || true
  echo
  echo "===== allow rules mentioning sysfs_agold ====="
  grep -Rni -E '\(allow .*sysfs_agold|sysfs_agold.*\(file|sysfs_agold.*\(dir' "$DEEP/images/system_ext/etc/selinux" "$DEEP/images/vendor/etc/selinux" "$DEEP/images/system/system/etc/selinux" 2>/dev/null | head -n 2400 || true
} > "$OUT/keyled-selinux-allows.txt" 2>&1 || true

# 2. DEX strings for stock keyboard-light policy/controller.
{
  TERMS='agui_keyboard_background_light|keyboard_light_slide|keyboard[_ -]?light|keyled_brightness|keypad_led|KeyboardLightController|pressKeyToPowerOn|BrightnessPreference'
  find "$DEEP/dex" -type f -name "*.dex" -print0 2>/dev/null | while IFS= read -r -d "" d; do
    hits="$(strings "$d" 2>/dev/null | grep -Ei "$TERMS" | head -n 200 || true)"
    if [[ -n "$hits" ]]; then
      echo "===== ${d#"$DEEP/dex/"} ====="
      printf "%s\n" "$hits"
    fi
  done
} > "$OUT/keyled-dex-strings.txt" 2>&1 || true

# 3. Live settings plus kernel/logcat traces may expose the cached/current duty.
{
  echo "===== settings ====="
  for ns in system secure global; do
    echo "--- $ns ---"
    adbsh "settings list $ns 2>/dev/null | grep -Ei 'keyboard|keypad|keyled|light|touchpad' || true"
  done
  echo
  echo "===== kernel/logcat keypad traces ====="
  adbsh "logcat -b kernel -d 2>/dev/null | grep -Ei 'keypad[_ -]?led|keyled|set_pwm_duty|keyboard light' | tail -n 500 || true"
  adbsh "logcat -b all -d 2>/dev/null | grep -Ei 'keypad[_ -]?led|keyled_brightness|KeyboardLightController|keyboard light' | tail -n 800 || true"
  echo
  echo "===== direct node read (expected SELinux denial in shell) ====="
  adbsh "ls -lZ /sys/devices/platform/keypad_led/keyled_brightness 2>&1 || true; cat /sys/devices/platform/keypad_led/keyled_brightness 2>&1 || true"
} > "$OUT/keyled-live-correlation.txt" 2>&1 || true

# 4. Locate any host dexdump and dump only methods containing literal 404.
DEXDUMP="$(command -v dexdump 2>/dev/null || true)"
if [[ -z "$DEXDUMP" ]]; then
  DEXDUMP="$(find /srv/data/sable-build -type f -path "*/out/host/linux-x86/bin/dexdump" -perm -0100 -print -quit 2>/dev/null || true)"
fi
{
  echo "dexdump=${DEXDUMP:-<none>}"
  if [[ -n "$DEXDUMP" ]]; then
    for d in "$DEEP/dex"/*services.jar*.dex; do
      [[ -f "$d" ]] || continue
      tmp="$OUT/$(basename "$d").dexdump.txt"
      "$DEXDUMP" -d "$d" > "$tmp" 2>/dev/null || true
      echo "===== $(basename "$d") ====="
      grep -n -E -B45 -A100 '#int 404|0x00000194|#0194' "$tmp" | head -n 5000 || true
    done
  fi
} > "$OUT/key404-dexdump-context.txt" 2>&1 || true

# 5. Native input/gesture candidates: search exact touch/gesture strings and AArch64 immediate 0x194.
{
  echo "===== candidate ELF files ====="
  find "$DEEP/images/system/system" "$DEEP/images/system_ext" "$DEEP/images/vendor" "$DEEP/images/product" -type f \( -path "*/bin/*" -o -path "*/lib64/*" \) 2>/dev/null | grep -Ei 'input|gesture|agui|touch|keyboard' | head -n 1200
  echo
  echo "===== string candidates ====="
  find "$DEEP/images/system/system" "$DEEP/images/system_ext" "$DEEP/images/vendor" "$DEEP/images/product" -type f \( -path "*/bin/*" -o -path "*/lib64/*" \) 2>/dev/null | grep -Ei 'input|gesture|agui|touch|keyboard' | while IFS= read -r f; do
    hits="$(strings "$f" 2>/dev/null | grep -Ei 'touchPad|FingersGesture|KEYCODE.*404|keyCode.*404|gesture.*key|keyboard.*gesture' | head -n 120 || true)"
    if [[ -n "$hits" ]]; then echo "--- ${f#"$DEEP/images/"} ---"; printf "%s\n" "$hits"; fi
  done
  echo
  echo "===== AArch64 immediate 0x194 in likely native input binaries ====="
  TOOL="$(command -v aarch64-linux-gnu-objdump 2>/dev/null || true)"
  if [[ -n "$TOOL" ]]; then
    find "$DEEP/images/system/system" "$DEEP/images/system_ext" "$DEEP/images/vendor" "$DEEP/images/product" -type f \( -path "*/bin/*" -o -path "*/lib64/*" \) 2>/dev/null | grep -Ei 'input|gesture|agui|touch|keyboard' | while IFS= read -r f; do
      file "$f" 2>/dev/null | grep -q "ELF 64-bit LSB.*ARM aarch64" || continue
      h="$("$TOOL" -d "$f" 2>/dev/null | grep -E -C 12 '#0x194([^0-9a-fA-F]|$)|#404([^0-9]|$)' | head -n 220 || true)"
      if [[ -n "$h" ]]; then echo "--- ${f#"$DEEP/images/"} ---"; printf "%s\n" "$h"; fi
    done
  fi
} > "$OUT/key404-native.txt" 2>&1 || true

(
  cd "$OUT"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
) || true

echo "Keyboard policy/native closeout complete:"
echo "  $OUT"
echo
echo "SELinux keyled allows:"; cat "$OUT/keyled-selinux-allows.txt" | head -n 2600
echo
echo "Keyled DEX policy strings:"; cat "$OUT/keyled-dex-strings.txt" | head -n 2200
echo
echo "Live keyled correlation:"; cat "$OUT/keyled-live-correlation.txt" | head -n 1800
echo
echo "Key404 exact DEX contexts:"; cat "$OUT/key404-dexdump-context.txt" | head -n 4200
echo
echo "Key404 native candidates:"; cat "$OUT/key404-native.txt" | head -n 3600