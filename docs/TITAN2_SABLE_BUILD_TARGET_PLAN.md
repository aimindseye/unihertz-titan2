# Titan 2 SableOS build-target plan

Status: **ACTIVE — Titan 2 artifact does not exist yet; build-target definition precedes E3**

The existing SableOS Release 9 artifact was built for Pixel 7 / Panther. It must
not be used as the Titan 2 N0 artifact.

Titan 2 bring-up therefore splits into two tracks:

1. define and build a Titan 2-compatible Sable userspace/system target;
2. only then resume Tier 2 E3 artifact preflight and first deployment.

## Non-goals

The first Titan 2 target does not attempt to replace the stock MediaTek kernel,
vendor partition, firmware stack, modem firmware, or device calibration.

The first N0 target should preserve the stock dependency set unless a concrete
compatibility failure proves otherwise:

```text
boot
init_boot
vendor_boot
dtbo
vendor
vendor_dlkm
odm_dlkm
vbmeta_vendor
modem and other MTK firmware partitions
```

Do not copy Pixel 7 device-specific boot images, vendor files, kernel artifacts,
partition assumptions, AVB policy, or Panther overlays into Titan 2.

## Inputs already closed

Titan 2 platform contract:

```text
arch                arm64-only
Android stock base  16 / SDK 36
board first API     34
vendor API          34
VNDK                34
Treble              true
dynamic partitions  true
Virtual A/B         true
super               9 GiB
kernel              stock 6.1.145 Android-14-derived GKI stack
fastbootd           supported
fastboot boot       unsupported
DSU                 unavailable
```

Tier 1 already defines the Titan-specific keyboard, touchPad, side-key,
keyboard-light, display/SubScreen and vendor input-translation boundaries.

## First build target

The first Sable build should produce a **Titan 2 userspace/system artifact**, not
a Pixel image relabeled for Titan.

Required properties:

- ARM64-only;
- compatible with a vendor/VNDK-34 Treble vendor stack;
- no Panther-specific kernel/vendor dependency;
- no hard-coded Pixel partition sizing;
- Titan 2 product/device identity owned by a device/product configuration rather
  than copied stock properties;
- enough framework/system content to boot against the stock Titan 2
  kernel/vendor stack;
- debuggable ADB for N0;
- inclusion of the Titan 2 keyboard/display device-adapter work as it becomes
  available.

The exact packaging form remains evidence-driven:

```text
candidate A: pure system.img
candidate B: system + product + system_ext bundle
candidate C: generated super.img
```

Do not choose among them until the build output and current LP allocation are
compared.

## Build-system work required

In the SableOS source tree, create the smallest Titan 2 target that can inherit
the common Sable Release 9 framework/userspace while separating device-specific
Panther content.

Expected classes of changes:

```text
device/product definition
  -> Titan 2 product name / lunch target
  -> arm64-only target
  -> Treble/vendor-VNDK compatibility declarations

device overlay / properties
  -> near-square primary display defaults only where required
  -> no stock AGUI UI dependency
  -> no hard-coded runtime rear-display ID

input integration
  -> TitanKey keylayout/keychars or Sable-owned equivalent
  -> touchPad classification
  -> Func1 / Func2 policy
  -> keyboard-light Sable controller
  -> optional vendor-404 compatibility only if needed

secondary display integration
  -> discover rear display dynamically
  -> Titan 2 presentation/security/lifecycle policy

camera
  -> include normal Sable Camera backend for public cameras 0/1
  -> keep hidden SYSTEM_CAMERA work gated until privileged integration

diagnostics
  -> provide a Sable-owned Titan hardware diagnostics surface
  -> preserve `*#*#3377#*#*` as a compatibility entry point where technically feasible
  -> retain equivalent bounded tests for YGPS/GNSS, loudspeaker, receiver,
     Microphone1/2, vibrator/haptics, accelerometer/gravity, gyro, compass,
     touch/touchPad, display/backlight and keyboard light
  -> keep calibration, aging, RF-write or other state-changing factory actions
     disabled/deferred until ownership and safety are explicitly understood
  -> do not depend on proprietary stock Factory Test UI being present

build artifacts
  -> exact output paths
  -> SHA-256 manifest
  -> image logical sizes
  -> AVB metadata where present
```

## Factory diagnostics preservation contract

The stock Titan 2 retail build exposes Factory Test through the dialer code
`*#*#3377#*#*`. Physical testing on V01.00.13 verified the YGPS path and the
Single Test hardware surface, including dedicated microphone and haptics/audio
checks.

SableOS should retain this capability as a **Sable-owned diagnostics feature**.
The compatibility goal is:

```text
TITAN2_DIAGNOSTICS_SURFACE=REQUIRED
TITAN2_DIAGNOSTICS_DIALER_COMPAT=*#*#3377#*#* where feasible
TITAN2_DIAGNOSTICS_READ_ONLY_TESTS=REQUIRED
TITAN2_FACTORY_CALIBRATION_ACTIONS=DEFERRED_UNTIL_REVIEWED
```

N0 does not require cloning the proprietary stock application. It does require
preserving practical on-device hardware verification so keyboard-first bring-up
and later field support do not lose the diagnostics that stock firmware makes
available.

Implementation rule:

```text
FACTORY_TEST_APP_REVERSE_ENGINEERING=NOT_REQUIRED_BY_DEFAULT
SABLE_DIAGNOSTICS_IMPLEMENTATION=SABLE_OWNED
BLACK_BOX_BEHAVIORAL_EQUIVALENCE=SUFFICIENT_FOR_READ_ONLY_TESTS
SELECTIVE_STOCK_IMPLEMENTATION_STUDY=ONLY_IF_VENDOR_HOOK_REQUIRED
```

For read-only diagnostics, prefer direct Android/framework APIs, binder/HAL
interfaces already exposed to the system image, sysfs/input/service interfaces
covered by the Titan device adapter, and bounded vendor interfaces that are
already part of the preserved stock vendor contract. Reproduce the **observable
test capability**, not the proprietary Factory Test application's code or UI.

Study the stock Factory Test implementation only when a required diagnostic
cannot be reproduced through documented/inspectable platform interfaces, or
when the stock test is the only evidence of a vendor-specific command/protocol.
Even then, scope the investigation to identifying the minimal interface,
permission/service owner, request/response semantics and safety boundary needed
for a Sable-owned test.

Calibration, RF programming, aging/stress modes and other state-changing factory
operations remain out of scope for N0 and must not be inferred from the
read-only diagnostic paths.

## N0 artifact contract

The first candidate is not flashable merely because the build succeeds.

When a Titan 2 artifact exists, run:

```bash
bash tools/t2-tier2-n0-artifact-preflight.sh /absolute/path/to/system.img
```

and record:

```text
ARTIFACT_PATH=
ARTIFACT_SHA256=
ARTIFACT_FILE_BYTES=
ARTIFACT_LOGICAL_BYTES=
ARTIFACT_SPARSE=
CURRENT_SYSTEM_BYTES=
SIZE_FIT=
AVB_METADATA=
```

If the build produces a system/product/system_ext bundle or super image, extend
the preflight contract before flashing rather than forcing it through the
single-system-image helper.

## Gate status

```text
E0 restore verification      PASS
E1 bootloader preflight      PASS
E2 fastbootd / LP preflight PASS
BUILD-TARGET                 REQUIRED NOW
E3 Sable artifact preflight BLOCKED until Titan 2 artifact exists
N0 flash                     BLOCKED until E3 + reviewed AVB/LP/userdata plan
```

## Immediate next deliverable

The next actionable deliverable is **not** another device-side capture. It is a
Titan 2 product/build target in the SableOS source tree.

Once the Sable source tree or repository is identified on `ai-g732`, inspect
the existing Panther Release 9 target and factor the common Sable userspace from
Panther-specific device configuration. Do not copy Panther hardware assumptions
into the Titan 2 target.
