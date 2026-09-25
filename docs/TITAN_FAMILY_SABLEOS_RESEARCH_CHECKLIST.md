# Titan 2 family research checklist for SableOS

Status: **active — Titan 2 Tier 1 A–D complete; Tier 2, first-Sable validation, and Titan 2 Elite work remain**

Date: 2026-09-24

This checklist is intentionally narrower than the original Titan 2 firmware
forensics. The Titan 2 bootloader/AVB/Treble feasibility questions are already
well covered. The next research should produce evidence that directly fills
future SableOS device-adapter, keyboard-first UI, Camera and N0 acceptance
contracts.

Titan 2 and Titan 2 Elite are always independent evidence targets. Do not copy a
PASS from one device to the other.


## Progress snapshot — Titan 2 (2026-09-25)

Status labels in this table apply only to the **Titan 2** retail unit and stock
V01.00.13 evidence. Titan 2 Elite remains an independent target.

| Checklist area | Titan 2 status | Current boundary |
| --- | --- | --- |
| Tier 1 A. Physical keyboard event pipeline | **COMPLETE** | Stable Linux/Android mapping, driver ownership, side-key paths, wake boundary, keyboard illumination backend, `ff_key` fingerprint ownership, and native vendor key-404 synthesis are mapped sufficiently for the first Sable adapter. Exact stock-only preference/predicate parity is optional. |
| Tier 1 B. Keyboard touch surface / mouse mode | **COMPLETE** | `touchPad` is a separate ABS_MT device; stock Mouse Mode is Android Mouse Keys layered above it. |
| Tier 1 C. Display and input topology | **COMPLETE** | Primary and rear SubScreen topology, touch association, wake/lifecycle, brightness independence, notification presentation, security/display-group behavior, and rotation are characterized. Runtime display IDs remain explicitly non-stable. |
| Tier 1 D. Stock keyboard/SubScreen ownership | **COMPLETE** | Kernel/vendor-framework/replaceable-policy boundaries are mapped, including keyboard light, programmable keys, Mouse Keys, SubScreen launcher/notifications, Kika policy, and vendor key-404 consumers. |
| Titan 2 Elite Tier 1 arrival baseline | **NOT STARTED / WAITING FOR HARDWARE** | Must be captured independently before mutation; do not copy Titan 2 PASS results. |
| Tier 2 E. Restore and deployment contract | **PARTIAL — E0/E1/E2 PASS; build target required; E3 blocked** | Restore set verified and hashed; bootloader-fastboot and fastbootd preflights passed. Sable Release 9 currently has a Pixel 7 / Panther artifact only; it is not a Titan 2 candidate. Still required: create a Titan 2 Sable build target, build the first Titan 2 artifact, run E3 artifact preflight, review AVB/LP/userdata policy, then perform the first bounded deployment. |
| Tier 2 F. VINTF / vendor compatibility | **PARTIAL** | Stock Treble/vendor/VNDK/API/ABI baseline and compatibility feasibility are known. Still required: normalized first-Sable comparison of HAL/service availability against stock. |
| Tier 2 G. AVB / rollback / security | **PARTIAL** | Bootloader/AVB feasibility work is complete enough for bring-up and stock vbmeta artifacts are captured. Still required for the checklist: normalized full security-capability inventory (KeyMint/Gatekeeper/StrongBox/biometric strength and any remaining rollback/key-rotation details) for a future security claim. |
| Tier 2 H. Camera | **PARTIAL — normal-app path complete** | Ordinary-app topology/probe and Sable Camera main/front/JPEG/DNG work are complete. Remaining controlled phase: SYSTEM_CAMERA-capable hidden tele/logical-camera access and negative third-party discovery tests if that capability is adopted. |
| Tier 2 I. Telephony / IMS | **NOT STARTED as checklist baseline** | SIM/carrier-specific data, voice, SMS/MMS, IMS, VoLTE/VoWiFi, APN, dual-SIM and call-audio baseline still required. |
| Tier 2 J. Audio | **NOT STARTED as checklist baseline** | Earpiece, speaker, microphones, Bluetooth, USB audio, FM, haptics and call/camera routing baseline still required. |
| Tier 2 K. Fingerprint, sensors, NFC and GNSS | **PARTIAL / INCIDENTAL ONLY** | Fingerprint kernel/input ownership has incidental evidence from keyboard work. Full behavior + HAL/service inventory for fingerprint, sensors, NFC, GNSS, IR and USB OTG remains. |
| Tier 2 L. Power / thermal / suspend | **PARTIAL** | Keyboard/SubScreen wake and screen-off key behavior are characterized. Charging/health policy, broad suspend/deep-idle, thermal zones/throttling and battery/Health HAL baseline remain. |
| Acceptance matrix | **PARTIAL** | Stock evidence can now be filled for boot feasibility, display/touch, keyboard/pointer/IME, SubScreen and normal-app camera. Every **First Sable N0** cell remains unproven until a Sable artifact is actually deployed. |

### Current research stop boundary

For Titan 2, do **not** continue broad keyboard/SubScreen reverse engineering before
the first Sable adapter/N0 experiment. Tier 1 answered the safety and ownership
questions it was intended to answer.

The next highest-value work is:

1. turn the completed keyboard/display contracts into the Titan 2 Sable device
   adapter;
2. finish the explicit Tier 2 E first-deployment contract and perform the first
   bounded Sable N0 experiment;
3. use that boot to populate the first-Sable side of the acceptance matrix and
   drive only evidence-based follow-up;
4. in parallel, capture stock telephony/audio/sensors/power baselines before
   those subsystems are needed for N0 parity;
5. keep Titan 2 Elite entirely pending until the physical unit can be qualified
   independently.

## Evidence discipline

For every capture record:

```text
device family
retail variant / region
exact stock build display + incremental
Android release / security patch
capture date
locked/unlocked state
active slot
tool versions
whether the operation was read-only or state-changing
```

Keep raw dumps, serials, modem identifiers and unreviewed vendor diagnostics in
private evidence storage. Commit normalized/redacted conclusions and hashes.

Do not identify Titan 2 Elite solely by a Titan-like fingerprint. Capture
multiple independent identifiers and SoC/storage facts.

## Tier 1 — highest-value research before SableOS image work

### A. Physical keyboard event pipeline

Build a complete mapping from hardware event to Android/app behavior:

```text
Linux input device
  -> scan code / EV_KEY or axis
  -> .kl key layout
  -> Android KeyEvent keyCode/meta state
  -> .kcm character mapping
  -> IME/text composition
  -> focused app action
```

Capture:

- `/proc/bus/input/devices`;
- `dumpsys input`;
- `getevent -lp` for the relevant input devices;
- device-specific files under `/odm/usr/keylayout`,
  `/vendor/usr/keylayout`, `/system/usr/keylayout`;
- corresponding `.kcm` and `.idc` files;
- `dumpsys input_method`;
- stock keyboard/IME package identities and versions;
- stock framework/vendor services or overlays related to keyboard/touchpad;
- programmable-key configuration storage/owner.

For every physical key record at least:

```text
base press/release
Shift
Alt
Fn/Sym
long press
auto-repeat
two-key/chord behavior
lockscreen behavior
screen-off wake behavior
focused text field
non-text application
```

Specifically characterize:

- Space and Enter;
- Back/Escape;
- Shift and Alt state/lock behavior;
- Fn/Sym;
- navigation/cursor keys or emulated navigation;
- red programmable key(s);
- camera-compatible shutter candidates;
- any dedicated Recent/Home/Back behavior;
- keyboard backlight controls.

Do not infer Android key codes from printed key labels.

### B. Keyboard touch surface / mouse mode

This is especially important because current Unihertz firmware exposes
touch-surface behavior on the keyboard.

Determine whether keyboard touch gestures arrive as:

- the same Linux input device as the key matrix;
- a separate touch/relative-pointer device;
- Android MotionEvents;
- mouse/trackpad axes/buttons;
- a vendor service that synthesizes input.

Capture behavior with stock mouse mode OFF and ON.

For Titan 2 Elite also test:

- cursor movement on the capacitive keyboard;
- flick/candidate selection behavior;
- long-slide keyboard-backlight gesture;
- shortcut behavior;
- whether these depend on the stock IME.

The SableOS design should not depend on Kika or another IME for hardware
pointer/key events that properly belong in the platform input adapter.

### C. Display and input topology

For both devices capture:

- `dumpsys display`;
- `dumpsys window displays` / WindowManager display information;
- `SurfaceFlinger --display-id` / equivalent available display inventory;
- physical resolution, logical resolution, density and refresh modes;
- cutout/rounded-corner/inset data;
- natural orientation and rotation behavior;
- touch input association to display IDs;
- minimum/smallest-width configuration.

For Titan 2, treat the rear SubScreen as a separate subsystem. Characterize:

```text
display ID / type
resolution + density
touch input device and display association
wake / double-tap behavior
brightness control owner
screen-on/off coupling
which apps can be launched/shown
security restrictions
notification presentation
rotation/orientation
whether input remains active when rear display is disabled
```

This evidence should drive a display profile; do not hard-code "Titan 2 means
display 1".

### D. Stock keyboard/subscreen implementation ownership

Inventory stock packages, privileged permissions, services, overlays and native
libraries that appear to own:

- keyboard remapping;
- mouse mode;
- shortcut customization;
- keyboard backlight;
- programmable buttons;
- SubScreen lifecycle/input/security;
- stock Kika integration.

Goal: classify each behavior as one of:

```text
kernel/input-driver capability
vendor framework/service capability to preserve
replaceable stock app/IME policy
Sable-owned presentation behavior
```

This prevents SableOS from replacing a UI package and accidentally deleting the
only owner of a hardware capability.

## Tier 1 for Titan 2 Elite arrival

Before mutation, create an Elite factory baseline equivalent to Titan 2
`FACTORY_BASELINE.md`.

Record independently:

- exact model/variant and SoC;
- product/device/board identities;
- bootloader fastboot product;
- Android/build/security patch;
- first API / board API / vendor API / VNDK;
- ABI/zygote bitness;
- Treble;
- dynamic partitions;
- A/B / Virtual A/B;
- kernel/version/config availability;
- stock locked AVB state;
- partition inventory;
- boot/init_boot/vendor_boot/recovery arrangement;
- VINTF trees;
- super metadata and free-space constraints;
- bootloader and fastbootd capabilities;
- stock firmware/OTA/restore artifact availability.

Do not assume standard Titan 2 Elite and Titan 2 Elite Pro have the same SoC or
firmware basis. Record the exact retail unit.

## Tier 2 — platform bring-up evidence

### E. Restore and deployment contract

Before the first non-stock image on either device prove:

```text
exact stock restore source
hashes for restore-critical images
bootloader mode identity
fastbootd identity
super/LP metadata capture
snapshot-update state
active slot
vbmeta chain
known-good reboot back to stock
```

Keep bootloader-fastboot and fastbootd capability inventories separate.

Determine whether the first SableOS N0 artifact should be:

- a pure `system.img` GSI;
- a generated `super.img`;
- a bounded system/product/system_ext bundle.

Do not choose based only on a community flashing recipe. Choose based on actual
LP metadata, free space, AVB and restore constraints.

Also determine experimentally, before enabling automation, whether first GSI
deployment requires a userdata wipe. If it does, the Sable deployment adapter
must expose a separate explicit destructive-data policy; it must not silently
reuse Panther's preserved-data contract.

### F. VINTF / vendor compatibility

Preserve and normalize:

- complete vendor/system VINTF trees;
- `lshal` / AIDL service inventory;
- vendor API/VNDK levels;
- vendor and ODM property sets relevant to framework compatibility;
- APEX configuration;
- 64-bit-only assumptions;
- SELinux enforcing state and policy version.

At first Sable GSI boot, compare service/HAL availability to the stock baseline
rather than debugging only visible UI failures.

### G. AVB / rollback / security

For every firmware baseline used for SableOS record:

- top-level vbmeta key digest;
- chained vbmeta keys;
- rollback-index locations and values;
- descriptors for boot/init_boot/vendor_boot/dtbo/system/vendor/product/etc.;
- locked/unlocked verified-boot state;
- any key rotation between OTAs.

Also inventory platform security capabilities that matter for a future support
claim:

- KeyMint/Gatekeeper versions;
- StrongBox feature presence if any;
- fingerprint/biometric HAL and authenticator strength;
- SELinux state;
- kernel security patch/build;
- vendor security patch;
- bootloader/firmware versions.

N0 functionality must not be mislabeled as N2 security ownership.

## Tier 2 — hardware/runtime baseline

### H. Camera

Continue the existing Camera Probe work.

For Elite, repeat the ordinary-app probe first. Do not import Titan 2 camera IDs
or vendor-tag values.

Only in the later controlled system-app phase compare:

```text
ordinary camera enumeration
vs
SYSTEM_CAMERA-capable Sable Camera enumeration
```

If a hidden tele/logical camera appears only with SYSTEM_CAMERA, retain the
normal user-revocable CAMERA permission and run negative third-party discovery
tests.

### I. Telephony / IMS

Create a stock baseline before GSI work for each active carrier/SIM combination
you care about:

- SIM/eSIM topology;
- data registration;
- LTE/5G NSA/SA where available;
- voice calling;
- SMS;
- MMS;
- IMS registration;
- VoLTE;
- VoWiFi;
- carrier configuration;
- APN;
- dual-SIM behavior;
- call audio routes.

Do not use emergency services as a test target.

Titan 2 region/firmware branches and Elite eSIM capability make this especially
important.

### J. Audio

Baseline:

- earpiece;
- loudspeaker;
- microphones for call and recording;
- Bluetooth call/media;
- USB audio;
- FM radio path;
- vibration/haptics;
- audio routing during calls and Camera recording.

### K. Fingerprint, sensors, NFC and GNSS

Capture stock behavior and HAL/service identity for:

- fingerprint;
- accelerometer;
- gyroscope;
- compass;
- proximity;
- ambient light;
- NFC;
- GNSS;
- IR;
- USB OTG.

These are N0 parity checks after the first Sable userspace boot.

### L. Power / thermal / suspend

Record stock reference behavior for:

- charging modes and 80%/battery-health policy if present;
- suspend/deep-idle behavior;
- wake sources;
- thermal zones and throttling;
- battery/Health HAL;
- keyboard/subscreen wake cost;
- screen-off physical-key behavior.

Do not tune power policy until Sable userspace can reproduce the stock
observation baseline.

## Acceptance matrix to prepare now

Use the same column set for Titan 2 and Elite:

| Area | Stock evidence | First Sable N0 | Device adapter needed | Common Sable change needed |
| --- | --- | --- | --- | --- |
| boot/adb | | | | |
| display/touch | | | | |
| physical keyboard | | | | |
| keyboard pointer/mouse | | | | |
| IME/text entry | | | | |
| rear SubScreen (Titan 2) | | | | |
| Wi-Fi | | | | |
| Bluetooth | | | | |
| cellular data | | | | |
| voice/IMS | | | | |
| SMS/MMS | | | | |
| audio | | | | |
| camera | | | | |
| fingerprint | | | | |
| sensors | | | | |
| NFC | | | | |
| GNSS | | | | |
| suspend/power | | | | |

The last two columns are important: repeated "common Sable change needed"
results are a signal that the portability abstraction is wrong.

## Research stop rule

Do not wait for perfect reverse engineering before beginning N0. Research is
sufficient when it answers the safety and adapter questions needed for the next
bounded experiment.

Conversely, do not mutate a device merely because a community GSI worked.
SableOS requires its own restore, artifact, serial-binding and evidence contract.
