#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EQ="${1:-/srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence}"
DTBO="$EQ/TEE13-source/dtbo.img"
VDLKM="$EQ/TEE13-large-source/vendor_dlkm.img"
[[ -f "$DTBO" && -f "$VDLKM" ]] || { echo "missing expected V01.00.13 images" >&2; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-dtbo-erofs"
WORK="$OUT/vendor_dlkm"
mkdir -p "$OUT" "$WORK"

python3 "$ROOT/tools/t2-dtbo-keyboard-props.py" "$DTBO" > "$OUT/dtbo-keyboard-properties.txt"

if ! command -v fsck.erofs >/dev/null 2>&1; then
  echo "fsck.erofs not installed; skipping vendor_dlkm extraction" > "$OUT/erofs-status.txt"
else
  mkdir -p "$WORK/root"
  if fsck.erofs --extract="$WORK/root" "$VDLKM" > "$OUT/erofs-extract.log" 2>&1; then
    echo "vendor_dlkm extraction ok" > "$OUT/erofs-status.txt"
  else
    echo "vendor_dlkm extraction failed" > "$OUT/erofs-status.txt"
  fi
fi

PATTERN="ff_key|gpio_key-func|gpio[_-]?key[_-]?func|TitanKey|touchPad|synaptics_dsx_pad|aw9523|keypad_led|keyboard_led|brightness|pwm|wakeup|disp_notify"
if [[ -d "$WORK/root" ]]; then
  for stem in aw9523_key synaptics_1403_touch hynitron_touchpad gpio_key keypad_led mtk_disp_notify mtk_pmic_keys; do
    ko="$(find "$WORK/root" -type f -name "$stem.ko" -print -quit 2>/dev/null || true)"
    [[ -n "$ko" ]] || continue
    {
      echo "===== $stem ====="
      echo "file=${ko#"$WORK/root"/}"
      if command -v readelf >/dev/null 2>&1; then
        echo "-- modinfo --"
        readelf -p .modinfo "$ko" 2>/dev/null || true
      fi
      echo "-- selected strings --"
      strings "$ko" 2>/dev/null | grep -Ei "$PATTERN" | sort -u | head -n 1000 || true
      echo
    } >> "$OUT/module-attribution.txt"
  done
  {
    echo "=== exact input-name hits across extracted modules ==="
    while IFS= read -r ko; do
      strings "$ko" 2>/dev/null | grep -E "^(ff_key|gpio_key-func|TitanKey|touchPad(/input0)?)$" | while IFS= read -r hit; do
        printf "%s\t%s\n" "${ko#"$WORK/root"/}" "$hit"
      done || true
    done < <(find "$WORK/root" -type f -name "*.ko" 2>/dev/null | sort)
  } > "$OUT/input-name-attribution.txt"
fi

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "Keyboard DTBO/EROFS inspection complete:"
echo "  $OUT"
echo
echo "DTBO keyboard properties:"
cat "$OUT/dtbo-keyboard-properties.txt" | head -n 1800
echo
echo "EROFS status:"
cat "$OUT/erofs-status.txt"
echo
echo "Module attribution:"
cat "$OUT/module-attribution.txt" 2>/dev/null | head -n 1800 || true
echo
echo "Input-name attribution:"
cat "$OUT/input-name-attribution.txt" 2>/dev/null | head -n 800 || true
