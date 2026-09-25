#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST="${1:-$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-final-attribution 2>/dev/null | head -n1 || true)}"
[[ -n "$LATEST" && -d "$LATEST" ]] || { echo "error: no keyboard-final-attribution artifact found" >&2; exit 1; }

echo "artifact=$LATEST"
echo

echo "===== FF_KEY CONCISE ====="
FF="$LATEST/ff-key-owner.txt"
if [[ -f "$FF" ]]; then
  grep -E -i '^(=====|path=|objdump=)|focaltech_fp|ff_key|ff_register_device|register gesture keycode|input_(allocate|register|report)|KEY_(ENTER|UP|DOWN|LEFT|RIGHT|POWER|BACK)' "$FF" | head -n 900 || true
else
  echo "missing $FF"
fi

echo
echo "===== KEYLED POLICY CONCISE ====="
KP="$LATEST/keyled-policy-owner.txt"
if [[ -f "$KP" ]]; then
  grep -E -i -n -B5 -A12 'keyled_brightness|keypad_led|agui_keyboard_background_light|keyboard_light_slide|keyboard.?light' "$KP" | head -n 1400 || true
else
  echo "missing $KP"
fi

echo
echo "===== KEYLED PWM CONCISE ====="
KD="$LATEST/keyled-disassembly-full.txt"
if [[ -f "$KD" ]]; then
  awk '
    /^===== set_pwm_duty =====/ {p=1}
    /^===== keypad_led_probe =====/ {if(p){exit}}
    p {print}
  ' "$KD" | head -n 1000
  echo "--- probe references ---"
  grep -E -i 'pwm_request|pwm_apply|pwm_config|pwm_enable|min_brightness|pwm_ch|sysfs_create_group|mtk_disp_notifier' "$KD" | head -n 600 || true
else
  echo "missing $KD"
fi

echo
echo "===== KEY404 CORRECTED SCAN ONLY ====="
K4="$LATEST/key404-corrected.txt"
if [[ -f "$K4" ]]; then
  awk '
    /^===== corrected contextual 404 scan =====/ {p=1; next}
    /^===== AguiKeyboardShortcut method\/string ownership =====/ {p=0}
    p {print}
  ' "$K4" | sed '/^[[:space:]]*$/d' | head -n 1200
  echo
  echo "===== AGUI INPUT CLASS NAMES ====="
  grep -E -i 'AguiKeyboardShortcut|ShortcutInterceptKey|FingersGesture|KeyboardLightController|keyCode|dispatchKeyEvent|getKeyCode' "$K4" | head -n 800 || true
else
  echo "missing $K4"
fi
