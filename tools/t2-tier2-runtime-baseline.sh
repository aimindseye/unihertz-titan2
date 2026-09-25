#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 ADB serial}"
LABEL="${1:-stock-pre-n0}"
ADB=(adb -s "$TITAN_SERIAL")
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier2/$STAMP-$LABEL-runtime"
REPORT="$OUT/REPORT.txt"
mkdir -p "$OUT"/{core,vintf,security,telephony,audio,sensors,power,camera,network}

if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  echo "error: Titan 2 is not reachable through adb serial $TITAN_SERIAL" >&2
  exit 2
fi

MODEL="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
if [[ "$MODEL" != *"Titan 2"* ]]; then
  echo "error: selected device does not report Titan 2 (model=$MODEL)" >&2
  exit 3
fi

capture() {
  local rel="$1"; shift
  local cmd="$*"
  mkdir -p "$(dirname "$OUT/$rel")"
  {
    echo "# command: $cmd"
    echo "# captured_utc: $(date -u +%FT%TZ)"
    timeout 90 "${ADB[@]}" shell "$cmd" 2>&1 || true
  } > "$OUT/$rel"
}

host_capture() {
  local rel="$1"; shift
  {
    echo "# command: $*"
    echo "# captured_utc: $(date -u +%FT%TZ)"
    timeout 90 "$@" 2>&1 || true
  } > "$OUT/$rel"
}

# Core identity / boot state.
capture core/identity.txt "printf 'model='; getprop ro.product.model; printf 'product='; getprop ro.product.device; printf 'build='; getprop ro.build.display.id; printf 'incremental='; getprop ro.build.version.incremental; printf 'release='; getprop ro.build.version.release; printf 'sdk='; getprop ro.build.version.sdk; printf 'spl='; getprop ro.build.version.security_patch; printf 'slot='; getprop ro.boot.slot_suffix; printf 'vbstate='; getprop ro.boot.verifiedbootstate; printf 'flash_locked='; getprop ro.boot.flash.locked; printf 'vbmeta_state='; getprop ro.boot.vbmeta.device_state; printf 'dynamic='; getprop ro.boot.dynamic_partitions; printf 'virtual_ab='; getprop ro.virtual_ab.enabled; printf 'vendor_api='; getprop ro.vendor.api_level; printf 'vndk='; getprop ro.vndk.version; uname -a"
capture core/getprop.txt "getprop"
capture core/proc_input_devices.txt "cat /proc/bus/input/devices"
capture core/dumpsys_input.txt "dumpsys input"
capture core/dumpsys_display.txt "dumpsys display"
capture core/dumpsys_window_displays.txt "dumpsys window displays"
capture core/surfaceflinger_displays.txt "dumpsys SurfaceFlinger --display-id 2>/dev/null || dumpsys SurfaceFlinger"
capture core/package_features.txt "pm list features"
capture core/service_list.txt "service list"
capture core/dumpsys_list.txt "dumpsys -l"
capture core/apex.txt "cmd apex list --active 2>/dev/null || pm list packages -a | grep apex"
capture core/mounts.txt "cat /proc/mounts"
capture core/filesystems.txt "df -T"
capture core/selinux.txt "getenforce; cat /sys/fs/selinux/policyvers 2>/dev/null || true"

# VINTF / vendor compatibility.
capture vintf/vendor_files.txt "find /vendor/etc/vintf -type f -maxdepth 3 -print 2>/dev/null | sort"
capture vintf/system_files.txt "find /system/etc/vintf /system_ext/etc/vintf /product/etc/vintf -type f -maxdepth 3 -print 2>/dev/null | sort"
capture vintf/vendor_vintf.txt "for f in \$(find /vendor/etc/vintf -type f 2>/dev/null | sort); do echo =====\$f=====; cat \$f; echo; done"
capture vintf/system_vintf.txt "for f in \$(find /system/etc/vintf /system_ext/etc/vintf /product/etc/vintf -type f 2>/dev/null | sort); do echo =====\$f=====; cat \$f; echo; done"
capture vintf/lshal.txt "lshal 2>/dev/null || true"
capture vintf/aidl_hal_services.txt "service list | grep -Ei 'android\.hardware|vendor\.|mediatek|mtk' || true"

# Security / AVB / biometric service inventory.
capture security/boot_security_props.txt "getprop | grep -Ei 'verifiedboot|vbmeta|avb|flash.locked|rollback|security_patch|first_api|vendor.api|vndk' || true"
capture security/keymint_gatekeeper_services.txt "service list | grep -Ei 'keymint|gatekeeper|secureclock|sharedsecret|weaver|strongbox|biometric|fingerprint|face' || true"
capture security/features.txt "pm list features | grep -Ei 'strongbox|fingerprint|face|biometric|keystore|secure' || true"
capture security/biometric.txt "dumpsys biometric 2>/dev/null || true"
capture security/fingerprint.txt "dumpsys fingerprint 2>/dev/null || true"
capture security/keystore.txt "dumpsys android.security.keystore 2>/dev/null || dumpsys keystore 2>/dev/null || true"

# Telephony / IMS. These raw files may contain carrier/subscriber identifiers.
capture telephony/phone.txt "dumpsys telephony.registry 2>/dev/null || true"
capture telephony/telecom.txt "dumpsys telecom 2>/dev/null || true"
capture telephony/ims.txt "dumpsys ims 2>/dev/null || dumpsys imsservice 2>/dev/null || true"
capture telephony/carrier_config.txt "dumpsys carrier_config 2>/dev/null || true"
capture telephony/subscriptions.txt "dumpsys isub 2>/dev/null || dumpsys subscription 2>/dev/null || true"
capture telephony/connectivity.txt "dumpsys connectivity 2>/dev/null || true"

# Audio.
capture audio/audio.txt "dumpsys audio"
capture audio/audio_flinger.txt "dumpsys media.audio_flinger 2>/dev/null || true"
capture audio/audio_policy.txt "dumpsys media.audio_policy 2>/dev/null || true"
capture audio/vibrator.txt "dumpsys vibrator_manager 2>/dev/null || dumpsys vibrator 2>/dev/null || true"

# Sensors / NFC / GNSS / USB.
capture sensors/sensorservice.txt "dumpsys sensorservice"
capture sensors/nfc.txt "dumpsys nfc 2>/dev/null || true"
capture sensors/location.txt "dumpsys location 2>/dev/null || true"
capture sensors/gnss_services.txt "service list | grep -Ei 'gnss|gps|location' || true"
capture sensors/usb.txt "dumpsys usb 2>/dev/null || true"
capture sensors/ir_features.txt "pm list features | grep -Ei 'consumerir|infrared|ir' || true"

# Power / thermal / battery.
capture power/power.txt "dumpsys power"
capture power/battery.txt "dumpsys battery"
capture power/thermal.txt "dumpsys thermalservice 2>/dev/null || true"
capture power/deviceidle.txt "dumpsys deviceidle 2>/dev/null || true"
capture power/power_supply.txt "for d in /sys/class/power_supply/*; do echo =====\$d=====; for f in type status health capacity charge_type usb_type current_now voltage_now temp; do [ -r \$d/\$f ] && echo \$f=\$(cat \$d/\$f); done; done"
capture power/wakeup_sources.txt "cat /sys/kernel/debug/wakeup_sources 2>/dev/null || cat /d/wakeup_sources 2>/dev/null || true"
capture power/thermal_zones.txt "for d in /sys/class/thermal/thermal_zone*; do [ -d \$d ] || continue; echo =====\$d=====; cat \$d/type 2>/dev/null; cat \$d/temp 2>/dev/null; done"

# Camera and networking acceptance baselines.
capture camera/media_camera.txt "dumpsys media.camera 2>/dev/null || true"
capture network/wifi.txt "dumpsys wifi 2>/dev/null || true"
capture network/bluetooth.txt "dumpsys bluetooth_manager 2>/dev/null || true"

host_capture core/adb_version.txt adb version

cat > "$OUT/PRIVATE_EVIDENCE_NOTICE.txt" <<'EOF'
PRIVATE EVIDENCE ONLY.
Files in this directory may contain serials, carrier/subscriber information,
network identifiers, Bluetooth/Wi-Fi details, app state, and other device-
specific data. Do not commit the raw directory. Commit only reviewed/redacted
conclusions and hashes.
EOF

{
  echo "Titan 2 Tier 2 runtime baseline"
  echo "timestamp_utc=$STAMP"
  echo "label=$LABEL"
  echo "model=$MODEL"
  echo "build=$("${ADB[@]}" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
  echo "incremental=$("${ADB[@]}" shell getprop ro.build.version.incremental 2>/dev/null | tr -d '\r')"
  echo "security_patch=$("${ADB[@]}" shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')"
  echo "slot=$("${ADB[@]}" shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r')"
  echo "verified_boot=$("${ADB[@]}" shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r')"
  echo "flash_locked=$("${ADB[@]}" shell getprop ro.boot.flash.locked 2>/dev/null | tr -d '\r')"
  echo "selinux=$("${ADB[@]}" shell getenforce 2>/dev/null | tr -d '\r')"
  echo
  echo "Captured groups:"
  for d in core vintf security telephony audio sensors power camera network; do
    printf '  %-12s %s files\n' "$d" "$(find "$OUT/$d" -type f | wc -l)"
  done
  echo
  echo "This collector is read-only. Raw outputs remain private."
} > "$REPORT"

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo "Tier 2 runtime baseline written:"
echo "  $REPORT"
echo "  evidence=$OUT"
echo "Attach REPORT.txt for metadata only; attach specific private files only when analysis requires them."
