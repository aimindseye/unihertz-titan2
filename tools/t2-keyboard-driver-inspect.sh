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
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-keyboard-driver-inspect"
mkdir -p "$OUT/modules"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=read-only targeted keyboard driver inspection"
  echo "collector=tools/t2-keyboard-driver-inspect.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

# Exact bus-device driver bindings.
"${ADB[@]}" shell '
  for d in \
    /sys/bus/i2c/devices/6-0058 \
    /sys/bus/i2c/devices/2-0020 \
    /sys/bus/platform/devices/gpio-keys \
    /sys/devices/platform/soc/1cc04000.spmi/spmi-0/0-04/mtk-pmic-keys
  do
    echo "===== $d ====="
    if [ -e "$d" ]; then
      printf "realpath="; readlink -f "$d" 2>/dev/null || true
      printf "driver="; readlink -f "$d/driver" 2>/dev/null || true
      printf "subsystem="; readlink -f "$d/subsystem" 2>/dev/null || true
      printf "modalias="; cat "$d/modalias" 2>/dev/null || true
      printf "wakeup="; cat "$d/power/wakeup" 2>/dev/null || true
      printf "control="; cat "$d/power/control" 2>/dev/null || true
      printf "runtime_status="; cat "$d/power/runtime_status" 2>/dev/null || true
      echo "-- uevent --"
      cat "$d/uevent" 2>/dev/null || true
    else
      echo "missing"
    fi
    echo
  done
' > "$OUT/exact-driver-bindings.txt" 2>&1 || true

# Walk input-device parents to find the nearest bound driver instead of assuming
# event numbers or a driver symlink on the input child itself.
"${ADB[@]}" shell '
  for e in /sys/class/input/event*; do
    [ -e "$e" ] || continue
    name=$(cat "$e/device/name" 2>/dev/null || true)
    case "$name" in
      TitanKey|touchPad|ff_key|gpio_key-func|mtk-pmic-keys|gpio-keys)
        echo "===== $name ====="
        p=$(readlink -f "$e/device" 2>/dev/null || true)
        echo "input_device=$p"
        i=0
        while [ -n "$p" ] && [ "$p" != "/" ] && [ $i -lt 8 ]; do
          printf "ancestor_%d=%s" "$i" "$p"
          if [ -L "$p/driver" ]; then
            printf " driver=%s" "$(readlink -f "$p/driver" 2>/dev/null || true)"
          fi
          if [ -r "$p/modalias" ]; then
            printf " modalias=%s" "$(cat "$p/modalias" 2>/dev/null | tr "\n" " ")"
          fi
          if [ -r "$p/power/wakeup" ]; then
            printf " wakeup=%s" "$(cat "$p/power/wakeup" 2>/dev/null | tr "\n" " ")"
          fi
          echo
          np=$(dirname "$p")
          [ "$np" = "$p" ] && break
          p="$np"
          i=$((i+1))
        done
        echo
        ;;
    esac
  done
' > "$OUT/input-parent-chain.txt" 2>&1 || true

# Module runtime metadata and parameters.
for mod in aw9523_key hynitron_touchpad keypad_led gpio_key mtk_pmic_keys mtk_disp_notify; do
  "${ADB[@]}" shell "
    echo ===== $mod =====
    if [ -d /sys/module/$mod ]; then
      echo present=yes
      echo -- parameters --
      for f in /sys/module/$mod/parameters/*; do
        [ -r \"\$f\" ] || continue
        printf \"%s=\" \"\${f##*/}\"
        cat \"\$f\" 2>/dev/null || true
      done
      echo -- holders --
      ls -1 /sys/module/$mod/holders 2>/dev/null || true
    else
      echo present=no
    fi
  " >> "$OUT/module-runtime.txt" 2>&1 || true
done

# Locate likely keyboard-light controls without changing them.
"${ADB[@]}" shell '
  find /sys -maxdepth 8 \( -type f -o -type l \) 2>/dev/null |
    grep -Ei "/(keypad|kbd|keyboard|aw9523|touchpad|key_led|keylight|backlight)" |
    sort | head -n 1600
' > "$OUT/sysfs-keyboard-candidate-paths.txt" 2>&1 || true

"${ADB[@]}" shell '
  for f in $(find /sys -maxdepth 8 -type f 2>/dev/null |
      grep -Ei "/(keypad|kbd|keyboard|aw9523|key_led|keylight)" |
      grep -Ei "(brightness|level|duty|enable|timeout|mode|state|wakeup)$" |
      head -n 400); do
    [ -r "$f" ] || continue
    printf "%s=" "$f"
    cat "$f" 2>/dev/null | tr "\n" " "
    echo
  done
' > "$OUT/readable-keyboard-control-values.txt" 2>&1 || true

# Module dependency/alias metadata from the installed module tree.
"${ADB[@]}" shell '
  for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules /odm/lib/modules; do
    [ -d "$base" ] || continue
    echo "===== $base ====="
    for f in modules.dep modules.alias modules.load modules.softdep; do
      [ -r "$base/$f" ] || continue
      echo "--- $f ---"
      grep -Ei "aw9523_key|hynitron_touchpad|keypad_led|gpio_key|mtk_pmic_keys|mtk_disp_notify" "$base/$f" || true
    done
  done
' > "$OUT/module-metadata.txt" 2>&1 || true

# Pull only the small, already-loaded keyboard-related .ko files into the
# gitignored private evidence tree for host-side metadata/strings inspection.
for mod in aw9523_key hynitron_touchpad keypad_led gpio_key mtk_pmic_keys mtk_disp_notify; do
  remote="$("${ADB[@]}" shell "for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules /odm/lib/modules; do find \$base -maxdepth 2 -type f \( -name \"$mod.ko\" -o -name \"$mod.ko.*\" \) 2>/dev/null | head -n1; done" 2>/dev/null | tr -d "\r" | head -n1)"
  [[ -n "$remote" ]] || continue
  out="$OUT/modules/$(basename "$remote")"
  "${ADB[@]}" pull "$remote" "$out" >/dev/null 2>&1 || continue

  inspect="$out"
  case "$inspect" in
    *.zst)
      if command -v zstd >/dev/null 2>&1; then
        zstd -q -d -f "$inspect" -o "${inspect%.zst}" >/dev/null 2>&1 || true
        [[ -f "${inspect%.zst}" ]] && inspect="${inspect%.zst}"
      fi
      ;;
    *.gz)
      if command -v gzip >/dev/null 2>&1; then
        gzip -cd "$inspect" > "${inspect%.gz}" 2>/dev/null || true
        [[ -s "${inspect%.gz}" ]] && inspect="${inspect%.gz}"
      fi
      ;;
  esac

  {
    echo "===== $mod ====="
    echo "source=$remote"
    if command -v readelf >/dev/null 2>&1; then
      readelf -p .modinfo "$inspect" 2>/dev/null || true
    fi
    echo "-- relevant strings --"
    strings "$inspect" 2>/dev/null |
      grep -Ei "i2c|compatible|driver|aw9523|hynitron|keypad|keyboard|led|pwm|brightness|wakeup|suspend|resume|disp_notify|input_register|sysfs|proc" |
      sort -u | head -n 600 || true
  } >> "$OUT/module-inspection.txt"
done

# Device-tree candidates from both common mount points.
"${ADB[@]}" shell '
  for base in /proc/device-tree /sys/firmware/devicetree/base; do
    [ -d "$base" ] || continue
    echo "===== $base ====="
    find "$base" -maxdepth 8 -type d 2>/dev/null |
      grep -Ei "aw9523|keypad|keyboard|touchpad|hynitron|gpio.*key|pmic.*key|wakeup" |
      sort | head -n 800
  done
' > "$OUT/device-tree-driver-candidates.txt" 2>&1 || true

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "Keyboard driver inspection complete:"
echo "  $OUT"
echo
echo "Exact driver bindings:"
cat "$OUT/exact-driver-bindings.txt" 2>/dev/null || true
echo
echo "Input parent chains:"
cat "$OUT/input-parent-chain.txt" 2>/dev/null || true
echo
echo "Module metadata / relevant strings:"
cat "$OUT/module-metadata.txt" "$OUT/module-inspection.txt" 2>/dev/null | head -n 900 || true
echo
echo "Keyboard-light sysfs candidates:"
cat "$OUT/readable-keyboard-control-values.txt" 2>/dev/null | head -n 500 || true
echo
echo "Device-tree candidates:"
cat "$OUT/device-tree-driver-candidates.txt" 2>/dev/null | head -n 500 || true
