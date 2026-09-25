#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ART="${1:-$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-policy-closeout 2>/dev/null | head -n1 || true)}"
DEEP="${T2_DEEP_WORK_DIR:-$(ls -1dt /srv/data/sable-build/titan2/deep-work/*-keyboard-deep-analysis-work 2>/dev/null | head -n1 || true)}"
[[ -n "$ART" && -d "$ART" ]] || { echo "error: no keyboard-policy-closeout artifact found" >&2; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTDIR="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-policy-summary"
REPORT="$OUTDIR/REPORT.txt"
mkdir -p "$OUTDIR"

generate_report() {
  echo "source_artifact=$ART"
  echo "deep_work=${DEEP:-<none>}"
  echo

  echo "===== KEYLED SELINUX ALLOWS ====="
  F="$ART/keyled-selinux-allows.txt"
  if [[ -f "$F" ]]; then
    grep -E -i -n 'keyled_brightness|keypad_led|sysfs_agold|allow .*sysfs_agold' "$F" | head -n 900 || true
  else
    echo "missing $F"
  fi

  echo
  echo "===== KEYLED DEX POLICY ====="
  F="$ART/keyled-dex-strings.txt"
  if [[ -f "$F" ]]; then
    grep -E -i '=====|agui_keyboard_background_light|keyboard_light_slide|KeyboardLightController|pressKeyToPowerOn|BrightnessPreference|keyled_brightness|keypad_led' "$F" | head -n 1200 || true
  else
    echo "missing $F"
  fi

  echo
  echo "===== KEYLED LIVE CORRELATION ====="
  F="$ART/keyled-live-correlation.txt"
  if [[ -f "$F" ]]; then
    grep -E -i -n -B3 -A8 'keyboard|keypad|keyled|set_pwm_duty|brightness|avc:.*denied' "$F" | head -n 1200 || true
  else
    echo "missing $F"
  fi

  echo
  echo "===== KEY404 DEXDUMP TARGETED ====="
  F="$ART/key404-dexdump-context.txt"
  if [[ -f "$F" ]]; then
    grep -E -i -n -B25 -A60 'AguiKeyboardShortcut|FingersGesture|APhoneWindowManagerExt|PhoneWindowManager|#int 404|0x00000194|#0194' "$F" | head -n 2200 || true
  else
    echo "missing $F"
  fi

  echo
  echo "===== KEY404 PRODUCER SCAN ====="
  if [[ -n "$DEEP" && -d "$DEEP/dex" ]]; then
    find "$DEEP/dex" -type f -name '*.dex' -print0 2>/dev/null | sort -z |       xargs -0 -r python3 "$ROOT/tools/dex-find-key404-producer.py" |       grep -E -i 'FingersGesture|AguiKeyboardShortcut|APhoneWindowManagerExt|producer_refs=.*(KeyEvent|injectInputEvent|sendKey)' | head -n 1200 || true
  else
    echo "deep DEX corpus unavailable"
  fi

  echo
  echo "===== NATIVE 0x194 STRICT IMMEDIATES ====="
  F="$ART/key404-native.txt"
  if [[ -f "$F" ]]; then
    grep -E -B6 -A10 '\b(cmp|cmn)\s+w[0-9]+, #0x194\b|\bmov\s+w[0-9]+, #0x194\b|\b(subs?|adds?)\s+w[0-9]+, w[0-9]+, #0x194\b' "$F" | head -n 900 || true
  fi
}

generate_report > "$REPORT" 2>&1

(
  cd "$OUTDIR"
  sha256sum REPORT.txt > SHA256SUMS
) || true

LINES="$(wc -l < "$REPORT" 2>/dev/null || echo 0)"
BYTES="$(wc -c < "$REPORT" 2>/dev/null || echo 0)"

echo "Keyboard policy summary written:"
echo "  $REPORT"
echo "  lines=$LINES bytes=$BYTES"
echo
echo "Attach REPORT.txt instead of pasting terminal output."

if [[ "${T2_SUMMARY_STDOUT:-0}" == "1" ]]; then
  echo
  cat "$REPORT"
fi
