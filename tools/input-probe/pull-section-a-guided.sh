#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"

ADB=(adb -s "$TITAN_SERIAL")
PKG=org.sableos.research.inputprobe
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-a-guided"

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || {
  echo "error: selected ADB target is not ready (state=${state:-none})" >&2
  exit 1
}

model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$model" == "Titan 2" ]] || {
  echo "error: selected device reports '${model:-unknown}', expected Titan 2" >&2
  exit 1
}

mkdir -p "$OUT"

if ! "${ADB[@]}" shell run-as "$PKG" test -r files/section-a-guided.tsv; then
  echo "error: guided result file not found." >&2
  echo "Run Input Probe -> Start guided A and finish all steps first." >&2
  exit 2
fi

"${ADB[@]}" shell run-as "$PKG" cat files/section-a-guided.tsv   > "$OUT/section-a-guided.tsv"

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=read-only result pull"
  echo "package=$PKG"
  echo "default_ime=$("${ADB[@]}" shell settings get secure default_input_method 2>/dev/null | tr -d '\r')"
  echo "mouse_keys=$("${ADB[@]}" shell settings get secure accessibility_mouse_keys_enabled 2>/dev/null | tr -d '\r')"
  echo "build_display=$("${ADB[@]}" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
  echo "incremental=$("${ADB[@]}" shell getprop ro.build.version.incremental 2>/dev/null | tr -d '\r')"
  echo "security_patch=$("${ADB[@]}" shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')"
} > "$OUT/METADATA.txt"

"${ADB[@]}" shell dumpsys input_method > "$OUT/dumpsys-input-method.txt" 2>&1 || true

(
  cd "$OUT"
  sha256sum METADATA.txt section-a-guided.tsv dumpsys-input-method.txt > SHA256SUMS
)

echo "Guided Section A results pulled to:"
echo "  $OUT"
echo
echo "Compact summary:"
grep -E $'\t(STEP_START|STEP_END|KEY)\t' "$OUT/section-a-guided.tsv"   | grep -E 'STEP_START|STEP_END|action=(DOWN|UP)'   | head -n 250 || true
