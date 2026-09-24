#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APK="$ROOT/app/build/outputs/apk/debug/app-debug.apk"

: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 adb serial}"

MODEL="$(adb -s "$TITAN_SERIAL" shell getprop ro.product.model | tr -d '\r')"
if [[ "$MODEL" != "Titan 2" ]]; then
    echo "ERROR: target reports '$MODEL', expected 'Titan 2'." >&2
    exit 3
fi

adb -s "$TITAN_SERIAL" install -r "$APK"
adb -s "$TITAN_SERIAL" shell am start -n org.sableos.camera/.MainActivity
