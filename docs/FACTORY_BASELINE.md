# T2-R0 Factory Baseline

**Status:** CLOSED  
**Target handset:** Titan 2, US retail variant  
**Baseline build:** `Titan 2_V01.00.13-20260210` / incremental `V01.00.13`  
**Capture date:** 2026-09-22

This document records the stock state that was established before bootloader modification, plus the verified post-unlock transition used in T2-R2.

## Stock identity

| Field | Evidence |
|---|---|
| Manufacturer / model | Unihertz Titan 2 |
| Product / device | `Titan_2` |
| Fastboot product | `g71v78c2k_dfl_tee` |
| Platform family | MediaTek MT6878 |
| Android release | Android 16 |
| SDK | 36 |
| Build display ID | `Titan 2_V01.00.13` |
| Build incremental | `V01.00.13` |
| Build fingerprint | `Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.13:user/release-keys` |
| Security patch | `2025-12-05` |
| CPU ABI | `arm64-v8a` only |
| Zygote | `zygote64` |
| Product first API | 35 |
| Board first API | 34 |
| Vendor API | 34 |
| VNDK | 34 |
| Treble | true |
| Dynamic partitions | true |
| Virtual A/B | true |
| Active slot during research | `_a` |

## Kernel

The running stock kernel and the decompressed kernel extracted from the stock `boot.img` agree:

```text
Linux 6.1.145
branch: android14-11
arch: aarch64
build: 6.1.145-android14-11-gbd17012cc2f7-ab14044926
clang: 17.0.2
```

The production kernel exposes `/proc/config.gz`, which was preserved privately for later SableOS work.

## Pre-unlock verified-boot state

Before unlocking:

```text
ro.boot.verifiedbootstate = green
ro.boot.flash.locked      = 1
ro.boot.vbmeta.device_state = locked
ro.boot.slot_suffix       = _a
ro.boot.dynamic_partitions = true
ro.boot.avb_version       = 1.3
```

Bootloader fastboot reported:

```text
product      = g71v78c2k_dfl_tee
current-slot = a
unlocked     = no
secure       = yes
slot-count   = 2
is-userspace = no
unlock_ability = true
```

## Post-unlock state

The standard `fastboot flashing unlock` flow was completed successfully. After the required userdata reset and stock reboot:

```text
ro.boot.verifiedbootstate = orange
ro.boot.flash.locked      = 0
ro.boot.vbmeta.device_state = unlocked
ro.boot.slot_suffix       = _a
ro.boot.dynamic_partitions = true
ro.virtual_ab.enabled     = true
```

Bootloader fastboot reported:

```text
unlocked = yes
secure   = no
```

See [UNIHERTZ_QUIRKS.md](UNIHERTZ_QUIRKS.md) for the tiny unlock UI, timeout behavior, and the Volume Up confirmation nuance.

## Boot image arrangement

Observed from the verified stock images:

- `boot.img`: Android boot image header v4, kernel present, ramdisk size 0.
- `init_boot.img`: header v4, generic ramdisk present, kernel size 0.
- `vendor_boot.img`: vendor boot header v4, DTB present, two vendor ramdisk fragments.
- The second vendor ramdisk fragment has type `0x2` and name `recovery`.
- No standalone `recovery.img` was observed in the OTA-managed partition set.
- `dtbo`, `vbmeta`, `vbmeta_system`, and `vbmeta_vendor` are separate OTA-managed images.

This is consistent with a modern GKI-style boot layout with recovery carried inside `vendor_boot`.

## Virtual A/B / dynamic partitions

Fastbootd and LP metadata independently confirm Virtual A/B.

```text
super size                = 9663676416 bytes (9 GiB)
metadata version          = 10.2
metadata slot count       = 3
header flags              = virtual_ab_device
active group              = main_a
main_a maximum size       = 9661579264 bytes
snapshot-update-status    = none
```

Active logical partitions observed in fastbootd:

```text
odm_dlkm_a
product_a
system_a
system_dlkm_a
system_ext_a
vendor_a
vendor_dlkm_a
```

Corresponding `*_a-cow` logical partitions were present. LP metadata slot 1 described the corresponding `*_b` layout even though the `*_b` logical partitions were not materialized/openable through fastbootd while slot A was active.

## Controlled stock write test

After unlocking, the exact stock `V01.00.13` `init_boot.img` was written back to `init_boot_a`.

```text
partition size = 0x800000
image size     = 8388608 bytes
image SHA-256  = aa2d07bfb03b87401cedef7c318c59cb286b02eb47a1309ee0f2561a6141b223
fastboot send  = OK
fastboot write = OK
post-flash boot = OK
```

Android returned to stock `V01.00.13` with the expected unlocked/orange AVB state.

## Deferred hardware-specific characterization

The research phase intentionally stopped once SableOS feasibility was established. Detailed physical-keyboard behavior, secondary-display behavior, camera/audio/sensor completeness, fingerprint behavior, modem/IMS behavior, and per-key keylayout mapping remain **bring-up validation tasks**, not unresolved firmware/bootloader blockers.

## Private evidence archive

Raw captures and unredacted artifacts were consolidated to the Titan 2 research-evidence area on `ai-g732`.

```text
capture date:       2026-09-22
file count:         2706
SHA256SUMS SHA-256: bd9df72e51fa17a3eff8b03da5f218f5b4689de3f1dc0253be2c5552d10361eb
```

The private archive may contain device-specific identifiers and must not be mirrored into this public repository.
