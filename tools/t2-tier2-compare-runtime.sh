#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOCK="${1:-$(ls -1dt "$ROOT"/artifacts/private/t2-tier2/*-stock-pre-n0-runtime 2>/dev/null | head -n1 || true)}"
SABLE="${2:-$(ls -1dt "$ROOT"/artifacts/private/t2-tier2/*-sable-n0-runtime 2>/dev/null | head -n1 || true)}"

if [[ -z "$STOCK" || ! -d "$STOCK" ]]; then
  echo "error: stock runtime directory not found; pass it as argument 1" >&2
  exit 2
fi
if [[ -z "$SABLE" || ! -d "$SABLE" ]]; then
  echo "error: Sable runtime directory not found; pass it as argument 2" >&2
  exit 3
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier2/$STAMP-stock-vs-sable-runtime"
REPORT="$OUT/REPORT.txt"
mkdir -p "$OUT/diffs"

pairs=(
  "core/identity.txt"
  "core/proc_input_devices.txt"
  "core/dumpsys_input.txt"
  "core/dumpsys_display.txt"
  "core/service_list.txt"
  "vintf/lshal.txt"
  "vintf/aidl_hal_services.txt"
  "security/keymint_gatekeeper_services.txt"
  "security/features.txt"
  "audio/audio.txt"
  "sensors/sensorservice.txt"
  "power/power.txt"
  "camera/media_camera.txt"
  "network/wifi.txt"
  "network/bluetooth.txt"
)

{
  echo "Titan 2 stock vs Sable runtime comparison"
  echo "timestamp_utc=$STAMP"
  echo "stock=$STOCK"
  echo "sable=$SABLE"
  echo
  for rel in "${pairs[@]}"; do
    safe="${rel//\//__}.diff"
    a="$STOCK/$rel"; b="$SABLE/$rel"
    if [[ -f "$a" && -f "$b" ]]; then
      diff -u "$a" "$b" > "$OUT/diffs/$safe" || true
      lines="$(wc -l < "$OUT/diffs/$safe")"
      printf '%-42s diff_lines=%s\n' "$rel" "$lines"
    else
      printf '%-42s missing stock=%s sable=%s\n' "$rel" "$([[ -f "$a" ]] && echo no || echo yes)" "$([[ -f "$b" ]] && echo no || echo yes)"
    fi
  done
  echo
  echo "Interpret diffs by subsystem; absence from Sable is not automatically a failure."
  echo "Use the stock service/HAL inventory as the reference for compatibility triage."
} > "$REPORT"

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo "Runtime comparison written:"
echo "  $REPORT"
echo "  diffs=$OUT/diffs"
