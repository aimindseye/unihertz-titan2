# Titan 2 Camera Research and Sable Camera Plan

**Status:** stock-camera characterization complete enough to begin app work  
**Stock baseline:** Android 16 `V01.00.13`  
**Method:** read-only CameraService / Camera2 / HAL inspection plus stock-camera live-session observation

This work is separate from the deferred SableOS operating-system bring-up. The goal is to understand the Titan 2 camera stack now and use that knowledge to design a reusable camera application for physical-keyboard devices.

Raw dumps remain private on `ai-g732`; this document records only redacted, reproducible findings.

## Camera topology

CameraService reports:

```text
Number of camera devices: 4
Number of normal camera devices: 2
Number of public camera devices visible to API1: 2
```

The observed Camera2 topology is:

| ID | Role | Visibility | Important characteristics |
| --- | --- | --- | --- |
| `0` | rear main | normal/public | 4096×3072 active array, 5.59 mm, f/1.8, RAW, manual sensor/post-processing, Camera2 LEVEL_3 |
| `1` | front | normal/public | 3280×2464 active array, 3.81 mm, f/2.0, fixed-focus metadata, Camera2 FULL, no RAW capability |
| `2` | rear telephoto physical camera | `SYSTEM_CAMERA` | 3264×2448 active array, 7.48 mm, f/2.4, RAW, manual sensor/post-processing, Camera2 LEVEL_3 |
| `3` | rear logical main+tele camera | `SYSTEM_CAMERA` + `LOGICAL_MULTI_CAMERA` | physical IDs `0` and `2`, 1–20× logical zoom range, approximate sensor sync |

The important distinction is that cameras `2` and `3` exist in the camera provider and are fully described by Camera2 metadata, but are not part of the normal/public camera set.

## Rear main camera

Observed standard metadata for camera `0`:

```text
facing: back
orientation: 90
flash: yes

pixel/active array: 4096 × 3072
sensor physical size: 8.192 × 6.144 mm
focal length: 5.59 mm
aperture: f/1.8
minimum focus distance: 20.0 diopters
color filter: RGGB
ISO range: 100–19200
exposure-time range: 100 µs – 400 ms
zoom range: 1× – 10×
```

Capabilities include:

```text
BACKWARD_COMPATIBLE
MANUAL_SENSOR
MANUAL_POST_PROCESSING
READ_SENSOR_SETTINGS
RAW
BURST_CAPTURE
YUV_REPROCESSING
STREAM_USE_CASE
COLOR_SPACE_PROFILES
```

The AGOLD vendor tag `com.agold.feature.superResolution` advertises:

```text
8192 × 6144
```

which is approximately 50.3 MP. Android's standard maximum-resolution / ultra-high-resolution metadata was not found in the inspected dump, so this should be treated as a vendor-defined capture path rather than standard `ULTRA_HIGH_RESOLUTION_SENSOR` exposure.

MediaTek vendor metadata also advertises 1920×1080 at 60 fps for high-frame-rate operation and an EIS-compatible 1080p60 limit.

## Front camera

Observed standard metadata for camera `1`:

```text
facing: front
orientation: 270
flash: no

pixel/active array: 3280 × 2464
sensor physical size: 5.25 × 3.94 mm
focal length: 3.81 mm
aperture: f/2.0
minimum focus distance: 0.0
color filter: GBRG
ISO range: 100–4000
zoom range: 1× – 4×
```

The front camera advertises manual sensor/post-processing and reprocessing support but does **not** advertise the standard RAW capability.

AGOLD's `superResolution` tag advertises:

```text
6560 × 4928
```

which is approximately 32.3 MP.

## Rear telephoto camera

Camera `2` is a real rear physical camera hidden behind `SYSTEM_CAMERA`.

Observed metadata:

```text
facing: back
orientation: 90
flash: yes

pixel/active array: 3264 × 2448
sensor physical size: 3.28 × 2.46 mm
focal length: 7.48 mm
aperture: f/2.4
minimum focus distance: 20.0 diopters
color filter: GRBG
ISO range: 100–1000
camera-local zoom range: 1× – 20×
```

It advertises RAW, manual sensor control, manual post-processing, sensor readback, burst capture and YUV reprocessing.

This differs from the Titan 2 Elite community telephoto investigation, where the hidden telephoto used by that project was reported not to provide the RAW stream expected by the chosen GCam photo pipeline. Do not transfer Elite sensor/HAL assumptions to Titan 2.

## Logical rear camera

Camera `3` is the vendor's intended combined rear-camera abstraction:

```text
SYSTEM_CAMERA
LOGICAL_MULTI_CAMERA
physical IDs: [0, 2]
sensor sync: APPROXIMATE
zoom range: 1× – 20×
```

MediaTek's multi-camera vendor metadata exposes controls/results for:

- master physical ID;
- active physical ID;
- active streaming IDs;
- multi-camera zoom value;
- zoom-step configuration;
- per-sensor crop regions;
- capture count;
- AF/AE/AWB multi-camera state;
- multi-camera stream-size pairing.

The advertised zoom steps are:

```text
[1.0, 3.4]
```

The paired main/tele stream sizes include:

```text
4096×3072  <->  3264×2448
3840×2160  <->  3072×1728
3504×3504  <->  2448×2448
```

The approximately 3.4× handoff is also consistent with the relative fields of view derived from the reported sensor dimensions and focal lengths.

## Stock-camera live behavior

The stock camera application resolves to:

```text
com.mediatek.camera/.CameraActivity
```

It does **not** open public camera `0` directly for the normal rear-camera UI. CameraService shows the stock app opening logical camera `3`, with cameras `0` and `2` treated as its conflicting physical devices.

At approximately 1×:

```text
logical camera:       3
zoomRatio:            1.00000000
activePhysicalId:     "0"
multiCamMasterId:     0
```

At a captured zoom value of approximately 4.631×:

```text
logical camera:       3
zoomRatio:            4.63100481
activePhysicalId:     "2"
multiCamMasterId:     2
```

The `activePhysicalId` values were emitted as null-terminated bytes:

```text
[48 0] -> "0"
[50 0] -> "2"
```

This directly proves that the stock MediaTek camera uses logical camera `3` and changes the active/master physical camera from the main sensor to the telephoto at higher zoom.

The HAL advertises the optical step at 3.4×. The exact switching hysteresis around 3.4× has not been measured and is not currently a blocker.

## What this means for a custom camera

There are two distinct deployment targets.

### Normal APK on stock firmware

A normal third-party camera should be designed to work with the public camera set first:

```text
0 = rear main
1 = front
```

The exact result from `CameraManager.getCameraIdList()` in a third-party process should still be verified with a probe APK rather than assumed from CameraService.

### Privileged/system build on SableOS

The more interesting SableOS target is a privileged/system camera application that can request access to `SYSTEM_CAMERA` devices.

The desired rear path is logical camera `3`, not manual camera-close/camera-open switching:

```text
logical camera 3
  -> physical 0 main
  -> physical 2 tele
  -> vendor-coordinated zoom/crop/3A pipeline
```

Direct camera `2` access should remain available as a useful explicit tele/manual mode, especially because Titan 2 exposes RAW on that physical camera.

Whether SableOS can expose IDs `2` and `3` cleanly through the standard privileged-camera permission path must be proven during the OS integration phase. It should not be assumed solely from stock-firmware CameraService behavior.

## Sable Camera design direction

The camera application should be reusable across Titan-family and other physical-keyboard devices rather than hard-coded around one handset.

Proposed layers:

```text
camera-core/
  Camera2 session lifecycle
  still/video capture
  AF/AE/AWB
  RAW/YUV/JPEG handling
  stream selection

camera-capabilities/
  standard Camera2 dump
  physical/logical topology
  stream maps
  vendor-tag discovery
  JSON export

device-profiles/
  generic
  titan2
  titan2elite
  q27 (later, when retail/current OTA evidence exists)

ui/
  aspect-ratio-safe viewfinder
  square / near-square display handling
  cutout and rounded-corner awareness
  keyboard-first controls

platform-integration/
  normal app backend
  optional privileged SableOS backend
  device-specific vendor features only where proven
```

Core design rule:

> Keep **sensor capability**, **HAL capability**, **app-visible capability**, and **OS privilege** as separate facts.

The Titan 2 and Titan 2 Elite investigations show why those layers cannot be collapsed into a single "camera supports X" statement.

## Immediate next step: Camera Probe

Before building the full camera UI, create a small reusable Camera2 probe APK.

Required first version:

1. enumerate `CameraManager.getCameraIdList()`;
2. dump standard `CameraCharacteristics`;
3. record `physicalCameraIds`;
4. dump stream configuration maps;
5. enumerate vendor-tag names/values that are accessible to the process;
6. attempt to open every returned camera;
7. optionally capture one preview frame/JPEG;
8. export a normalized JSON report.

The same probe should later be run as:

- a normal APK on stock Titan 2;
- a privileged/system APK on SableOS;
- the equivalent normal/privileged builds on Titan 2 Elite;
- Q27 only after current/retail firmware evidence is available.

This makes the probe code directly reusable by Sable Camera rather than disposable research code.

## Cross-device lessons from Titan 2 Elite community work

The community GCam work for Titan 2 Elite is useful as a UI and compatibility warning, not as direct proof of Titan 2 behavior.

Reported near-square-screen issues included:

- top controls collapsing or disappearing;
- cutout overlap;
- tap-to-focus coordinate offsets;
- preview resolution being too low;
- mode UI failures caused by assumptions about normal phone aspect ratios;
- stabilization behavior that could smear motion;
- color-processing defaults that did not suit the device.

The separate Titan 2 Elite Telephoto Fix documents another recurring pattern: four camera IDs with hidden `SYSTEM_CAMERA` devices and a logical multi-camera path. Its stock-firmware solution uses a firmware-specific runtime `cameraserver` patch plus GCam-specific hooks. That implementation is a valuable reverse-engineering reference, but SableOS should prefer normal platform privilege and Camera2 logical-camera support if possible.

## Q27 scope

Q27 camera/keyboard work is deliberately deferred.

Prototype OTA and component information may be useful later, but conclusions from prototype firmware must not be presented as retail-device behavior. Wait for newer/current OTA releases and, ideally, shipping hardware before creating a Q27 device profile.

## Private evidence

Raw CameraService dumps, logs, app-private diagnostics and future probe exports stay under the private Titan 2 artifact area on `ai-g732` until reviewed/redacted.

Do not commit device serials, private logs or unreviewed vendor diagnostics.
