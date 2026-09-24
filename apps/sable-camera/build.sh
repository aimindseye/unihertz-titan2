#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/srv/data/sable-host-tools/android/r8/sdk}}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/srv/data/sable-host-tools/gradle}"

if [[ ! -r "$ANDROID_SDK_ROOT/platforms/android-36/android.jar" ]]; then
    echo "ERROR: Android API 36 SDK not found under $ANDROID_SDK_ROOT" >&2
    exit 2
fi

if [[ -n "${GRADLE_BIN:-}" ]]; then
    GRADLE="$GRADLE_BIN"
elif command -v gradle >/dev/null 2>&1; then
    GRADLE="$(command -v gradle)"
else
    GRADLE="$(find "$GRADLE_USER_HOME/wrapper/dists/gradle-8.13-bin"         -maxdepth 6 -type f -path '*/gradle-8.13/bin/gradle'         -perm -111 -print -quit 2>/dev/null || true)"
fi

if [[ -z "${GRADLE:-}" || ! -x "$GRADLE" ]]; then
    echo "ERROR: Gradle 8.13 executable not found." >&2
    exit 3
fi

cd "$ROOT"
exec "$GRADLE" --offline --no-daemon :app:assembleDebug
