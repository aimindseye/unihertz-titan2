#!/usr/bin/env bash
set -euo pipefail

: "${TITAN_SERIAL:?Set TITAN_SERIAL to the Titan 2 adb serial}"

DEST="${1:-./probe-output}"
mkdir -p "$DEST"

MODEL="$(adb -s "$TITAN_SERIAL" shell getprop ro.product.model | tr -d '\r')"
if [[ "$MODEL" != "Titan 2" ]]; then
    echo "ERROR: target serial reports model '$MODEL', expected 'Titan 2'." >&2
    exit 3
fi

REMOTE="/sdcard/Android/data/org.sableos.research.cameraprobe/files/camera-probe/camera-probe-latest.json"
adb -s "$TITAN_SERIAL" pull "$REMOTE" "$DEST/"
sha256sum "$DEST/camera-probe-latest.json"
