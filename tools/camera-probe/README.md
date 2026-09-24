# Titan 2 Camera Probe

Small normal-application Camera2 probe for issue #4.

This is intentionally **not** the final Sable Camera UI. It establishes what a normal third-party process can enumerate, inspect and open on stock Titan 2 firmware.

## Current scope

The probe:

- requests only the normal `CAMERA` runtime permission;
- records build identity without device serial/IMEI;
- enumerates `CameraManager.getCameraIdList()`;
- records standard Camera2 characteristics;
- records logical physical-camera IDs visible to the process;
- records output/input stream formats and sizes;
- records accessible non-`android.*` vendor characteristics;
- attempts to open every camera returned to the app;
- writes a normalized JSON report to app-specific external storage.

It does not request `SYSTEM_CAMERA` and does not attempt privilege bypasses.

## ai-g732 build environment

The SableOS canonical host toolchain already provides:

```text
SDK=/srv/data/sable-host-tools/android/r8/sdk
API=36
build-tools=36.0.0
Gradle user home=/srv/data/sable-host-tools/gradle
```

Build after other heavy Android builds have finished:

```bash
cd tools/camera-probe
./build.sh
```

The build is offline by default and reuses the canonical Sable Gradle cache.

## Install only on Titan 2

Always use an explicit serial when Pixel 7 is attached too:

```bash
export TITAN_SERIAL=<titan-serial>
./install-titan2.sh
```

The install helper verifies that the selected device reports model `Titan 2` before installing.

## Run

Open **Camera Probe**, grant Camera permission, then choose **Run probe**.

The result is written to:

```text
/sdcard/Android/data/org.sableos.research.cameraprobe/files/camera-probe/
```

Pull the latest report:

```bash
export TITAN_SERIAL=<titan-serial>
./pull-latest.sh
```

Treat the JSON as private/raw evidence until reviewed. Do not commit raw probe output directly.

## Expected stock hypothesis

CameraService already proves four registered cameras but only two normal cameras. The normal APK is therefore expected to enumerate cameras `0` and `1`, while hidden `SYSTEM_CAMERA` IDs `2` and `3` are expected to remain absent.

This probe exists to test that expectation from an ordinary application process rather than treating it as proven in advance.

A later privileged/system SableOS build can reuse the same reporting core to test the system-camera path.
