#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"

MODE="${1:-}"
case "$MODE" in
  lockscreen|screenoff) ;;
  *)
    echo "Usage: TITAN_SERIAL=<serial> $0 lockscreen|screenoff [q|space|enter|func1|func2 ...]" >&2
    exit 2
    ;;
esac
shift || true

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

all_labels=(q space enter func1 func2)
if (( $# > 0 )); then
  labels=("$@")
else
  labels=("${all_labels[@]}")
fi

for label in "${labels[@]}"; do
  case "$label" in
    q|space|enter|func1|func2) ;;
    *)
      echo "error: unknown key label '$label'" >&2
      echo "valid labels: q space enter func1 func2" >&2
      exit 2
      ;;
  esac
done

instruction_for() {
  case "$1" in
    q) echo "press Q once" ;;
    space) echo "press Space once" ;;
    enter) echo "press Enter once" ;;
    func1) echo "press the UPPER red side button (Func1) once" ;;
    func2) echo "press the LOWER red side button (Func2) once" ;;
  esac
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-a-$MODE"
mkdir -p "$OUT"

cat > "$OUT/METADATA.txt" <<EOF
capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
device_family=Titan 2
mode=$MODE
operation=guided observational key-context capture
selected_keys=${labels[*]}
EOF

echo
echo "Titan 2 Section A guided context capture: $MODE"
echo "Selected keys: ${labels[*]}"
echo "No repeated shell commands are needed."
echo

count=0
for label in "${labels[@]}"; do
  count=$((count + 1))
  instruction="$(instruction_for "$label")"

  echo "------------------------------------------------------------"
  echo "Test $count of ${#labels[@]}: $label"

  if [[ "$MODE" == "lockscreen" ]]; then
    echo "BEFORE starting capture:"
    echo "  1. Wake the phone with Power."
    echo "  2. Confirm the credential/PIN lockscreen is visible."
    echo "  3. Do NOT unlock it."
    echo "  4. Do NOT touch Power during the 6-second capture."
  else
    echo "BEFORE starting capture:"
    echo "  Turn the main screen OFF and leave the phone locked."
    echo "  Do not wake it before the capture starts."
  fi

  echo "When the phone is in that state, press ENTER here."
  read -r

  "${ADB[@]}" shell cat /proc/uptime > "$OUT/$label-uptime-before.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power-before.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window policy > "$OUT/$label-window-policy-before.txt" 2>&1 || true

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
