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

## Stock V01.00.13 result

Normal-app validation on Titan 2 proved:

```text
CameraManager.getCameraIdList() -> ["0", "1"]

camera 0:
  open -> success
  LEVEL_3
  RAW -> up to 4096x3072
  JPEG -> includes 8192x6144

camera 1:
  open -> success
  FULL
  no RAW capability
  JPEG -> includes 6560x4928

camera 2/3:
  not returned to the ordinary app
```

The normal-app visibility boundary is therefore closed: the telephoto and logical main+tele cameras remain hidden behind `SYSTEM_CAMERA`.

An important additional result is that the ~50 MP rear and ~32 MP front still sizes are exposed to an ordinary app through the standard JPEG stream map even though the standard ultra-high-resolution capability was not observed.

Device validation now proves those maximum JPEG modes capture successfully from the ordinary app:

```text
camera 0 3264x2448 -> PASS
camera 0 8192x6144 -> PASS

camera 1 3264x2448 -> PASS
camera 1 6560x4928 -> PASS
```

Host-side inspection confirmed the encoded JPEG dimensions match the requested sizes.

This proves usable ordinary-app high-resolution JPEG paths. It does not prove rear 50 MP RAW, front RAW, or whether the high-resolution JPEGs are sensor-native remosaic versus vendor super-resolution processing.

A later privileged/system SableOS build can reuse the same reporting/capture core to test the system-camera path.


## JPEG capture test

After the metadata probe, the current branch also provides **Run JPEG capture tests**.

The test selects, for each camera visible to the ordinary app:

- a large conventional 4:3 JPEG size at or below 4096×3072 when available;
- the largest advertised JPEG size.

On the validated Titan 2 metadata this is intended to exercise the ordinary still path plus the advertised high-resolution JPEG paths, including rear `8192×6144` and front `6560×4928`.

The capture test records requested size, success/failure, byte count and elapsed time. JPEG outputs are stored privately beneath the app-specific `camera-probe/captures` directory.

Metadata advertisement is not treated as capture proof until this test succeeds on-device.


## Current next tests

The metadata and JPEG-availability questions are now closed for the normal stock-app path.

Next useful work:

- rear RAW capture at 4096x3072;
- review the ordinary-app-visible AGOLD/MediaTek vendor characteristics;
- identify request/result vendor controls that can be used without privilege;
- compare conventional vs maximum JPEG image detail before deciding how Sable Camera should label the high-resolution modes.

Telephoto/logical IDs 2 and 3 remain a later privileged/system-camera integration target.


## Vendor-key boundary

The ordinary stock app currently sees 35 rear and 30 front non-`android.*` characteristics, all MediaTek-prefixed in the observed report. The AGOLD `superResolution` characteristic visible from lower-level CameraService/HAL diagnostics is not present in the ordinary app's `CameraCharacteristics` key list.

The probe now also inventories non-`android.*` CaptureRequest, CaptureResult, session and physical-request key names. This distinguishes "feature advertised by a characteristic" from "control/result actually exposed to an ordinary app."

## RAW DNG test

The current branch adds **Run RAW DNG capture test**.

It exercises only ordinary-app-visible cameras that advertise both the standard RAW capability and a `RAW_SENSOR` output size. On the current Titan 2 metadata this is expected to exercise rear camera `0` at its largest advertised RAW size and skip the front camera.

The test writes a DNG using Android's `DngCreator` plus the real `TotalCaptureResult`, then records success/failure, output byte count and end-to-end elapsed time.
