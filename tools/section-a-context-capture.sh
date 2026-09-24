#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"

MODE="${1:-}"
case "$MODE" in
  lockscreen|screenoff) ;;
  *)
    echo "Usage: TITAN_SERIAL=<serial> $0 lockscreen|screenoff" >&2
    exit 2
    ;;
esac

ADB=(adb -s "$TITAN_SERIAL")
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

command -v timeout >/dev/null 2>&1 || {
  echo "error: host timeout command required" >&2
  exit 1
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-a-$MODE"
mkdir -p "$OUT"

cat > "$OUT/METADATA.txt" <<EOF
capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
device_family=Titan 2
mode=$MODE
operation=guided observational key-context capture
EOF

labels=(q space enter func1 func2)
instructions=(
  "press Q once"
  "press Space once"
  "press Enter once"
  "press the UPPER red side button (Func1) once"
  "press the LOWER red side button (Func2) once"
)

echo
echo "Titan 2 Section A guided context capture: $MODE"
echo "No repeated shell commands are needed."
echo

for i in "${!labels[@]}"; do
  label="${labels[$i]}"
  instruction="${instructions[$i]}"

  echo "------------------------------------------------------------"
  echo "Test $((i + 1)) of ${#labels[@]}: $label"

  if [[ "$MODE" == "lockscreen" ]]; then
    echo "Put the phone on the visible lockscreen and DO NOT unlock it."
  else
    echo "Turn the main screen OFF and leave the phone locked."
  fi

  echo "When ready, press ENTER here."
  read -r

  "${ADB[@]}" shell cat /proc/uptime > "$OUT/$label-uptime-before.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power-before.txt" 2>&1 || true

  echo
  echo "CAPTURING FOR 6 SECONDS: $instruction"
  echo

  {
    echo '$ adb -s <redacted> shell getevent -lt'
    timeout --signal=INT 6 "${ADB[@]}" shell getevent -lt
  } > "$OUT/$label-events.txt" 2>&1 || true

  "${ADB[@]}" shell cat /proc/uptime > "$OUT/$label-uptime-after.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power-after.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window policy > "$OUT/$label-window-policy-after.txt" 2>&1 || true

  if [[ "$MODE" == "screenoff" ]]; then
    echo "What visibly happened?"
    echo "  n = neither screen woke"
    echo "  m = main screen woke"
    echo "  r = rear SubScreen woke"
    echo "  b = both"
    echo "  o = other"
    read -r -p "[n/m/r/b/o]: " obs
    printf '%s\t%s\n' "$label" "$obs" >> "$OUT/OBSERVATIONS.tsv"
  fi

  echo "Captured: $label"
  echo
done

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0     | sort -z     | xargs -0 sha256sum > SHA256SUMS
)

echo "Complete:"
echo "  $OUT"
echo
echo "Compact raw-key summary:"
for f in "$OUT"/*-events.txt; do
  echo
  echo "===== $(basename "$f") ====="
  grep -E '/dev/input/event|EV_KEY|EV_MSC' "$f" || true
done

if [[ -f "$OUT/OBSERVATIONS.tsv" ]]; then
  echo
  echo "Visible observations:"
  cat "$OUT/OBSERVATIONS.tsv"
fi
