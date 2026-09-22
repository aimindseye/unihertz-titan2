#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/$STAMP"

usage() {
  cat <<'EOF'
Usage:
  ./tools/t2-r0-collect.sh snapshot
  ./tools/t2-r0-collect.sh ota-watch

snapshot   Collect a read-only factory-baseline snapshot over ADB.
ota-watch  Follow logcat while you manually trigger System Update on the phone.

All output is local under artifacts/private/ and is gitignored.
Raw Android diagnostics may contain identifiers. Review/redact before sharing.
EOF
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "error: adb is not in PATH" >&2
    exit 1
  fi

  local state
  state="$(adb get-state 2>/dev/null || true)"
  if [[ "$state" != "device" ]]; then
    echo "error: no authorized Android device is connected (adb state: ${state:-none})" >&2
    echo "Check the USB cable, USB debugging, and the authorization prompt on the phone." >&2
    exit 1
  fi
}

new_output_dir() {
  mkdir -p "$OUT"
  printf '%s\n' "$OUT"
}

capture() {
  local name="$1"
  shift
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n'
    "$@"
  } >"$OUT/$name" 2>&1 || true
}

capture_shell() {
  local name="$1"
  shift
  local cmd="$*"
  {
    printf '$ adb shell %s\n' "$cmd"
    adb shell "$cmd"
  } >"$OUT/$name" 2>&1 || true
}

write_manifest() {
  (
    cd "$OUT"
    find . -type f ! -name SHA256SUMS -print0 \
      | sort -z \
      | xargs -0 shasum -a 256 > SHA256SUMS
  )
}

snapshot() {
  new_output_dir >/dev/null

  {
    echo "# Titan 2 R0 curated properties"
    echo "# Deliberately excludes common serial/IMEI/MEID/MAC/ICCID properties."
    for key in \
      ro.product.manufacturer \
      ro.product.brand \
      ro.product.model \
      ro.product.device \
      ro.product.name \
      ro.product.board \
      ro.product.cpu.abi \
      ro.product.cpu.abilist \
      ro.board.platform \
      ro.hardware \
      ro.boot.hardware \
      ro.soc.manufacturer \
      ro.soc.model \
      ro.build.fingerprint \
      ro.build.id \
      ro.build.display.id \
      ro.build.type \
      ro.build.tags \
      ro.build.version.release \
      ro.build.version.release_or_codename \
      ro.build.version.sdk \
      ro.build.version.security_patch \
      ro.build.version.incremental \
      ro.vendor.build.fingerprint \
      ro.vendor.build.version.sdk \
      ro.vendor.build.security_patch \
      ro.vendor.api_level \
      ro.board.api_level \
      ro.vndk.version \
      ro.treble.enabled \
      ro.build.ab_update \
      ro.virtual_ab.enabled \
      ro.virtual_ab.compression.enabled \
      ro.boot.slot_suffix \
      ro.boot.dynamic_partitions \
      ro.boot.super_partition \
      ro.boot.flash.locked \
      ro.boot.verifiedbootstate \
      ro.boot.veritymode \
      ro.boot.vbmeta.device_state \
      ro.boot.avb_version \
      ro.boot.vbmeta.digest
    do
      value="$(adb shell getprop "$key" 2>/dev/null | tr -d '\r')"
      printf '%-40s %s\n' "$key" "$value"
    done
  } >"$OUT/properties.txt"

  capture adb-devices.txt adb devices -l
  capture_shell kernel.txt uname -a
  {
    adb shell cat /proc/version 2>/dev/null || true
  } >>"$OUT/kernel.txt"

  capture_shell partitions.txt cat /proc/partitions
  capture_shell block-by-name.txt ls -l /dev/block/by-name
  capture_shell block-mapper.txt ls -l /dev/block/mapper
  capture_shell filesystems.txt df -h
  capture_shell mounts.txt mount
  capture_shell logical-partitions.txt lpdump

  capture_shell input-devices.txt getevent -lp
  capture_shell keylayouts-system.txt ls -la /system/usr/keylayout
  capture_shell keylayouts-vendor.txt ls -la /vendor/usr/keylayout
  capture_shell keylayouts-odm.txt ls -la /odm/usr/keylayout

  capture_shell display-size.txt wm size
  capture_shell display-density.txt wm density
  capture_shell display-service.txt dumpsys display
  capture_shell surfaceflinger-displays.txt dumpsys SurfaceFlinger --display-id

  capture_shell features.txt pm list features
  capture_shell overlays.txt cmd overlay list
  capture_shell input-service.txt dumpsys input

  write_manifest

  cat <<EOF
R0 snapshot complete.

Local private capture:
  $OUT

Next:
  1. Review the files locally.
  2. Copy only redacted, non-secret observations into docs/FACTORY_BASELINE.md.
  3. Do not commit artifacts/private/.
EOF
}

ota_watch() {
  new_output_dir >/dev/null

  local raw="$OUT/ota-logcat.txt"
  local candidates="$OUT/ota-candidates.txt"

  cat <<EOF
Capturing Android logcat without clearing the device log buffer.

Now, on the Titan 2:
  Settings -> About phone -> System Update -> check for/update

Let the updater reach the point where it discovers or starts an update.
Press Ctrl-C here when done.

Raw logcat can contain private identifiers and app activity. It is gitignored.
EOF

  finish() {
    trap - INT TERM
    write_manifest || true
    echo
    echo "OTA watch stopped."
    echo "Raw log:       $raw"
    echo "Candidate log: $candidates"
    echo "Review/redact before sharing or committing any excerpt."
    exit 0
  }
  trap finish INT TERM

  adb logcat -v threadtime 2>&1 \
    | tee "$raw" \
    | awk 'BEGIN { IGNORECASE=1 }
      /https?:\/\// ||
      /ota/ ||
      /system[ _-]*update/ ||
      /update_engine/ ||
      /download/ ||
      /payload/ ||
      /googleapis/ ||
      /drive\.google/ ||
      /gvt1/ ||
      /unihertz/ ||
      /fota/ {
        print
        fflush()
      }' \
    | tee "$candidates"

  write_manifest
}

main() {
  require_adb

  case "${1:-}" in
    snapshot) snapshot ;;
    ota-watch) ota_watch ;;
    -h|--help|help|"") usage ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
