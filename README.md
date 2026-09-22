# Unihertz Titan 2

Bounded device research for safely starting a SableOS Titan 2 bring-up.

## Current phase

**T2-R0 — Factory baseline**

R0 is intentionally read-only. Do not unlock the bootloader, flash partitions, root the phone, or alter AVB while establishing the factory baseline.

The first device-side deliverable is a single collector:

```bash
./tools/t2-r0-collect.sh snapshot
```

To observe the stock updater while checking for a US OTA:

```bash
./tools/t2-r0-collect.sh ota-watch
```

Both modes use ADB read operations only. Captures are written beneath `artifacts/private/`, which is ignored by Git. Treat raw logcat and diagnostic output as private until reviewed and redacted.

## Research boundary

The objective is to learn only enough about the device to safely and intelligently start SableOS development.

```text
T2-R0  Factory baseline
   ↓
T2-R1  Firmware + partition + recovery closure
   ↓
T2-R2  Bootloader / AVB / GSI feasibility
   ↓
T2-R3  SableOS feasibility decision
   ↓
STOP RESEARCH
   ↓
SableOS Titan 2 bring-up
```

Research exits when device identity, stock firmware preservation, partition/boot architecture, recovery, bootloader/AVB behavior, stock-vendor viability, core Titan-specific hardware, and one bounded alternate-system proof are known well enough for bring-up.

## US OTA investigation

Public Titan 2 rooting material documents EEA/Worldwide firmware and OTA packages distributed through Google Drive, but that does **not** establish that the US variant uses the same source, naming, or delivery path.

For the US handset, capture what the stock updater actually does before making assumptions. See [docs/OTA_CAPTURE.md](docs/OTA_CAPTURE.md).

## Repository rules

- Do not commit stock firmware, OTA packages, partition images, dumps, keys, calibration data, or device-specific secrets.
- Keep firmware archives on the designated offline/storage host, not in this repository.
- Prefer hashes, metadata, scripts, reproducible commands, and redacted observations.
- Do not import Titan 2 Elite assumptions into Titan 2 evidence.
- Keep the project small: investigate only what blocks SableOS bring-up.

## Layout

```text
docs/
  FACTORY_BASELINE.md
  OTA_CAPTURE.md
  REFERENCES.md
  SABLEOS_BRINGUP_CONTRACT.md
tools/
  t2-r0-collect.sh
artifacts/private/   # local only, gitignored
```
