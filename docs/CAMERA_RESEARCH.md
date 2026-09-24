# Titan 2 Camera Research and Sable Camera Plan

**Status:** stock-camera characterization complete enough to begin app work  
**Stock baseline:** Android 16 `V01.00.13`  
**Method:** read-only CameraService / Camera2 / HAL inspection plus stock-camera live-session observation

This work is separate from the deferred SableOS operating-system bring-up. The goal is to understand the Titan 2 camera stack now and use that knowledge to design a reusable camera application for physical-keyboard devices.

Raw dumps remain private on `ai-g732`; this document records only redacted, reproducible findings.

For a consolidated comparison of what is achievable as a normal APK, with rooted stock firmware, and later as a privileged SableOS system app — including how those paths relate to GCam-style functionality and image quality — see [Sable Camera: No-Root, Rooted-Stock, and SableOS Capability Roadmap](CAMERA_ROOT_VS_NO_ROOT.md).

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

which is approximately 50.3 MP.

A normal third-party Camera2 probe subsequently showed that `8192×6144` is also advertised through the ordinary `SCALER_STREAM_CONFIGURATION_MAP` as a JPEG output size. The same app sees RAW only up to `4096×3072`.

No standard `ULTRA_HIGH_RESOLUTION_SENSOR` capability / maximum-resolution metadata was observed. The best current description is therefore:

```text
ordinary app-visible JPEG still path: 8192×6144
ordinary app-visible RAW path:        4096×3072
standard ultra-high-resolution API:   not advertised
AGOLD superResolution tag:            8192×6144
```

This is stronger than the earlier conclusion that the ~50 MP mode was only a vendor-hidden path. Actual third-party capture has now been proven at `8192×6144`: the probe wrote a valid JPEG of 12,881,437 bytes, and host-side inspection confirmed the encoded dimensions are 8192×6144. The probe's end-to-end test took 538 ms including camera open, session creation, capture and file write.

This proves an ordinary app-visible ~50.3 MP JPEG path. It does **not** prove 50 MP RAW or establish whether the JPEG is sensor-native remosaic versus vendor super-resolution processing.

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

The normal third-party Camera2 probe also sees `6560×4928` in the standard JPEG output stream map. The front camera still does not advertise RAW, and its ordinary YUV output sizes top out below that full-resolution JPEG path. Successful third-party capture has now been proven at `6560×4928`: the probe wrote a valid JPEG of 7,399,576 bytes, and host-side inspection confirmed the encoded dimensions are 6560×4928. The end-to-end test took 507 ms including camera open, session creation, capture and file write.

This proves an ordinary app-visible ~32.3 MP front JPEG path, but it still does not establish the exact sensor/processing mode used to generate that JPEG.

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

This is now experimentally verified with the Camera Probe APK on stock `V01.00.13`:

```text
CameraManager.getCameraIdList() -> ["0", "1"]

camera 0:
  open -> success
  LEVEL_3
  RAW advertised
  RAW_SENSOR -> up to 4096×3072
  JPEG -> includes 8192×6144
  accessible vendor characteristics -> 35

camera 1:
  open -> success
  FULL
  RAW not advertised
  JPEG -> includes 6560×4928
  accessible vendor characteristics -> 30

camera 2 -> not returned to the ordinary app
camera 3 -> not returned to the ordinary app
```

This closes the normal-app visibility question: stock third-party applications get public IDs `0` and `1`, while the telephoto physical camera and logical main+tele camera remain hidden behind the system-camera boundary.

It also shows that the normal stock-app backend can expose the vendor high-resolution still paths as ordinary JPEG stream sizes even though the standard ultra-high-resolution capability is not advertised.

### Vendor characteristics visible to an ordinary app

The normal APK sees 35 non-`android.*` characteristics on camera `0` and 30 on camera `1`. In this app-visible characteristic list, all observed keys are MediaTek-prefixed; the AGOLD `superResolution` characteristic seen from CameraService/HAL diagnostics is **not** exposed as a normal-app `CameraCharacteristics` key.

This is an important API boundary: Sable Camera must discover the working high-resolution JPEG path from the standard stream map rather than depending on the AGOLD characteristic.

Rear camera `0` exposes vendor capability metadata for:

- ZSL availability/default;
- postview and early-notification support;
- continuous-shot modes;
- photo/video/VHDR mode enumerants;
- MFNR/AI-multiframe mode enumerants;
- 3D noise reduction;
- high-frame-rate support with a reported 1920×1080@60 maximum;
- high-frame-rate EIS with the same 1920×1080@60 maximum;
- in-sensor-zoom support metadata associated with physical ID `0`;
- preview compression;
- AOV/background-service pipeline capability metadata;
- HDR10+ EIS/VSS support flags;
- video AI noise-reduction mode enumerants.

Front camera `1` exposes a largely overlapping subset, but its vendor characteristics do not advertise the rear camera's HFR mode/max-resolution entries, in-sensor-zoom physical-ID entry, rear continuous-shot mode `1`, or flash-calibration availability.

The integer vendor-mode values are recorded as raw enumerants. Their semantic names must not be guessed without either MediaTek source/header evidence or controlled request/result experiments.

The `com.mediatek.control.capture.ispMetaSizeForRaw` and `...ispMetaSizeForYuv` values are vendor metadata dimensions and must not be interpreted as sensor/output stream resolutions.

The probe should next inventory ordinary-app-visible **CaptureRequest**, **CaptureResult**, session and physical-request vendor keys. A characteristic saying a feature exists does not prove a normal app can set its request control or observe its result state.

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

## Camera Probe status and next test

Camera Probe v0.1 is now built and device-tested as a normal APK on stock Titan 2.

Completed:

1. enumerate `CameraManager.getCameraIdList()`;
2. dump standard `CameraCharacteristics`;
3. record `physicalCameraIds`;
4. dump stream configuration maps;
5. enumerate accessible vendor characteristics;
6. open every returned camera;
7. export normalized JSON.

Validated result:

```text
visible IDs = [0, 1]
0 open = PASS
1 open = PASS
2/3 absent from ordinary app enumeration
```

JPEG still-capture validation is now complete for the ordinary app:

```text
camera 0 conventional 3264×2448 -> PASS, 3,059,514 bytes, 444 ms
camera 0 maximum      8192×6144 -> PASS, 12,881,437 bytes, 538 ms

camera 1 conventional 3264×2448 -> PASS, 2,662,063 bytes, 451 ms
camera 1 maximum      6560×4928 -> PASS, 7,399,576 bytes, 507 ms
```

Host-side inspection confirmed all four JPEG files encode the requested dimensions.

The timings above are probe end-to-end timings and include camera open, session setup, capture and file write. They are not pure shutter/exposure latency.

Rear RAW capture is now proven from the ordinary app:

```text
camera 0 RAW_SENSOR 4096×3072 -> PASS
DNG size: 25,196,844 bytes
probe end-to-end time: 472 ms

camera 1 -> skipped; RAW capability/stream unavailable
```

Host-side inspection identifies the file as TIFF/DNG-style image data at 4096×3072 with Titan 2 camera metadata. This closes the ordinary-app rear RAW path: standard Camera2 `RAW_SENSOR` + `DngCreator` works without privilege.

The refreshed vendor-key inventory also shows that the normal app can see a much larger request/result surface than the characteristics alone suggested. Notable request/session keys include:

- `com.agold.feature.operationMode`;
- MediaTek ZSL controls;
- MediaTek HDR session/request controls;
- MFNR/MFB and 3DNR controls;
- EIS controls;
- rear HFR control;
- in-sensor-zoom hints/status;
- RAW-processing controls including packed RAW, RAW BPP, raw10 conversion, processRaw, `remosaicenable`, and `seamless.remosaicenable`.

Several matching result keys are visible for HDR, MFNR, ZSL, in-sensor zoom, 3A metrics and other features.

No vendor physical-request keys are exposed on either public camera.

A key practical result is that the proven `8192×6144` rear JPEG and `6560×4928` front JPEG captures required no proprietary request tag. The baseline high-resolution still path should therefore be implemented from the standard stream map first, with vendor controls treated as optional enhancements only after controlled testing.

The next useful tests are:

1. inspect DNG metadata/CFA/black-white level/color matrices;
2. compare conventional versus maximum JPEG detail to determine whether the high-resolution modes add real scene detail versus interpolation/vendor super-resolution;
3. identify safe request values for selected vendor controls from stock-camera traces or MediaTek definitions before attempting to set them;
4. start extracting the reusable normal-app camera backend from the probe;
5. keep telephoto/logical-camera privilege work deferred to the SableOS system-app phase.

The same reporting/capture core should later run as a privileged/system APK on SableOS and then on Titan 2 Elite. Q27 remains deferred until current/retail firmware evidence is available.

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
