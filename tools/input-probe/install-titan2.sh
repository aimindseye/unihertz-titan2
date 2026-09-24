#!/usr/bin/env bash
set -euo pipefail

: "${TITAN_SERIAL:?Set TITAN_SERIAL explicitly}"

ADB=(adb -s "$TITAN_SERIAL")
MODEL="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
[[ "$MODEL" == "Titan 2" ]] || {
  echo "error: selected device reports '$MODEL', expected Titan 2" >&2
  exit 1
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="$ROOT/app/build/outputs/apk/debug/app-debug.apk"

[[ -f "$APK" ]] || {
  echo "error: APK not found: $APK" >&2
  echo "Run ./build.sh first." >&2
  exit 1
}

"${ADB[@]}" install -r "$APK"
"${ADB[@]}" shell am force-stop org.sableos.research.inputprobe
"${ADB[@]}" shell monkey -p org.sableos.research.inputprobe 1 >/dev/null
