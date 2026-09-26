#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")

die(){ echo "error: $*" >&2; exit 1; }

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"
model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d "\r")"
[[ "$model" == "Titan 2" ]] || die "selected device reports \"${model:-unknown}\", expected Titan 2"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-binary-dt"
mkdir -p "$OUT/modules"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=read-only keyboard module + device-tree inspection"
  echo "collector=tools/t2-keyboard-binary-dt-inspect.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

# Dump exact driver->module relationships using symlink existence rather than
# readlink -f on a possibly absent "module" path.
"${ADB[@]}" shell '
  for d in \
    /sys/bus/i2c/drivers/TitanKey \
    /sys/bus/i2c/drivers/synaptics_dsx_pad \
    /sys/bus/platform/drivers/gpio-keys \
    /sys/bus/platform/drivers/mtk-pmic-keys
  do
    echo "===== $d ====="
    if [ -L "$d/module" ]; then
      echo "module=$(readlink -f "$d/module")"
    else
      echo "module=<none/built-in-or-not-exposed>"
    fi
    echo
  done
' > "$OUT/driver-module-verified.txt" 2>&1 || true

# Enumerate DT entries with ls/find and dump every non-directory property under
# the selected nodes. This avoids relying on -type f semantics in sysfs.
"${ADB[@]}" shell '
  nodes="
/sys/firmware/devicetree/base/soc/i2c@11e01000/aw9523b_led@58
/sys/firmware/devicetree/base/keypad_led
/sys/firmware/devicetree/base/soc/i2c@11c22000/hynitron@15
/sys/firmware/devicetree/base/soc/i2c@11c22000/hynitron1@5a
/sys/firmware/devicetree/base/soc/spmi@1cc04000/pmic@4/mt6363keys
/sys/firmware/devicetree/base/agold_gpio_key
"
  for n in $nodes; do
    echo "===== $n ====="
    [ -e "$n" ] || { echo "missing"; echo; continue; }
    echo "-- ls --"
    ls -la "$n" 2>/dev/null || true
    echo "-- properties --"
    find "$n" -maxdepth 2 -print 2>/dev/null | sort | while read -r p; do
      [ -d "$p" ] && continue
      echo "--- $p ---"
      printf "strings: "
      strings "$p" 2>/dev/null | tr "\n" " " | head -c 500
      echo
      printf "hex: "
      od -An -tx1 -N128 "$p" 2>/dev/null | tr "\n" " " | sed "s/[[:space:]]\+/ /g"
      echo
    done
    echo
  done
' > "$OUT/device-tree-properties.txt" 2>&1 || true

# Resolve module filenames robustly via modules.dep or a find fallback.
mods="aw9523_key synaptics_1403_touch keypad_led gpio_key mtk_pmic_keys mtk_disp_notify"
for mod in $mods; do
  remote="$("${ADB[@]}" shell "
    for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules /odm/lib/modules; do
      [ -d \$base ] || continue
      if [ -r \$base/modules.dep ]; then
        sed -n \"s#^\([^:]*${mod}\\.ko[^:]*\):.*#\$base/\\1#p\" \$base/modules.dep | head -n1
      fi
      find \$base -type f \( -name \"${mod}.ko\" -o -name \"${mod}.ko.*\" \) 2>/dev/null | head -n1
    done | head -n1
  " 2>/dev/null | tr -d "\r")"
  [[ -n "$remote" ]] || continue

  base="$(basename "$remote")"
  localf="$OUT/modules/$base"
  "${ADB[@]}" pull "$remote" "$localf" >/dev/null 2>&1 || continue

  inspect="$localf"
  case "$inspect" in
    *.zst)
      if command -v zstd >/dev/null 2>&1; then
        zstd -q -d -f "$inspect" -o "${inspect%.zst}" >/dev/null 2>&1 || true
        [[ -s "${inspect%.zst}" ]] && inspect="${inspect%.zst}"
      fi
      ;;
    *.gz)
      if command -v gzip >/dev/null 2>&1; then
        gzip -cd "$inspect" > "${inspect%.gz}" 2>/dev/null || true
        [[ -s "${inspect%.gz}" ]] && inspect="${inspect%.gz}"
      fi
      ;;
    *.xz)
      if command -v xz >/dev/null 2>&1; then
        xz -cd "$inspect" > "${inspect%.xz}" 2>/dev/null || true
        [[ -s "${inspect%.xz}" ]] && inspect="${inspect%.xz}"
      fi
      ;;
  esac

  {
    echo "===== $mod ====="
    echo "remote=$remote"
    echo "local=$inspect"
    file "$inspect" 2>/dev/null || true
    if command -v readelf >/dev/null 2>&1; then
      echo "-- .modinfo --"
      readelf -p .modinfo "$inspect" 2>/dev/null || true
    fi
    echo "-- exact-interest strings --"
    strings "$inspect" 2>/dev/null | grep -Ei \
      "ff_key|gpio_key-func|gpio[_-]?key[_-]?func|TitanKey|synaptics_dsx_pad|touchPad|aw9523|keypad_led|keyboard_led|key.*light|brightness|pwm|disp_notify|wakeup|suspend|resume|input_register|sysfs|proc_create" |
      sort -u | head -n 900 || true
    echo
  } >> "$OUT/module-inspection.txt"
done

# Search the selected module binaries together for the virtual input names.
if compgen -G "$OUT/modules/*" >/dev/null; then
  for f in "$OUT"/modules/*; do
    strings "$f" 2>/dev/null | grep -Ei "ff_key|gpio_key-func|touchPad|TitanKey|keypad_led" |
      sed "s#^#$(basename "$f"): #" || true
  done | sort -u > "$OUT/virtual-name-hits.txt"
fi

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "Keyboard binary/DT inspection complete:"
echo "  $OUT"
echo
echo "Verified driver -> module:"
cat "$OUT/driver-module-verified.txt" 2>/dev/null || true
echo
echo "Device-tree properties:"
cat "$OUT/device-tree-properties.txt" 2>/dev/null | head -n 1800 || true
echo
echo "Module inspection:"
cat "$OUT/module-inspection.txt" 2>/dev/null | head -n 1800 || true
echo
echo "Virtual input name hits:"
cat "$OUT/virtual-name-hits.txt" 2>/dev/null | head -n 600 || true
