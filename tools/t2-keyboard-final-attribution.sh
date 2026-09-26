#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 ADB serial}"
ADB=(adb -s "$TITAN_SERIAL")
DEEP="${T2_DEEP_WORK_DIR:-$(ls -1dt /srv/data/sable-build/titan2/deep-work/*-keyboard-deep-analysis-work 2>/dev/null | head -n1 || true)}"
[[ -n "$DEEP" && -d "$DEEP" ]] || { echo "error: no deep-analysis work tree found" >&2; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-final-attribution"
mkdir -p "$OUT"

adbsh() { "${ADB[@]}" shell "$@"; }

# 1. ff_key: prove or reject focaltech_fp.ko ownership.
FP="$(find "$DEEP/boot-followup/vendor_boot" -type f -name focaltech_fp.ko -print -quit 2>/dev/null || true)"
{
  echo "===== live focaltech_fp ====="
  adbsh "cat /proc/modules 2>/dev/null | grep -E '^focaltech_fp ' || true"
  adbsh "dumpsys input 2>/dev/null | grep -n -B5 -A25 'ff_key' | head -n 120 || true"
  echo
  echo "===== module ====="
  echo "path=${FP:-<none>}"
  if [[ -n "$FP" ]]; then
    echo "-- modinfo --"
    readelf -p .modinfo "$FP" 2>/dev/null || true
    echo "-- symbols --"
    readelf -sW "$FP" 2>/dev/null | grep -Ei 'ff_register_device|ff.*key|gesture|input_(allocate|register|report)|keycode|ff_irq|ff_probe' || true
    echo "-- strings --"
    strings -a -t x "$FP" 2>/dev/null | grep -Ei 'ff_key|register gesture keycode|ff_register_device|input|gesture|keycode' | head -n 500 || true
    TOOL="$(command -v aarch64-linux-gnu-objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null || true)"
    echo "objdump=${TOOL:-<none>}"
    if [[ -n "$TOOL" ]]; then
      for sym in ff_register_device ff_probe ff_irq ff_irq_handler; do
        if readelf -sW "$FP" 2>/dev/null | grep -q " $sym$"; then
          echo "-- disassemble $sym --"
          "$TOOL" -dr --disassemble="$sym" "$FP" 2>/dev/null || true
        fi
      done
    fi
  fi
} > "$OUT/ff-key-owner.txt" 2>&1 || true

# 2. keyled: exact init/SELinux policy + stock policy consumers.
{
  echo "===== vendor init exact references ====="
  grep -Rni -B8 -A18 -E 'keyled_brightness|keypad_led|keyboard.*light'     "$DEEP/images/vendor/etc/init" 2>/dev/null | head -n 2000 || true
  echo
  echo "===== SELinux exact references ====="
  grep -Rni -B5 -A12 -E 'keyled_brightness|keypad_led|sysfs.*key.*led'     "$DEEP/images/vendor/etc/selinux"     "$DEEP/images/system_ext/etc/selinux"     "$DEEP/images/system/system/etc/selinux" 2>/dev/null | head -n 2600 || true
  echo
  echo "===== policy-setting consumers ====="
  TERMS='agui_keyboard_background_light|persist\.sys\.keyboard_light_slide_on|keyboard_light_slide|keyboard[_ -]?light|keyled_brightness|keypad_led'
  grep -aRIl -E "$TERMS" "$DEEP/images" 2>/dev/null | head -n 500 | while IFS= read -r f; do
    echo "--- ${f#"$DEEP/images/"} ---"
    strings "$f" 2>/dev/null | grep -Ei -C 10 "$TERMS" | head -n 700 || true
  done
} > "$OUT/keyled-policy-owner.txt" 2>&1 || true

# 3. keypad LED full low-level mapping.
MODROOT="$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-dtbo-erofs/vendor_dlkm/root 2>/dev/null | head -n1 || true)"
KLED=""
[[ -n "$MODROOT" ]] && KLED="$(find "$MODROOT" -type f -name keypad_led.ko -print -quit 2>/dev/null || true)"
{
  echo "module=${KLED:-<none>}"
  TOOL="$(command -v aarch64-linux-gnu-objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null || true)"
  echo "objdump=${TOOL:-<none>}"
  if [[ -n "$KLED" ]]; then
    readelf -sW "$KLED" 2>/dev/null | grep -Ei 'set_pwm_duty|keypad_led_probe|keyled_brightness|pwm|brightness' || true
    if [[ -n "$TOOL" ]]; then
      for sym in set_pwm_duty keypad_led_probe keyled_brightness_show keyled_brightness_store; do
        echo "===== $sym ====="
        "$TOOL" -dr --disassemble="$sym" "$KLED" 2>/dev/null || true
      done
    fi
  fi
} > "$OUT/keyled-disassembly-full.txt" 2>&1 || true

# 4. Key 404: rerun corrected scanner against existing DEX corpus, then focus AGUI services.
{
  echo "===== corrected contextual 404 scan ====="
  find "$DEEP/dex" -type f -name '*.dex' -print0 2>/dev/null | sort -z |     xargs -0 -r python3 "$ROOT/tools/dex-find-key404-keyevent.py" || true
  echo
  echo "===== AguiKeyboardShortcut method/string ownership ====="
  for d in "$DEEP/dex"/*services.jar*.dex; do
    [[ -f "$d" ]] || continue
    echo "--- $(basename "$d") ---"
    strings "$d" 2>/dev/null | grep -Ei -C 8 'AguiKeyboardShortcut|ShortcutInterceptKey|KEYCODE|404|touchPad|gesture' | head -n 1600 || true
  done
} > "$OUT/key404-corrected.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
) || true

echo "Keyboard final attribution complete:"
echo "  $OUT"
echo
echo "ff_key owner:"; cat "$OUT/ff-key-owner.txt" | head -n 2400
echo
echo "keyled policy/owner:"; cat "$OUT/keyled-policy-owner.txt" | head -n 2800
echo
echo "keyled low-level mapping:"; cat "$OUT/keyled-disassembly-full.txt" | head -n 2600
echo
echo "key404 corrected:"; cat "$OUT/key404-corrected.txt" | head -n 2600
