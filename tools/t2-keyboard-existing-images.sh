#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EQ="${1:-/srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence}"

SRC="$EQ/TEE13-source"
LARGE="$EQ/TEE13-large-source"

for f in "$SRC/dtbo.img" "$SRC/vendor_boot.img" "$LARGE/vendor_dlkm.img" "$LARGE/system_dlkm.img" "$LARGE/odm_dlkm.img"; do
  [[ -f "$f" ]] || { echo "error: missing expected image: $f" >&2; exit 1; }
done

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-existing-images"
WORK="$OUT/work"
mkdir -p "$WORK"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "operation=low-IO offline inspection of existing V01.00.13 extracted images"
  echo "collector=tools/t2-keyboard-existing-images.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "source_basename=$(basename "$EQ")"
  echo "note=no raw OTA extraction; no broad filesystem scan; no large vendor/system_ext/product reads"
} > "$OUT/METADATA.txt"

PATTERN='TitanKey|aw9523|synaptics_dsx_pad|synaptics_1403|touchPad|ff_key|gpio_key-func|gpio[_-]?key[_-]?func|keypad_led|keyboard_led|keyboard_light|mtk_disp_notify|mtk_pmic_keys|mt6363keys|wakeup-source|matrix_key_enable|wakeup_key|pwm_ch|min_brightness'

echo "=== Image types ===" > "$OUT/image-types.txt"
for f in "$SRC/dtbo.img" "$SRC/vendor_boot.img" "$LARGE/vendor_dlkm.img" "$LARGE/system_dlkm.img" "$LARGE/odm_dlkm.img"; do
  printf "%s: " "$(basename "$f")" >> "$OUT/image-types.txt"
  file "$f" >> "$OUT/image-types.txt" 2>&1 || true
done

# Small-image targeted string pass only (~100 MiB total input).
for f in "$SRC/dtbo.img" "$SRC/vendor_boot.img" "$LARGE/vendor_dlkm.img" "$LARGE/system_dlkm.img" "$LARGE/odm_dlkm.img"; do
  echo "===== $(basename "$f") =====" >> "$OUT/targeted-strings.txt"
  strings "$f" 2>/dev/null | grep -Ei "$PATTERN" | sort -u | head -n 800 >> "$OUT/targeted-strings.txt" || true
  echo >> "$OUT/targeted-strings.txt"
done

# DTBO table only; no extraction unless mkdtimg is already installed.
if command -v mkdtimg >/dev/null 2>&1; then
  mkdtimg dump "$SRC/dtbo.img" > "$OUT/dtbo-table.txt" 2>&1 || true
else
  echo "mkdtimg not installed" > "$OUT/dtbo-table.txt"
fi

# Unpack vendor_boot only if a standard local tool already exists.
if command -v unpack_bootimg >/dev/null 2>&1; then
  mkdir -p "$WORK/vendor_boot"
  unpack_bootimg --boot_img "$SRC/vendor_boot.img" --out "$WORK/vendor_boot" > "$OUT/vendor-boot-unpack.txt" 2>&1 || true
  for f in "$WORK/vendor_boot"/*; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
      *dtb*|*ramdisk*)
        echo "===== $(basename "$f") =====" >> "$OUT/vendor-boot-component-hits.txt"
        strings "$f" 2>/dev/null | grep -Ei "$PATTERN" | sort -u | head -n 800 >> "$OUT/vendor-boot-component-hits.txt" || true
        ;;
    esac
  done
else
  echo "unpack_bootimg not installed" > "$OUT/vendor-boot-unpack.txt"
fi

# Read-only filesystem directory listings from the small DLKM images. If an
# image is Android sparse, make a temporary local raw copy first.
prepare_ext4() {
  local src="$1" tag="$2" dst="$WORK/$tag.raw.img"
  if file "$src" | grep -qi "Android sparse"; then
    if command -v simg2img >/dev/null 2>&1; then
      simg2img "$src" "$dst" >/dev/null 2>&1 || return 1
      printf "%s" "$dst"
    else
      return 1
    fi
  else
    printf "%s" "$src"
  fi
}

if command -v debugfs >/dev/null 2>&1; then
  for pair in "vendor_dlkm:$LARGE/vendor_dlkm.img" "system_dlkm:$LARGE/system_dlkm.img" "odm_dlkm:$LARGE/odm_dlkm.img"; do
    tag="${pair%%:*}"
    src="${pair#*:}"
    img="$(prepare_ext4 "$src" "$tag" || true)"
    echo "===== $tag =====" >> "$OUT/dlkm-listings.txt"
    if [[ -n "$img" ]]; then
      for p in / /lib /lib/modules /vendor/lib/modules /system/lib/modules; do
        echo "--- $p ---" >> "$OUT/dlkm-listings.txt"
        debugfs -R "ls -p $p" "$img" >> "$OUT/dlkm-listings.txt" 2>&1 || true
      done
    else
      echo "could not prepare ext4 image" >> "$OUT/dlkm-listings.txt"
    fi
    echo >> "$OUT/dlkm-listings.txt"
  done
else
  echo "debugfs not installed" > "$OUT/dlkm-listings.txt"
fi

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "Existing-image keyboard inspection complete:"
echo "  $OUT"
echo
cat "$OUT/image-types.txt"
echo
echo "Targeted strings:"
cat "$OUT/targeted-strings.txt" | head -n 1600
echo
echo "DLKM listings:"
cat "$OUT/dlkm-listings.txt" | head -n 1200
echo
echo "DTBO table:"
cat "$OUT/dtbo-table.txt" | head -n 600
echo
echo "vendor_boot component hits:"
cat "$OUT/vendor-boot-component-hits.txt" 2>/dev/null | head -n 800 || true
