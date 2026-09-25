#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"
ADB=(adb -s "$TITAN_SERIAL")

die() {
  echo "error: $*" >&2
  exit 1
}

state="$("${ADB[@]}" get-state 2>/dev/null || true)"
[[ "$state" == "device" ]] || die "selected ADB target is not ready (state=${state:-none})"

model="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$model" == "Titan 2" ]] || die "selected device reports '${model:-unknown}', expected Titan 2"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier1/$STAMP-section-c-rotation-brightness"
mkdir -p "$OUT"

snapshot() {
  local label="$1"

  "${ADB[@]}" shell dumpsys display > "$OUT/$label-dumpsys-display.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys window displays > "$OUT/$label-window-displays.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys input > "$OUT/$label-dumpsys-input.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys power > "$OUT/$label-power.txt" 2>&1 || true
  "${ADB[@]}" shell dumpsys SurfaceFlinger --display-id > "$OUT/$label-surfaceflinger-display-id.txt" 2>&1 || true

  "${ADB[@]}" shell '
    echo "===== system ====="
    settings list system 2>/dev/null |
      grep -Ei "brightness|rotation|accelerometer|display|subscreen|sub_screen|mini" || true
    echo "===== secure ====="
    settings list secure 2>/dev/null |
      grep -Ei "brightness|rotation|accelerometer|display|subscreen|sub_screen|mini" || true
    echo "===== global ====="
    settings list global 2>/dev/null |
      grep -Ei "brightness|rotation|accelerometer|display|subscreen|sub_screen|mini" || true
  ' > "$OUT/$label-settings.txt" 2>&1 || true

  "${ADB[@]}" shell '
    for d in /sys/class/backlight/*; do
      [ -d "$d" ] || continue
      echo "===== $d ====="
      for f in brightness actual_brightness max_brightness bl_power; do
        if [ -r "$d/$f" ]; then
          printf "%s=" "$f"
          cat "$d/$f"
        fi
      done
    done
  ' > "$OUT/$label-backlight.txt" 2>&1 || true
}

observe() {
  local key="$1"
  local prompt="$2"
  local answer
  echo
  echo "$prompt"
  read -r -p "> " answer
  printf '%s\t%s\n' "$key" "$answer" >> "$OUT/OBSERVATIONS.tsv"
}

{
  echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device_family=Titan 2"
  echo "operation=guided observational rotation/brightness capture"
  echo "collector=tools/section-c-rotation-brightness.sh"
  echo "collector_git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$OUT/METADATA.txt"

echo
echo "Titan 2 Section C — rear rotation + brightness"
echo
echo "No timed steps. Use only normal stock UI controls."
echo

echo "STEP 1 — rear ON, phone upright"
echo "Wake the rear SubScreen with Func1."
echo "Hold the phone in its normal upright orientation."
echo "When the stock rear UI is visible and stable, press ENTER."
read -r
snapshot upright
observe upright-visible-orientation   "Describe the rear UI orientation in a few words (for example: upright / rotated 90 / upside-down)."

echo
echo "STEP 2 — rotate phone 90 degrees clockwise"
echo "Keep the rear SubScreen ON. Physically rotate the whole phone 90 degrees clockwise."
echo "Wait about 2 seconds for any autorotation."
echo "Then press ENTER."
read -r
snapshot clockwise-90
observe clockwise-90-result   "Did the rear UI rotate to stay upright? Answer yes/no/other and add a short note."

echo
echo "STEP 3 — rotate phone 180 degrees from normal"
echo "Keep the rear SubScreen ON. Turn the phone upside-down (180 degrees from normal)."
echo "Wait about 2 seconds, then press ENTER."
read -r
snapshot upside-down-180
observe upside-down-180-result   "Did the rear UI rotate to stay upright? Answer yes/no/other and add a short note."

echo
echo "STEP 4 — return phone upright"
echo "Return to normal upright orientation and wait for the rear UI to settle."
echo "Press ENTER."
read -r
snapshot upright-restored

echo
echo "STEP 5 — rear brightness control"
echo "On the rear SubScreen, look for a stock brightness control."
echo "Do NOT change main-screen brightness."
echo "If a rear brightness control exists, set it as LOW as practical (not fully off), then press ENTER."
echo "If no rear brightness control exists, just press ENTER."
read -r
snapshot rear-brightness-low
observe rear-brightness-control-exists   "Does the stock rear UI expose its own brightness control? Answer yes/no/other."
observe rear-brightness-low-visible   "If you changed rear brightness low, did the rear panel visibly dim while the main display brightness stayed unchanged? Answer yes/no/not-tested."

echo
echo "STEP 6 — rear brightness HIGH"
echo "If a rear brightness control exists, set it high/max now. Otherwise make no change."
echo "Press ENTER when ready."
read -r
snapshot rear-brightness-high
observe rear-brightness-high-visible   "If tested, did the rear panel visibly brighten while the main display brightness stayed unchanged? Answer yes/no/not-tested."

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)

echo
echo "============================================================"
echo "Rotation/brightness capture complete:"
echo "  $OUT"
echo

echo "Visible observations:"
cat "$OUT/OBSERVATIONS.tsv" 2>/dev/null || true

echo
echo "Rotation summary:"
for f in "$OUT"/*-dumpsys-display.txt "$OUT"/*-window-displays.txt "$OUT"/*-dumpsys-input.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  grep -nEi 'displayId=2|local:4627039422300187651|rotation|orientation|Viewport INTERNAL|logicalFrame|physicalFrame' "$f" | head -n 140 || true
done

echo
echo "Brightness/backlight summary:"
for f in "$OUT"/*-backlight.txt "$OUT"/*-settings.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== $(basename "$f") ====="
  cat "$f"
done
