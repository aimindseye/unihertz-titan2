#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-/srv/data/sable-host-tools/android/r8/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

GRADLE="${GRADLE:-/srv/data/sable-host-tools/gradle/bin/gradle}"

cd "$ROOT"
exec nice -n 15 ionice -c2 -n7 "$GRADLE" --no-daemon :app:assembleDebug
