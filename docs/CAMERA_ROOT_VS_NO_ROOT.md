# Sable Camera: No-Root, Rooted-Stock, and SableOS Capability Roadmap

**Purpose:** preserve the current engineering view of how far Sable Camera can go on Titan 2 under three deployment models:

1. a normal third-party APK on stock firmware;
2. a rooted stock-firmware environment;
3. a future privileged/system build under SableOS.

This document separates **proven Titan 2 behavior** from **root/SableOS hypotheses** and from **computational-photography goals**.

## Evidence labels

Use these terms consistently:

- **PROVEN** — reproduced directly on Titan 2 stock `V01.00.13`.
- **SUPPORTED BY METADATA** — Camera2/HAL advertises the capability, but the complete feature path may not yet be exercised.
- **COMMUNITY REFERENCE** — demonstrated on related hardware/firmware, especially Titan 2 Elite; useful as a lead, not Titan 2 proof.
- **HYPOTHESIS / FUTURE TARGET** — reasonable design direction that still requires Titan 2 validation.

## Current Titan 2 baseline

The stock camera provider exposes four devices internally:

```text
0 = rear main, public
1 = front, public
2 = rear telephoto, SYSTEM_CAMERA
3 = logical rear main+tele, SYSTEM_CAMERA + LOGICAL_MULTI_CAMERA
```

A normal third-party APK sees only cameras `0` and `1`.

The current Sable Camera MVP has already proven on stock firmware:

```text
rear camera 0
  preview/orientation                         PROVEN
  tap-to-focus / AE metering                  PROVEN
  conventional JPEG                           PROVEN
  8192x6144 JPEG (~50.3 MP)                   PROVEN
  4096x3072 RAW_SENSOR -> DNG                  PROVEN
  hardware-key shutter                        PROVEN

front camera 1
  preview/orientation                         PROVEN
  mirrored front preview                      PROVEN
  conventional JPEG                           PROVEN
  6560x4928 JPEG (~32.3 MP)                   PROVEN
  RAW                                         not advertised
```

The high-resolution JPEG paths require no proprietary request tag in the validated baseline. They are selectable from the standard Camera2 stream map.

## Capability matrix

| Capability | Normal app on stock | Rooted stock firmware | Future SableOS system app |
| --- | --- | --- | --- |
| Rear main camera `0` | **PROVEN** | Expected | Expected |
| Front camera `1` | **PROVEN** | Expected | Expected |
| Rear 8192×6144 JPEG | **PROVEN** | Expected | Expected |
| Front 6560×4928 JPEG | **PROVEN** | Expected | Expected |
| Rear 4096×3072 RAW/DNG | **PROVEN** | Expected | Expected |
| Manual rear ISO/shutter/focus | Supported by Camera2 metadata; UI work pending | Expected | Expected |
| Tap focus / AE metering | **PROVEN** | Expected | Expected |
| Physical-key shutter | **PROVEN** | Expected | Expected |
| Public-camera digital zoom | Supported by metadata; app UI work pending | Expected | Expected |
| True telephoto camera `2` | **Blocked by SYSTEM_CAMERA** | **Hypothesis:** may be unlockable with root/camera-service work | **Target:** privileged access |
| Logical rear camera `3` | **Blocked by SYSTEM_CAMERA** | **Hypothesis:** may be unlockable with root/camera-service work | **Target:** privileged access |
| Vendor 1× → ~3.4× optical handoff | Not available to normal app because camera `3` is hidden | Hypothesis via camera `3` | Target via camera `3` |
| ZSL / HDR / MFNR / 3DNR | Vendor controls are visible; semantics/testing pending | More freedom to experiment | Can be integrated intentionally |
| Rear HFR / 1080p60 | Supported by metadata; implementation/testing pending | Expected if stock HAL accepts session | Expected |
| EIS | Supported by metadata; implementation/testing pending | Expected if stock HAL accepts session | Expected |
| GCam port with hidden tele | Not possible while IDs `2/3` remain hidden | Potential research route | Usually unnecessary if Sable Camera owns privileged path |
| Firmware-specific `cameraserver` RAM patch | Not possible | Possible research technique; fragile across OTAs | Should be avoided if platform privilege is sufficient |

"Expected" in this table does not mean already tested on Titan 2. Rooted-stock and SableOS paths remain separate future validation work.

## How far can Sable Camera go without root?

For the public rear and front cameras, root is **not** the main limitation.

Camera `0` already provides a strong standard Camera2 foundation:

```text
LEVEL_3
RAW
MANUAL_SENSOR
MANUAL_POST_PROCESSING
READ_SENSOR_SETTINGS
BURST_CAPTURE
YUV_REPROCESSING
ISO 100–19200
exposure 100 us – 400 ms
autofocus
flash
digital zoom metadata
```

Camera `1` is Camera2 FULL, supports manual/post-processing features and high-resolution JPEG, but does not expose RAW.

A normal app can therefore implement, without root:

- rear/front preview and still capture;
- rear RAW/DNG;
- high-resolution JPEG modes;
- manual ISO, exposure time and focus where supported;
- exposure compensation;
- flash control;
- digital zoom;
- focus lock and focus-state UI;
- timer, grid and gallery handoff;
- burst capture;
- video;
- capability-driven high-frame-rate modes if stream combinations validate;
- stabilization where standard/vendor session configuration validates;
- keyboard-first shutter/zoom/EV/navigation controls;
- application-level computational photography built from YUV/RAW frames.

The main no-root hardware limitation is access to the hidden telephoto/logical cameras:

```text
camera 2 = hidden telephoto
camera 3 = hidden logical main+tele
```

That means a no-root Sable Camera can become a highly capable **main/front** camera, but cannot use the actual optical telephoto while stock firmware enforces the system-camera boundary.

## Vendor features available to a normal app

The normal APK sees a substantial MediaTek vendor surface.

Observed characteristic/request/result areas include:

- ZSL;
- photo/video HDR modes;
- VHDR;
- MFNR/MFB / AI multiframe modes;
- 3D noise reduction;
- rear high-frame-rate mode metadata;
- EIS-related controls;
- in-sensor-zoom hints/status;
- RAW-processing controls;
- packed RAW / RAW BPP controls;
- `processRaw`;
- `remosaicenable`;
- `seamless.remosaicenable`;
- video AI noise reduction;
- AGOLD `operationMode` as a request/session key.

These keys are **not yet permission to guess values**.

Before Sable Camera sets a proprietary vendor request, establish:

1. value type;
2. valid enum/range;
3. stock-camera behavior or source/header meaning;
4. one-variable controlled test;
5. fallback behavior if the HAL rejects the request.

The validated high-resolution JPEG path should remain independent of these vendor controls because it already works through the standard stream map.

## Rooted stock firmware: what root actually changes

Root primarily changes **access and experimentation**, not image-processing quality by itself.

The Titan 2 Elite Telephoto Fix is the closest community reference. On that device/firmware:

- cameras `2/3` were marked `SYSTEM_CAMERA`;
- simply installing an app as privileged was not sufficient;
- Unihertz/AGUI added camera-service enforcement beyond the ordinary Android permission path;
- the working solution patched the running `cameraserver` process from a Magisk module;
- the patch uses firmware-specific offsets and therefore can break after an OTA.

That is **Titan 2 Elite evidence**, not proof that Titan 2 stock firmware will require the exact same patch.

For Titan 2, a rooted-stock research phase could investigate:

```text
root/Magisk
  -> inspect current cameraserver enforcement
  -> determine whether normal SYSTEM_CAMERA permission is still blocked
  -> derive Titan-2-specific unlock only if necessary
  -> test camera 2 directly
  -> test logical camera 3
  -> test stock-HAL main/tele switching
  -> optionally test a GCam port against unlocked IDs
```

A rooted runtime patch should be treated as a **research/compatibility mechanism**, not the preferred long-term architecture.

### Why Titan 2 may be more favorable than the Titan 2 Elite example

The Elite community project reports its telephoto path as Camera2 FULL without RAW.

Titan 2 camera `2` instead advertises:

```text
LEVEL_3
RAW
MANUAL_SENSOR
MANUAL_POST_PROCESSING
READ_SENSOR_SETTINGS
BURST_CAPTURE
YUV_REPROCESSING
```

That is a meaningful difference.

**HYPOTHESIS:** if a suitable GCam port can access Titan 2 camera `2` or logical camera `3`, Titan 2's RAW-capable telephoto may fit a higher-quality still pipeline more naturally than the Elite telephoto documented by that project.

This has not been tested and must not be presented as a working GCam telephoto path yet.

## Future SableOS system-app path

The preferred long-term architecture is not a Magisk RAM patch.

Under SableOS, the project controls the framework/system image and can design a privileged camera integration intentionally.

Desired model:

```text
Sable Camera
  normal Camera2 backend
    -> cameras 0 / 1

  privileged SableOS backend
    -> logical camera 3
         -> physical main 0
         -> physical tele 2
         -> MediaTek coordinated zoom / crop / 3A
```

Direct camera `2` should remain available as an explicit tele/manual/RAW path where useful.

The logical camera `3` is the preferred standard rear zoom path because stock-camera live testing already proved that the MediaTek app keeps camera `3` open and changes the active/master physical camera from `0` to `2` at higher zoom.

SableOS still needs to prove that platform privilege is sufficient with the reused vendor stack. Do not assume the stock AGUI restrictions disappear until the system build is tested.

## GCam feature parity vs GCam image quality

These are different engineering problems.

### Functional parity

Most common GCam-like camera functions do not inherently require root:

- rear/front capture;
- RAW;
- manual controls;
- zoom;
- EV;
- AF/AE;
- flash;
- timer;
- grids;
- panorama;
- portrait/depth effects implemented in-app;
- video;
- HFR where the HAL supports the session;
- stabilization where the HAL supports the session;
- application-level HDR/night stacking;
- keyboard shortcuts specific to Titan hardware.

Sable Camera can also provide Titan-specific UX that a generic GCam port does not naturally provide:

- near-square-screen-native layout;
- physical-key shutter;
- physical-key zoom/EV/focus/navigation;
- device-specific stream selection;
- explicit normal/high/RAW modes;
- eventually clean main/tele integration under SableOS.

For **functionality and device ergonomics**, the project can plausibly equal or exceed a generic port for Titan-specific use.

### Computational image-quality parity

Matching GCam's difficult-scene image quality is a separate and much larger project.

GCam quality typically depends on a mature computational-photography stack such as:

- multi-frame HDR;
- frame alignment;
- motion rejection and deghosting;
- temporal noise reduction;
- multi-frame detail reconstruction/sharpening;
- auto white balance and color science;
- local tone mapping;
- highlight/shadow reconstruction;
- super-resolution techniques;
- face-aware processing;
- Night Sight-style exposure/frame selection;
- portrait segmentation and depth estimation;
- per-sensor/lens tuning.

Root does not provide these algorithms.

Sable Camera can use:

1. the MediaTek HAL's processed JPEG path;
2. MediaTek vendor features where semantics are proven;
3. RAW/YUV data for custom processing;
4. later, SableOS-specific system integration.

But the project should not promise Pixel/GCam image-quality parity until it is measured.

### Practical quality expectation

The engineering expectation should be framed this way:

```text
hardware access                    very tractable
Titan-specific UI/functionality    very tractable
daylight main-camera quality       promising; must be measured
HDR / difficult backlight          requires tuning and/or multi-frame work
low light / motion                 substantial computational work
Night Sight-like quality           substantial computational work
Google/Pixel color science         requires calibration/tuning
full GCam parity                    not guaranteed
```

This is deliberately a development expectation, not a claim that a current Sable Camera build already matches GCam.

## What root does not solve

Root does **not** automatically improve:

- HDR quality;
- low-light noise;
- Night mode;
- motion handling;
- skin tones;
- white balance;
- sharpening;
- tone mapping;
- super-resolution;
- color science.

Root primarily gives the project more control over system policy and hidden camera access.

Better photographs still require HAL tuning, vendor-feature use, or application-level computational photography.

## Recommended development order

### Stage 1 — normal app

Continue APP-CAM work without root:

```text
validated MVP
  -> controlled image-quality comparison
  -> zoom / EV / flash / focus-state UI
  -> video
  -> HFR / stabilization testing
  -> controlled ZSL/HDR/MFNR experiments
  -> RAW/YUV processing experiments
```

### Stage 2 — optional rooted-stock research

Only when useful:

```text
inspect Titan 2 system-camera enforcement
  -> test whether privileged install is sufficient
  -> if not, characterize Titan-specific AGUI/cameraserver gate
  -> temporary rooted unlock experiment
  -> camera 2 direct test
  -> camera 3 logical zoom test
  -> optional GCam-port compatibility experiment
```

Do not generalize the Titan 2 Elite patch offsets or sensor behavior to Titan 2.

### Stage 3 — SableOS integration

After the OS bring-up resumes:

```text
platform-signed Sable Camera
  -> validate SYSTEM_CAMERA access
  -> prefer logical camera 3 for normal rear zoom
  -> expose direct camera 2 only where useful
  -> remove dependence on stock-firmware runtime patches
  -> keep normal-app backend usable across devices
```

## Bottom line

Without root, Titan 2 already exposes enough Camera2 capability to build a strong main/front camera application with high-resolution JPEG, rear RAW/DNG, manual controls, video and eventually substantial computational processing.

Root's biggest potential contribution is access to the hidden telephoto/logical-camera path and deeper vendor experimentation. It does not by itself make Sable Camera look like GCam.

The long-term path to both clean optical zoom and a maintainable product is a SableOS privileged/system integration, while image-quality parity with GCam remains a separate computational-photography and tuning effort.
