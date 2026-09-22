# Unihertz Titan 2

Bounded device research for a future SableOS Titan 2 bring-up.

## Status

**Research closed on 2026-09-22. SableOS bring-up is intentionally deferred until SableOS Release 9 validation on the Pixel 7 is complete.**

```text
T2-R0  Factory baseline                         CLOSED
T2-R1  Firmware + partition + recovery closure CLOSED
T2-R2  Bootloader / AVB / GSI feasibility      CLOSED
T2-R3  SableOS feasibility decision            GO / CLOSED

STOP RESEARCH

Next:
  finish SableOS 9 validation on Pixel 7
  -> design Titan 2 flash/recovery plan
  -> start SableOS Titan 2 bring-up
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

See:

- [Factory baseline](docs/FACTORY_BASELINE.md)
- [US OTA capture](docs/OTA_CAPTURE.md)
- [Firmware equivalence](docs/FIRMWARE_EQUIVALENCE.md)
- [Bootloader and AVB](docs/BOOTLOADER_AVB.md)
- [Platform architecture](docs/PLATFORM_ARCHITECTURE.md)
- [Unihertz/Titan 2 quirks](docs/UNIHERTZ_QUIRKS.md)
- [SableOS bring-up contract](docs/SABLEOS_BRINGUP_CONTRACT.md)
- [References](docs/REFERENCES.md)

## Private evidence and firmware

Raw captures, firmware, OTAs, extracted images, device identifiers, and unredacted FOTA metadata do **not** belong in this repository.

The consolidated private evidence for this research pass is stored on `ai-g732` beneath the Titan 2 artifact area. The 2026-09-22 Mac-to-server consolidation contained 2,706 files; the resulting evidence-manifest SHA-256 was:

```text
bd9df72e51fa17a3eff8b03da5f218f5b4689de3f1dc0253be2c5552d10361eb  SHA256SUMS
```

Firmware/image corpora are maintained separately on `ai-g732` and are not committed here.

## Repository rules

- Never commit stock firmware, OTA packages, partition images, dumps, keys, calibration data, device serials, IMEI/MEID/ICCID values, FCM identifiers, MID values, or per-device/signed OTA query strings.
- Keep raw diagnostic output private until reviewed and redacted.
- Prefer hashes, metadata, reproducible commands, and bounded conclusions.
- Do not import Titan 2 Elite assumptions into Titan 2 evidence.
- When multiple Android devices are attached, always target the Titan explicitly with `adb -s <serial>` / `fastboot -s <serial>`.
- Do not relock the bootloader unless a fully stock, internally consistent firmware state has first been restored and verified.

## Next bring-up boundary

When SableOS 9 validation on Pixel 7 is finished, resume here rather than reopening device research.

The first Titan 2 bring-up plan should:

1. preserve the stock MTK kernel/vendor stack initially;
2. define the SableOS system/framework image against the observed Treble/VNDK-34 contract;
3. account for AVB explicitly;
4. account for Virtual A/B and current `super` allocations;
5. define a stock restore path before the first non-stock flash;
6. test Titan-specific hardware only as it becomes a bring-up blocker.

The first alternate-system boot is a **bring-up milestone**, not another research prerequisite.
