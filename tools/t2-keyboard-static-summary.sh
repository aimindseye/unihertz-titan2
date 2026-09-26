#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT/artifacts/private/t2-tier1"

CAP="${1:-}"
if [[ -z "$CAP" ]]; then
  CAP="$(find "$BASE" -maxdepth 1 -type d -name '*-keyboard-static-map' | sort | tail -1)"
fi

[[ -n "$CAP" && -d "$CAP" ]] || {
  echo "error: no keyboard static-map capture found" >&2
  exit 1
}

echo "Keyboard static-map summary"
echo "capture=$(basename "$CAP")"

echo
echo "=== Input device identities ==="
grep -E '^(I: Bus=|N: Name=|H: Handlers=)' "$CAP/proc-input-devices.txt" |
  grep -B1 -A1 -E 'TitanKey|touchPad|ff_key|gpio_key-func|mtk-pmic-keys|gpio-keys|^I:|^H:' || true

echo
echo "=== Sysfs driver / bus / wake mapping ==="
cat "$CAP/sysfs-input-map.txt" 2>/dev/null || true

echo
echo "=== Key layout / character-map highlights ==="
grep -nEi   '^(=====|key[[:space:]]+|type[[:space:]]|map[[:space:]]|keyboard\.|fallback|FUNC1|FUNC2|AGUI_SYM|APP_SWITCH|HOME|BACK|DPAD|CAMERA|VOLUME|ENTER|SPACE)'   "$CAP/static-input-config.txt" |
  head -n 420 || true

echo
echo "=== InputReader device highlights ==="
grep -nEi -A16 -B4   'TitanKey|touchPad|ff_key|gpio_key-func|mtk-pmic-keys|gpio-keys|Sources:|KeyboardType:|IsWaking:|AssociatedDisplay'   "$CAP/dumpsys-input.txt" |
  head -n 520 || true

echo
echo "=== Vendor owner/package highlights ==="
grep -nEi   '^(=====|package:|codePath=|versionName=|versionCode=)|keyboard|shortcut|input|backlight|display|service|receiver|provider|granted=true'   "$CAP/vendor-owner-packages.txt" |
  head -n 420 || true

echo
echo "=== Relevant properties ==="
cat "$CAP/relevant-properties.txt" 2>/dev/null || true

echo
echo "=== Device-tree candidate directories ==="
cat "$CAP/device-tree-candidate-dirs.txt" 2>/dev/null | head -n 320 || true

echo
echo "=== Candidate loaded modules ==="
grep -Ei 'key|kbd|keyboard|gpio|input|touch|hall|led|backlight' "$CAP/proc-modules.txt" 2>/dev/null || true

echo
echo "Share this summary first. Keep the raw capture private."
