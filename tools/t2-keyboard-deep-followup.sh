#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EQ="${1:-/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence}"
DEEP="${T2_DEEP_WORK_DIR:-$(ls -1dt /srv/data/sable-build/titan2/deep-work/*-keyboard-deep-analysis-work 2>/dev/null | head -n1 || true)}"
[[ -n "$DEEP" && -d "$DEEP" ]] || { echo "error: no deep-analysis work tree found" >&2; exit 1; }
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-deep-followup"
mkdir -p "$OUT" "$DEEP/boot-followup"

echo "deep_work=$DEEP" > "$OUT/METADATA.txt"
echo "eq=$EQ" >> "$OUT/METADATA.txt"

# Keyboard LED ownership/policy: exact init + sepolicy context and all policy-key consumers.
{
  echo "===== agui_device_init.rc ====="
  f="$DEEP/images/vendor/etc/init/hw/agui_device_init.rc"
  [[ -f "$f" ]] && grep -n -B12 -A24 -E "keyled_brightness|keypad_led|keyboard" "$f" || true
  echo
  echo "===== SELinux keyled/keypad references ====="
  grep -Rni -B4 -A8 -E "keyled_brightness|keypad_led|sysfs.*key.*led" "$DEEP/images/system_ext/etc/selinux" "$DEEP/images/vendor/etc/selinux" "$DEEP/images/system/etc/selinux" 2>/dev/null | head -n 2400 || true
  echo
  echo "===== policy key file candidates ====="
  terms="agui_keyboard_background_light|persist\.sys\.keyboard_light_slide_on|KEY_SLIDE_KEYBOARD_LIGHT|key_slide_keyboard_light_switch|keyboard[_ -]?light|keyled_brightness|keypad_led"
  grep -aRIl -E "$terms" "$DEEP/images" 2>/dev/null | head -n 1200 || true
  echo
  echo "===== policy key string contexts ====="
  grep -aRIl -E "$terms" "$DEEP/images" 2>/dev/null | head -n 300 | while IFS= read -r x; do
    echo "--- ${x#"$DEEP/images/"} ---"
    strings "$x" 2>/dev/null | grep -Ei -C 8 "$terms" | head -n 500 || true
  done
} > "$OUT/keyled-policy.txt" 2>&1 || true

# Disassemble the actual PWM mapping and probe path.
MODROOT="$(ls -1dt "$ROOT"/artifacts/private/t2-tier1/*-keyboard-dtbo-erofs/vendor_dlkm/root 2>/dev/null | head -n1 || true)"
{
  ko=""; [[ -n "$MODROOT" ]] && ko="$(find "$MODROOT" -type f -name keypad_led.ko -print -quit 2>/dev/null || true)"
  tool="$(command -v aarch64-linux-gnu-objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null || true)"
  echo "module=${ko:-<none>}"; echo "objdump=${tool:-<none>}"
  if [[ -n "$ko" ]]; then
    echo "===== relevant symbols ====="
    readelf -sW "$ko" 2>/dev/null | grep -Ei "set_pwm_duty|keypad_led_probe|keyled|brightness|notifier|pwm" || true
  fi
  if [[ -n "$ko" && -n "$tool" ]]; then
    for sym in set_pwm_duty keypad_led_probe keyled_brightness_show keyled_brightness_store; do
      echo "===== $sym ====="
      "$tool" -dr --disassemble="$sym" "$ko" 2>/dev/null || true
    done
  fi
} > "$OUT/keypad-led-pwm.txt" 2>&1 || true

# Vendor boot + init boot ramdisks: remaining likely home for ff_key producer.
extract_ramdisk() {
  local src="$1" dest="$2" raw="$dest/ramdisk.raw"
  mkdir -p "$dest/root"
  local desc; desc="$(file -b "$src" 2>/dev/null || true)"
  echo "$src :: $desc"
  if echo "$desc" | grep -qi gzip; then gzip -dc "$src" > "$raw" 2>/dev/null || return 0
  elif echo "$desc" | grep -qi LZ4; then lz4 -d -c "$src" > "$raw" 2>/dev/null || return 0
  elif echo "$desc" | grep -qi "cpio archive"; then cp "$src" "$raw"
  else strings "$src" 2>/dev/null | grep -Ei "ff_key|uinput|UI_DEV|gpio_key-func|keyled_brightness" | head -n 300 || true; return 0; fi
  (cd "$dest/root" && cpio -idm --no-absolute-filenames < "$raw" >/dev/null 2>&1) || true
}

{
  for imgname in vendor_boot init_boot; do
    img="$EQ/TEE13-source/$imgname.img"; [[ -f "$img" ]] || continue
    dest="$DEEP/boot-followup/$imgname"; rm -rf "$dest"; mkdir -p "$dest"
    echo "===== $imgname ====="
    if command -v unpack_bootimg >/dev/null 2>&1; then
      unpack_bootimg --boot_img "$img" --out "$dest" >/dev/null 2>&1 || true
    fi
    find "$dest" -maxdepth 1 -type f -printf "%f\n" | sort
    for r in "$dest"/*ramdisk*; do [[ -f "$r" ]] || continue; extract_ramdisk "$r" "$r.extract"; done
    echo "-- ff/uinput hits --"
    grep -aRni -E "ff_key|/dev/uinput|UI_DEV_CREATE|UI_DEV_SETUP|uinput_user_dev|gpio_key-func" "$dest" 2>/dev/null | head -n 3000 || true
    echo "-- module/binary candidates --"
    find "$dest" -type f \( -name "*.ko" -o -perm -0100 \) -print 2>/dev/null | head -n 1200
  done
} > "$OUT/boot-ramdisk-ff.txt" 2>&1 || true

# Whole extracted userspace search for uinput/native virtual-input creators.
{
  echo "===== /dev/uinput and uinput API candidates ====="
  grep -aRIl -E "/dev/uinput|UI_DEV_CREATE|UI_DEV_SETUP|uinput_user_dev|UINPUT_VERSION" "$DEEP/images" 2>/dev/null | head -n 1600 || true
  echo
  grep -aRIl -E "/dev/uinput|UI_DEV_CREATE|UI_DEV_SETUP|uinput_user_dev|UINPUT_VERSION" "$DEEP/images" 2>/dev/null | head -n 300 | while IFS= read -r x; do
    echo "--- ${x#"$DEEP/images/"} ---"
    strings "$x" 2>/dev/null | grep -Ei -C 8 "uinput|ff[_ -]?key|virtual.*key|input.*create" | head -n 500 || true
  done
} > "$OUT/uinput-candidates.txt" 2>&1 || true

# Strict key-404 filtering over the DEX files already extracted by the deep pass.
{
  find "$DEEP/dex" -type f -name "*.dex" -print0 2>/dev/null | sort -z | xargs -0 -r python3 "$ROOT/tools/dex-find-key404-keyevent.py"
} > "$OUT/key404-strict.txt" 2>&1 || true

(
  cd "$OUT"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
) || true

echo "Keyboard deep follow-up complete:"
echo "  $OUT"
echo
echo "Keyled policy/init/SELinux:"; cat "$OUT/keyled-policy.txt" | head -n 3200
echo
echo "Keypad LED PWM disassembly:"; cat "$OUT/keypad-led-pwm.txt" | head -n 2600
echo
echo "Vendor/init boot ff_key search:"; cat "$OUT/boot-ramdisk-ff.txt" | head -n 3200
echo
echo "uinput/native candidates:"; cat "$OUT/uinput-candidates.txt" | head -n 2600
echo
echo "Strict key404 hits:"; cat "$OUT/key404-strict.txt" | head -n 2600