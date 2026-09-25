#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-}"
[[ -n "$SRC" ]] || {
  echo "usage: $0 /path/to/titan2-ota-or-extracted-firmware" >&2
  exit 2
}
[[ -e "$SRC" ]] || { echo "error: source not found: $SRC" >&2; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-ota-keyboard-inspect"
WORK="$OUT/work"
mkdir -p "$WORK"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "operation=read-only/offline Titan 2 OTA keyboard stack inspection"
  echo "collector=tools/t2-ota-keyboard-inspect.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "source_type=$([[ -d "$SRC" ]] && echo directory || echo file)"
  echo "source_basename=$(basename "$SRC")"
  echo "NOTE=source path intentionally omitted from committed/shareable output"
} > "$OUT/METADATA.txt"

PATTERN='TitanKey|aw9523|synaptics_dsx_pad|synaptics_1403|touchPad|hynitron_touchpad|ff_key|gpio_key-func|gpio_key|mtk-pmic-keys|mtk_pmic_keys|keypad_led|keyboard_led|keyboard_light|keyboard backlight|mtk_disp_notify|agold_gpio_key|mt6363keys'

echo "source=$(basename "$SRC")" > "$OUT/source-summary.txt"

# 1. Inventory container/OTA structure without modifying the source.
if [[ -d "$SRC" ]]; then
  find "$SRC" -maxdepth 4 -type f -printf "%P\t%s\n" 2>/dev/null | sort > "$OUT/file-inventory.txt"
else
  file "$SRC" > "$OUT/source-file-type.txt" 2>&1 || true
  case "$SRC" in
    *.zip)
      unzip -l "$SRC" > "$OUT/zip-list.txt" 2>&1 || true
      unzip -Z1 "$SRC" > "$OUT/zip-names.txt" 2>/dev/null || true
      ;;
  esac
fi

# 2. If this is an OTA ZIP, extract only metadata and payload/partition images
# into the private working tree. Nothing is written back to the OTA.
ANALYZE_ROOT="$SRC"
if [[ -f "$SRC" && "$SRC" == *.zip ]]; then
  mkdir -p "$WORK/zip"
  if grep -qx "payload.bin" "$OUT/zip-names.txt" 2>/dev/null; then
    unzip -p "$SRC" payload_properties.txt > "$WORK/zip/payload_properties.txt" 2>/dev/null || true
    unzip -p "$SRC" META-INF/com/android/metadata > "$WORK/zip/ota-metadata.txt" 2>/dev/null || true
    unzip -p "$SRC" payload.bin > "$WORK/zip/payload.bin"
    if command -v payload-dumper-go >/dev/null 2>&1; then
      mkdir -p "$WORK/payload"
      payload-dumper-go -o "$WORK/payload" "$WORK/zip/payload.bin" > "$OUT/payload-dumper.log" 2>&1 || true
      ANALYZE_ROOT="$WORK/payload"
    elif command -v payload_dumper >/dev/null 2>&1; then
      mkdir -p "$WORK/payload"
      payload_dumper -o "$WORK/payload" "$WORK/zip/payload.bin" > "$OUT/payload-dumper.log" 2>&1 || true
      ANALYZE_ROOT="$WORK/payload"
    else
      echo "payload.bin present but no payload-dumper-go/payload_dumper found" > "$OUT/NEEDS_PAYLOAD_DUMPER.txt"
      ANALYZE_ROOT="$WORK/zip"
    fi
  else
    while IFS= read -r n; do
      case "$n" in
        *boot*.img|*dtbo*.img|*vendor*.img|*system*.img|*product*.img|*odm*.img|*super*.img)
          mkdir -p "$WORK/zip/$(dirname "$n")"
          unzip -p "$SRC" "$n" > "$WORK/zip/$n" 2>/dev/null || true
          ;;
      esac
    done < "$OUT/zip-names.txt"
    ANALYZE_ROOT="$WORK/zip"
  fi
fi

# 3. Inventory interesting partition images/files.
find "$ANALYZE_ROOT" -type f 2>/dev/null |
  grep -Ei '/(boot|vendor_boot|dtbo|vendor_dlkm|system_dlkm|vendor|odm|system_ext|product|super)(_[ab])?\.img$|\.ko(\.|$)|\.kl$|\.kcm$|\.idc$|\.apk$|\.jar$' |
  sort > "$OUT/candidate-files.txt" || true

# 4. Search ordinary extracted files and binaries directly.
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.img) continue ;;
  esac
  rel="${f#"$ANALYZE_ROOT"/}"
  if grep -aEil "$PATTERN" "$f" >/dev/null 2>&1; then
    echo "===== $rel =====" >> "$OUT/direct-text-hits.txt"
    strings "$f" 2>/dev/null | grep -Ei "$PATTERN" | sort -u | head -n 400 >> "$OUT/direct-text-hits.txt" || true
  fi
done < "$OUT/candidate-files.txt"

# 5. Inspect kernel modules already available as extracted .ko files.
while IFS= read -r ko; do
  [[ -f "$ko" ]] || continue
  case "$(basename "$ko")" in
    *aw9523*|*synaptics*1403*|*hynitron*touchpad*|*keypad_led*|*gpio_key*|*mtk_pmic_keys*|*mtk_disp_notify*)
      echo "===== ${ko#"$ANALYZE_ROOT"/} =====" >> "$OUT/module-hits.txt"
      if command -v readelf >/dev/null 2>&1; then
        readelf -p .modinfo "$ko" 2>/dev/null >> "$OUT/module-hits.txt" || true
      fi
      strings "$ko" 2>/dev/null | grep -Ei "$PATTERN|compatible|wakeup|suspend|resume|pwm|brightness|sysfs|proc|input_register|i2c_driver" |
        sort -u | head -n 700 >> "$OUT/module-hits.txt" || true
      ;;
  esac
done < <(find "$ANALYZE_ROOT" -type f -name "*.ko" 2>/dev/null | sort)

# 6. Image-level reconnaissance. Use strings first because it is non-invasive
# and works even when filesystem unpackers are unavailable.
while IFS= read -r img; do
  [[ -f "$img" ]] || continue
  case "$img" in *.img) ;; *) continue ;; esac
  rel="${img#"$ANALYZE_ROOT"/}"
  echo "===== $rel =====" >> "$OUT/image-types.txt"
  file "$img" >> "$OUT/image-types.txt" 2>&1 || true
  strings "$img" 2>/dev/null | grep -Ei "$PATTERN|aw9523b,key|aw9523b,led|wakeup-source|pwm_ch|min_brightness" |
    sort -u | head -n 600 > "$WORK/image.$(echo "$rel" | tr "/ " "__").hits" || true
  if [[ -s "$WORK/image.$(echo "$rel" | tr "/ " "__").hits" ]]; then
    echo "===== $rel =====" >> "$OUT/image-string-hits.txt"
    cat "$WORK/image.$(echo "$rel" | tr "/ " "__").hits" >> "$OUT/image-string-hits.txt"
  fi
done < <(find "$ANALYZE_ROOT" -type f -name "*.img" 2>/dev/null | sort)

# 7. Try DT-specific tools on DTBO/boot-style images only when present.
for img in $(find "$ANALYZE_ROOT" -type f \( -name "dtbo*.img" -o -name "vendor_boot*.img" -o -name "boot*.img" \) 2>/dev/null | sort); do
  rel="${img#"$ANALYZE_ROOT"/}"
  if command -v mkdtimg >/dev/null 2>&1 && [[ "$(basename "$img")" == dtbo*.img ]]; then
    echo "===== $rel =====" >> "$OUT/dt-tool-output.txt"
    mkdtimg dump "$img" >> "$OUT/dt-tool-output.txt" 2>&1 || true
  fi
done

# 8. Print only a reviewed summary; raw extracted payload/images stay private.
(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "OTA keyboard inspection complete:"
echo "  $OUT"
echo
echo "OTA / firmware structure:"
cat "$OUT/source-file-type.txt" "$OUT/zip-list.txt" "$OUT/file-inventory.txt" 2>/dev/null |
  grep -Ei "payload|boot|dtbo|vendor_dlkm|system_dlkm|vendor\.img|system_ext|product|super|\.ko|\.kl|\.kcm|\.idc" | head -n 500 || true
echo
echo "Candidate files:"
sed "s#^$ANALYZE_ROOT/##" "$OUT/candidate-files.txt" 2>/dev/null | head -n 500 || true
echo
echo "Kernel/module hits:"
cat "$OUT/module-hits.txt" 2>/dev/null | head -n 1200 || true
echo
echo "Partition/image string hits:"
cat "$OUT/image-string-hits.txt" 2>/dev/null | head -n 1200 || true
echo
echo "Direct extracted-file hits:"
cat "$OUT/direct-text-hits.txt" 2>/dev/null | head -n 1000 || true
echo
if [[ -f "$OUT/NEEDS_PAYLOAD_DUMPER.txt" ]]; then
  cat "$OUT/NEEDS_PAYLOAD_DUMPER.txt"
  echo "Install/use a local payload dumper or point this script at an already-extracted firmware directory."
fi
