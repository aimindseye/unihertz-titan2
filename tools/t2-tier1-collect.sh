#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="$ROOT/artifacts/private/t2-tier1"
OUT="$BASE/$STAMP"
ADB=()

usage() {
  cat <<'EOF'
Usage:
  TITAN_SERIAL=<adb-serial> ./tools/t2-tier1-collect.sh baseline
  TITAN_SERIAL=<adb-serial> ./tools/t2-tier1-collect.sh state <label>
  TITAN_SERIAL=<adb-serial> ./tools/t2-tier1-collect.sh events <label> [seconds]

Commands:
  baseline
    Read-only Tier-1 static capture for keyboard/input, display/SubScreen,
    packages/services/overlays and feature ownership.

  state <label>
    Read-only point-in-time input/display/settings snapshot. Use labels such as:
      mouse-off
      mouse-on
      subscreen-enabled
      subscreen-disabled
      portrait
      landscape

  events <label> [seconds]
    Capture raw Linux input events from all input devices for a short,
    user-controlled test. Default duration is 12 seconds.

All raw output stays under:
  artifacts/private/t2-tier1/<UTC timestamp>/

That tree is gitignored. Review/redact before publishing anything.

This collector does not change device settings. Any mouse-mode, SubScreen,
rotation, lockscreen or screen-off state must be changed manually on the phone
before invoking the matching state/events capture.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

slugify() {
  printf '%s' "$1" | tr '[:space:]/' '__' | tr -cd 'A-Za-z0-9_.-'
}

select_titan() {
  command -v adb >/dev/null 2>&1 || die "adb is not in PATH"
  : "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly; multiple Android devices may be attached}"

  ADB=(adb -s "$TITAN_SERIAL")

  local state model
  state="$("${ADB[@]}" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"

  model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
  [[ "$model" == "Titan 2" ]] || die "selected device reports model '${model:-unknown}', expected 'Titan 2'"

  # Deliberately do not write the serial into capture metadata.
}

new_out() {
  mkdir -p "$OUT"
}

capture_host() {
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
    printf '$ adb -s <redacted> shell %s\n' "$cmd"
    "${ADB[@]}" shell "$cmd"
  } >"$OUT/$name" 2>&1 || true
}

write_hashes() {
  (
    cd "$OUT"
    if command -v sha256sum >/dev/null 2>&1; then
      find . -type f ! -name SHA256SUMS -print0 \
        | sort -z \
        | xargs -0 sha256sum > SHA256SUMS
    else
      find . -type f ! -name SHA256SUMS -print0 \
        | sort -z \
        | xargs -0 shasum -a 256 > SHA256SUMS
    fi
  )
}

write_metadata() {
  {
    echo "# Titan 2 Tier-1 capture metadata"
    echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "device_family=Titan 2"
    echo "operation=read-only"
    echo "collector=tools/t2-tier1-collect.sh"
    echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "host_kernel=$(uname -srmo 2>/dev/null || true)"
    echo
    echo "# adb"
    adb version 2>/dev/null || true
    echo
    echo "# curated device baseline (no telephony identifiers)"
    for key in \
      ro.product.manufacturer \
      ro.product.brand \
      ro.product.model \
      ro.product.device \
      ro.product.name \
      ro.product.board \
      ro.board.platform \
      ro.soc.manufacturer \
      ro.soc.model \
      ro.build.id \
      ro.build.display.id \
      ro.build.version.incremental \
      ro.build.version.release \
      ro.build.version.sdk \
      ro.build.version.security_patch \
      ro.vendor.build.version.security_patch \
      ro.vendor.api_level \
      ro.board.api_level \
      ro.vndk.version \
      ro.boot.slot_suffix \
      ro.boot.flash.locked \
      ro.boot.verifiedbootstate \
      ro.boot.vbmeta.device_state
    do
      value="$("${ADB[@]}" shell getprop "$key" 2>/dev/null | tr -d '\r')"
      printf '%-40s %s\n' "$key" "$value"
    done
  } >"$OUT/METADATA.txt"
}

capture_keymap_files() {
  capture_shell input-map-files.txt '
for dir in   /odm/usr/keylayout /odm/usr/keychars /odm/usr/idc   /vendor/usr/keylayout /vendor/usr/keychars /vendor/usr/idc   /system/usr/keylayout /system/usr/keychars /system/usr/idc   /system_ext/usr/keylayout /system_ext/usr/keychars /system_ext/usr/idc   /product/usr/keylayout /product/usr/keychars /product/usr/idc
do
  if [ -d "$dir" ]; then
    echo
    echo "===== DIRECTORY $dir ====="
    ls -la "$dir" 2>&1
    for f in "$dir"/*.kl "$dir"/*.kcm "$dir"/*.idc; do
      [ -f "$f" ] || continue
      echo
      echo "===== FILE $f ====="
      cat "$f" 2>&1
    done
  fi
done
'
}

capture_filtered_settings() {
  capture_shell settings-input-display.txt '
for ns in system secure global; do
  echo
  echo "===== settings $ns (filtered) ====="
  settings list "$ns" 2>/dev/null     | grep -Ei "keyboard|key_|keys|mouse|pointer|touch|gesture|shortcut|programm|red|sym|fn|backlight|subscreen|sub_screen|secondary|display|rotation|brightness|kika"     || true
done
'
}

capture_package_candidates() {
  capture_shell package-candidates.txt '
echo "===== package paths/names (candidate filter) ====="
pm list packages -f 2>/dev/null   | grep -Ei "agui|unihertz|kika|keyboard|input|mouse|touch|gesture|subscreen|sub\.screen|secondary|launcher|systemui"   || true

echo
echo "===== enabled IMEs ====="
ime list -s 2>/dev/null || true

echo
echo "===== all IMEs ====="
ime list -a 2>/dev/null || true
'
}

capture_runtime_owners() {
  capture_shell runtime-owner-candidates.txt '
echo "===== services (candidate filter) ====="
service list 2>/dev/null   | grep -Ei "input|keyboard|mouse|touch|display|sub|window|agui|unihertz|gesture"   || true

echo
echo "===== dumpsys services (candidate filter) ====="
dumpsys -l 2>/dev/null   | grep -Ei "input|keyboard|mouse|touch|display|sub|window|agui|unihertz|gesture"   || true

echo
echo "===== processes (candidate filter) ====="
ps -A 2>/dev/null   | grep -Ei "agui|unihertz|kika|keyboard|input|mouse|touch|gesture|subscreen|surfaceflinger|systemui"   || true
'
}

capture_baseline() {
  new_out
  write_metadata

  # Tier 1 A/B — Linux + Android input pipeline.
  capture_shell proc-input-devices.txt cat /proc/bus/input/devices
  capture_shell getevent-capabilities.txt getevent -lp
  capture_shell dumpsys-input.txt dumpsys input
  capture_shell dumpsys-input-method.txt dumpsys input_method
  capture_shell input-command-help.txt cmd input help
  capture_keymap_files
  capture_filtered_settings
  capture_package_candidates

  # Tier 1 C — display / touch association / insets / rotation.
  capture_shell wm-size.txt wm size
  capture_shell wm-density.txt wm density
  capture_shell wm-user-rotation.txt wm user-rotation
  capture_shell dumpsys-display.txt dumpsys display
  capture_shell dumpsys-window-displays.txt dumpsys window displays
  capture_shell dumpsys-window-policy.txt dumpsys window policy
  capture_shell surfaceflinger-display-id.txt dumpsys SurfaceFlinger --display-id
  capture_shell surfaceflinger-displays-alt.txt dumpsys SurfaceFlinger --displays
  capture_shell display-command-help.txt cmd display help

  # Tier 1 D — ownership candidates.
  capture_shell overlays.txt cmd overlay list
  capture_shell package-system-list.txt pm list packages -s -f
  capture_shell package-third-party-list.txt pm list packages -3 -f
  capture_shell service-list.txt service list
  capture_shell dumpsys-service-list.txt dumpsys -l
  capture_runtime_owners

  # Helpful read-only platform context for later classification.
  capture_shell features.txt pm list features
  capture_shell properties-input-display.txt '
getprop 2>/dev/null   | grep -Ei "keyboard|keypad|input|touch|mouse|pointer|display|subscreen|secondary|agui|unihertz"   || true
'
  capture_shell selinux-state.txt getenforce
  capture_shell kernel.txt uname -a

  write_hashes

  cat <<EOF
Tier-1 baseline capture complete.

Private output:
  $OUT

Do not commit the raw directory.

Next:
  1. Run the summary commands from docs/TITAN2_TIER1_CAPTURE_RUNBOOK.md.
  2. Then capture interactive key/mouse/SubScreen event sessions.
EOF
}

capture_state() {
  local label
  label="$(slugify "${1:-}")"
  [[ -n "$label" ]] || die "state requires a non-empty label"

  OUT="$BASE/$STAMP-state-$label"
  new_out
  write_metadata

  {
    echo "label=$label"
    echo "operation=read-only point-in-time state capture"
  } >>"$OUT/METADATA.txt"

  capture_shell dumpsys-input.txt dumpsys input
  capture_shell getevent-capabilities.txt getevent -lp
  capture_shell dumpsys-display.txt dumpsys display
  capture_shell dumpsys-window-displays.txt dumpsys window displays
  capture_shell dumpsys-window-policy.txt dumpsys window policy
  capture_shell surfaceflinger-display-id.txt dumpsys SurfaceFlinger --display-id
  capture_filtered_settings
  capture_runtime_owners
  write_hashes

  echo "State capture complete: $OUT"
}

capture_events() {
  local label seconds
  label="$(slugify "${1:-}")"
  seconds="${2:-12}"

  [[ -n "$label" ]] || die "events requires a non-empty label"
  [[ "$seconds" =~ ^[0-9]+$ ]] || die "seconds must be an integer"
  (( seconds >= 2 && seconds <= 120 )) || die "seconds must be between 2 and 120"

  command -v timeout >/dev/null 2>&1 || die "host 'timeout' command is required"

  OUT="$BASE/$STAMP-events-$label"
  new_out
  write_metadata

  {
    echo "label=$label"
    echo "duration_seconds=$seconds"
    echo "operation=read-only raw input event observation"
  } >>"$OUT/METADATA.txt"

  cat <<EOF
Capturing raw Linux input events for $seconds seconds.

Label:
  $label

Perform ONLY the intended test sequence now.
All input devices are observed so we can identify which device owns the event.
EOF

  {
    echo '$ adb -s <redacted> shell getevent -lt'
    timeout --signal=INT "$seconds" "${ADB[@]}" shell getevent -lt
  } >"$OUT/getevent-events.txt" 2>&1 || true

  capture_shell post-dumpsys-input.txt dumpsys input
  write_hashes

  echo "Event capture complete: $OUT"
}

main() {
  select_titan

  case "${1:-}" in
    baseline)
      capture_baseline
      ;;
    state)
      shift
      capture_state "${1:-}"
      ;;
    events)
      shift
      capture_events "${1:-}" "${2:-12}"
      ;;
    help|-h|--help|"")
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
