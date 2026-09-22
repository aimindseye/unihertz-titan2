# US OTA Capture

## Question

Does the US Titan 2 stock updater obtain firmware/OTA material through the same Google Drive-backed workflow documented for EEA/Worldwide devices, or does the US channel use a different endpoint or delivery path?

Do not assume the answer from another region.

## First-pass capture

On the Mac with Android platform tools installed:

```bash
adb devices -l
./tools/t2-r0-collect.sh snapshot
./tools/t2-r0-collect.sh ota-watch
```

While `ota-watch` is running, use the phone UI:

```text
Settings -> About phone -> System Update
```

Trigger a check and, if offered, allow the updater to reach the download/discovery stage. Stop the terminal capture with Ctrl-C.

The script stores:

- `ota-logcat.txt`: raw logcat stream;
- `ota-candidates.txt`: lines matching URL/update/download/OTA-related terms;
- `SHA256SUMS`: hashes of the local capture.

All are under `artifacts/private/<timestamp>/` and are ignored by Git.

## What to extract

Record only reviewed evidence in the repository:

- updater package/process name;
- build/channel identifier;
- metadata/check endpoint hostname;
- download hostname;
- URL/path pattern with device-specific tokens removed;
- OTA filename/version;
- timestamps that correlate request -> response -> download;
- whether a Google Drive/Google-hosted URL is actually observed.

Do **not** commit bearer tokens, signed query strings, cookies, account identifiers, IMEI/serial values, or raw logcat.

## If logcat does not expose the URL

Stop and preserve the negative result. Do not jump immediately to bootloader unlock or root.

A later R0/R1 step can choose a more targeted observation method (for example a carefully reviewed Android bugreport or isolated network capture), but those artifacts can contain substantially more private data and should remain local by default.

## Acceptance criterion

This task closes when we can document, from the US handset itself, either:

1. the updater's metadata/download path sufficiently to retrieve the matching stock OTA reproducibly, or
2. a clear negative result showing that ordinary ADB/logcat observation is insufficient, with the updater package/process identified for the next bounded test.
