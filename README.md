# Unihertz Titan 2

Bounded device research for a future SableOS Titan 2 bring-up, plus focused application research for physical-keyboard phones.

## Status

**Core Titan 2 boot/firmware research closed on 2026-09-22. SableOS bring-up is intentionally deferred until SableOS Release 9 validation on the Pixel 7 is complete.**

```text
T2-R0  Factory baseline                         CLOSED
T2-R1  Firmware + partition + recovery closure CLOSED
T2-R2  Bootloader / AVB / GSI feasibility      CLOSED
T2-R3  SableOS feasibility decision            GO / CLOSED

STOP BROAD DEVICE RESEARCH

Parallel work allowed:
  focused camera-app research
  focused physical-keyboard app research

OS bring-up resumes after:
  SableOS 9 validation on Pixel 7
```

No SableOS image has been flashed to the Titan 2 yet.

## Proven platform facts

- US retail handset fastboot product: `g71v78c2k_dfl_tee`.
- Stock baseline used for research: Android 16 `V01.00.13`, SPL `2025-12-05`.
- MediaTek platform family: MT6878.
- ARM64-only userspace (`zygote64`, `arm64-v8a`).
- Treble enabled; vendor/VNDK API level 34.
- Linux 6.1.145, Android 14-derived kernel branch.
- Dynamic partitions and Virtual A/B confirmed.
- 9 GiB `super` partition and working fastbootd.
- Standard bootloader unlock works; post-unlock AVB state is orange/unlocked.
- Boot-critical partition flashing works.
- `fastboot boot` is not implemented by the bootloader.
- DSU is not exposed by the stock firmware.
- Recovery ramdisk is carried in `vendor_boot`; no standalone recovery partition has been observed.
- The public non-EEA/`_tee` full firmware lineage is cryptographically equivalent to the observed US OTA lineage for all 34 OTA-managed partitions across `V01.00.13 -> V01.00.14`.

## Camera research snapshot

Focused read-only camera work on stock `V01.00.13` found a richer topology than the normal app-facing camera list suggests:

```text
4 total Camera2 devices
2 normal/public devices

0 = rear main
1 = front
2 = hidden SYSTEM_CAMERA rear telephoto
3 = hidden SYSTEM_CAMERA logical rear camera (physical IDs 0 + 2)
```

The stock MediaTek camera opens logical camera `3`. At 1× the active/master physical camera is `0`; at a captured ~4.63× zoom it is `2`. The HAL advertises multi-camera zoom steps `[1.0, 3.4]`.

The rear main and hidden telephoto both advertise RAW and manual Camera2 capabilities. AGOLD vendor metadata also exposes vendor super-resolution sizes corresponding to approximately 50 MP rear-main and 32 MP front output.

See [Camera research and Sable Camera plan](docs/CAMERA_RESEARCH.md).

## Physical-keyboard app research

While SableOS 9 validation continues on Pixel 7, the application track is evaluating existing physical-keyboard work rather than immediately starting another IME from scratch.

Primary references include:

- **Pastiera** — physical-keyboard IME with Titan 2 layouts/device archives;
- **Commander** — keyboard-first command palette / Android UX reference;
- **q25toolbox** — lower-level Q25 key-remap/accessibility/root integration reference;
- Unihertz community work and Discord discussions, converted into reproducible evidence before becoming repository claims.

See [Physical-keyboard app research plan](docs/KEYBOARD_APP_RESEARCH.md).

## Documentation

- [Factory baseline](docs/FACTORY_BASELINE.md)
- [US OTA capture](docs/OTA_CAPTURE.md)
- [Firmware equivalence](docs/FIRMWARE_EQUIVALENCE.md)
- [Bootloader and AVB](docs/BOOTLOADER_AVB.md)
- [Platform architecture](docs/PLATFORM_ARCHITECTURE.md)
- [Unihertz/Titan 2 quirks](docs/UNIHERTZ_QUIRKS.md)
- [Camera research and Sable Camera plan](docs/CAMERA_RESEARCH.md)
- [Camera no-root / root / SableOS capability roadmap](docs/CAMERA_ROOT_VS_NO_ROOT.md)
- [Physical-keyboard app research plan](docs/KEYBOARD_APP_RESEARCH.md)
- [SableOS bring-up contract](docs/SABLEOS_BRINGUP_CONTRACT.md)
- [References](docs/REFERENCES.md)

## Private evidence and firmware

Raw captures, firmware, OTAs, extracted images, device identifiers, and unredacted FOTA metadata do **not** belong in this repository.

The consolidated private evidence for the initial research pass is stored on `ai-g732` beneath the Titan 2 artifact area. The 2026-09-22 Mac-to-server consolidation contained 2,706 files; the resulting evidence-manifest SHA-256 was:

```text
bd9df72e51fa17a3eff8b03da5f218f5b4689de3f1dc0253be2c5552d10361eb  SHA256SUMS
```

Camera research dumps and future probe exports also stay private until reviewed/redacted.

Firmware/image corpora are maintained separately on `ai-g732` and are not committed here.

## Repository rules

- Never commit stock firmware, OTA packages, partition images, dumps, keys, calibration data, device serials, IMEI/MEID/ICCID values, FCM identifiers, MID values, or per-device/signed OTA query strings.
- Keep raw diagnostic output private until reviewed and redacted.
- Prefer hashes, metadata, reproducible commands, and bounded conclusions.
- Do not import Titan 2 Elite or Q27 assumptions into Titan 2 evidence.
- Keep prototype-device observations explicitly labeled as prototype evidence.
- When multiple Android devices are attached, always target the Titan explicitly with `adb -s <serial>` / `fastboot -s <serial>`.
- Do not relock the bootloader unless a fully stock, internally consistent firmware state has first been restored and verified.

## Near-term plan

The boot/firmware track stays parked. Application research can continue without changing the Titan 2 system image.

```text
camera:
  finish stock capability baseline
  -> build reusable Camera2 probe
  -> design Sable Camera around public + privileged backends

keyboard:
  capture Titan 2 physical-key event/keylayout baseline
  -> evaluate Pastiera on real hardware
  -> define cross-device keyboard profile schema

Q27:
  wait for newer/current OTA releases and preferably retail hardware
  -> do not generalize prototype firmware

SableOS:
  finish Release 9 validation on Pixel 7
  -> resume issue #2
  -> design Titan 2 recovery-safe first flash
```

The first alternate-system boot remains a **bring-up milestone**, not another research prerequisite.
