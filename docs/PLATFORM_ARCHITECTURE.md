# T2-R2/T2-R3 Platform Architecture

**Status:** CLOSED for research / GO for future SableOS bring-up

## Userspace / Treble contract

Observed on stock V01.00.13:

```text
ro.treble.enabled            = true
ro.product.cpu.abi           = arm64-v8a
ro.product.cpu.abilist       = arm64-v8a
ro.zygote                    = zygote64
ro.product.cpu.abilist32     = [empty]
ro.product.cpu.abilist64     = arm64-v8a
ro.product.first_api_level   = 35
ro.board.first_api_level     = 34
ro.vendor.api_level          = 34
ro.vndk.version              = 34
ro.boot.dynamic_partitions   = true
ro.virtual_ab.enabled        = true
ro.boot.slot_suffix          = _a
```

The device is therefore a 64-bit-only ARM64 target with Treble enabled.

The Android 16 framework/product stack is running against an Android-14-era vendor interface level (API/VNDK 34). That separation is favorable for an initial SableOS strategy that preserves the stock kernel/vendor stack.

## Kernel

Running kernel:

```text
Linux 6.1.145-android14-11-gbd17012cc2f7-ab14044926
arch: aarch64
clang: 17.0.2
```

The stock `boot.img` kernel is LZ4-compressed. After decompression it identifies as a normal little-endian ARM64 Linux kernel Image and reports the same kernel version string as the running device.

`/proc/config.gz` is readable on the stock device and was preserved privately. This gives later bring-up work the exact production kernel configuration rather than requiring guesses.

## VINTF

Both vendor and system VINTF trees are present.

Observed vendor files include:

```text
/vendor/etc/vintf/manifest.xml
/vendor/etc/vintf/compatibility_matrix.xml
/vendor/etc/vintf/manifest/*
```

Observed system files include multiple framework compatibility matrices, a device compatibility matrix, and system manifest fragments.

The full VINTF trees and an `lshal` snapshot were archived privately for later compatibility analysis.

## Dynamic partitions

Android properties, fastbootd, and LP metadata all independently confirm dynamic partitions.

Fastbootd reports:

```text
is-userspace: yes
current-slot: a
super-partition-name: super
partition-size:super: 0x240000000
dynamic-partition: true
```

`0x240000000` is 9 GiB.

Active logical partitions observed:

```text
odm_dlkm_a
product_a
system_a
system_dlkm_a
system_ext_a
vendor_a
vendor_dlkm_a
```

Each reports `is-logical: ... yes`.

## Virtual A/B

Stock properties expose Virtual A/B features including compression and userspace snapshots:

```text
ro.virtual_ab.enabled=true
ro.virtual_ab.compression.enabled=true
ro.virtual_ab.userspace.snapshots.enabled=true
```

`lpdump` confirms:

```text
Metadata version: 10.2
Metadata max size: 65536 bytes
Metadata slot count: 3
Header flags: virtual_ab_device
Partition name: super
Size: 9663676416 bytes
```

Slot 0 metadata uses group `main_a`; slot 1 metadata uses `main_b`.

Both groups have a maximum size of:

```text
9661579264 bytes
```

The active slot also exposed `*_a-cow` logical partitions. `snapshot-update-status` was `none`.

A key nuance: while slot A was active, direct fastbootd queries for `system_b`, `vendor_b`, etc. failed with "Partition not found", even though LP metadata slot 1 describes the corresponding `*_b` layout. This is expected Virtual A/B behavior and should not be mistaken for a missing second boot slot.

## Physical A/B vs logical Virtual A/B

Boot-critical physical partitions are genuinely slotted. Examples observed through fastboot:

```text
boot_a / boot_b
vendor_boot_a / vendor_boot_b
preloader_raw_a / preloader_raw_b
```

The dynamic-partition userspace is managed through `super` and Virtual A/B metadata/snapshots instead of maintaining a fully materialized second copy of every logical partition at all times.

## DSU

The stock firmware does not expose a usable Dynamic System Updates path.

Observed:

```text
pm list features | grep -i dynamic
    -> no Dynamic System feature reported

cmd dynamic_system help
    -> No shell command implementation.

ro.gsid.image_running
    -> empty

ro.gsid.mapped_image
    -> empty
```

DSU therefore cannot be relied on for a temporary GSI/SableOS trial on this stock build.

## Temporary boot

Bootloader `fastboot boot` is also unsupported. The image transfer succeeds but the boot action fails with:

```text
FAILED (remote: 'unknown command')
```

Therefore the practical development loop is:

```text
prepare image
-> flash deliberately
-> boot/test
-> recover using verified stock images if necessary
```

rather than DSU or RAM-only fastboot boot.

## T2-R3 feasibility conclusion

The research decision is **GO** for a future SableOS bring-up.

The initial strategy should preserve the stock MediaTek kernel/vendor stack and treat Titan 2 as a Treble-capable ARM64 target. A generic/SableOS system boot has **not** yet been tested; that test belongs to the bring-up phase.

Research does not establish that every Titan-specific peripheral will work under a generic userspace. The physical keyboard, secondary display, fingerprint, cameras, sensors, audio, modem/IMS, and device-specific framework hooks should be validated only when bring-up reaches them.

## Current stop point

No alternate system image has been flashed.

Further Titan 2 work is intentionally paused until SableOS Release 9 has completed its Pixel 7 validation. At that point, resume with a recovery-safe first-flash plan covering:

- stock restore procedure;
- AVB handling;
- current `super` allocation and logical-partition sizing;
- SableOS system image compatibility with the vendor/VNDK-34 contract;
- Titan-specific hardware validation.
