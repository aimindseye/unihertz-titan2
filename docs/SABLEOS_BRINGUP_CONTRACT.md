# SableOS Bring-Up Contract

This is the handoff from bounded Titan 2 research into future SableOS work.

**Research status:** complete  
**Bring-up decision:** GO  
**Execution status:** ACTIVE — Panther R9 is the frozen touch-first reference; keyboard-first Titan 2 Tier 2/N0 work is active

```text
DEVICE=titan2
SOC=MediaTek_MT6878
BOARD_PRODUCT=g71v78c2k_dfl_tee
ANDROID_BASE=16
SDK=36
KERNEL=6.1.145-android14-11
ARCH=arm64_only
PRODUCT_FIRST_API=35
BOARD_FIRST_API=34
VENDOR_API=34
VNDK=34

TREBLE=true
SLOTS=2
DYNAMIC_PARTITIONS=true
VIRTUAL_AB=true
SUPER_BYTES=9663676416

BOOTLOADER_UNLOCK=SUPPORTED_AND_VERIFIED
POST_UNLOCK_AVB_STATE=orange
FASTBOOTD=SUPPORTED
FASTBOOT_BOOT=UNSUPPORTED
DSU=UNAVAILABLE_ON_TESTED_STOCK_BUILD

STOCK_RECOVERY_PATH=vendor_boot_recovery_vendor_ramdisk
STOCK_FIRMWARE_ARCHIVED=YES_ON_AI_G732
OTA_MANAGED_STOCK_IMAGES=AVAILABLE_AND_VERIFIED
DEVICE_UNIQUE_PARTITION_BACKUP=NOT_CLAIMED

AVB_TOPOLOGY=CHAINED_BOOT_VBMETA_SYSTEM_VBMETA_VENDOR
ROOT_VBMETA_KEY_ROTATION_13_TO_14=YES

US_NON_EEA_EQUIVALENCE=PROVEN_FOR_34_OTA_MANAGED_PARTITIONS
GSI_BOOT=NOT_TESTED
VENDOR_COMPATIBILITY=PLAUSIBLE_TREBLE_VNDK34
KEYBOARD_BASELINE=COMPLETE_TIER1
SECONDARY_DISPLAY_BASELINE=COMPLETE_TIER1

SABLEOS_BRINGUP_AUTHORIZED=YES
SABLEOS_BRINGUP_STATUS=ACTIVE_TIER2_N0_PREFLIGHT
TITAN2_BUILD_TARGET=REQUIRED
TITAN2_SABLE_ARTIFACT=NOT_BUILT
PIXEL7_ARTIFACT_REUSABLE_FOR_TITAN2=NO

SABLEOS_R9_PANTHER_REFERENCE=COMPLETE
PUBLIC_BUILD_FOUNDATION=MERGED
PUBLIC_BUILD_SELF_TEST=MERGED
TITAN2_N0_DEVICE_ADAPTER=NOT_STARTED
TITAN2_N0_ARTIFACT=ABSENT
FIRST_SABLE_BOOT=BLOCKED_ON_ARTIFACT
TIER2_STOCK_BASELINE=ACTIVE
STOCK_FACTORY_DIAGNOSTICS=VERIFIED
SABLE_TITAN_DIAGNOSTICS=REQUIRED
```

## What "authorized" means

`SABLEOS_BRINGUP_AUTHORIZED=YES` means the bounded research questions have been answered well enough to begin a controlled port when the SableOS project is ready.

It does **not** mean an alternate system has already booted.

The first GSI/SableOS boot is intentionally a bring-up milestone.

## Required assumptions for the first bring-up

Initial work should preserve the stock MediaTek kernel/vendor stack unless evidence forces a different approach.

The first plan should treat these as stock dependencies:

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

Do not modify additional partitions without a specific bring-up reason.

## Required safety plan before the first non-stock system flash

Before flashing SableOS or a generic system image:

1. confirm the handset is still on the expected stock baseline and remains bootloader-unlocked;
2. verify the stock restore images and hashes are reachable on `ai-g732`;
3. record the active slot and current LP/super metadata;
4. choose explicit AVB handling for the experiment;
5. calculate the required logical-partition sizing against current `super` allocations;
6. preserve a recovery path for `boot`, `init_boot`, `vendor_boot`, `vbmeta*`, and the stock system/vendor images;
7. use explicit device serials for every `adb` and `fastboot` command when the Pixel 7 is also attached.

## Known development constraints

- The bootloader does not implement `fastboot boot`.
- The stock firmware does not expose a usable DSU path.
- Development therefore requires a flash/recover loop.
- Virtual A/B and COW partitions must be handled deliberately; do not treat COW partitions as disposable stale data.
- The root AVB signing key changed between V01.00.13 and V01.00.14.
- A custom system image will not match the stock system AVB hashtree; AVB strategy must be explicit.
- Titan-specific hardware support remains to be validated during bring-up.

## Resume point

Do not reopen broad Titan 2 research. Panther R9 is already frozen as the
touch-first reference; it is not a prerequisite still waiting to complete.

Resume with:

```text
Panther R9 frozen touch-first reference
    ↓
define Titan 2 SableOS system/framework target
    ↓
prepare AVB + super sizing + stock restore plan
    ↓
first controlled SableOS system flash
    ↓
validate boot, adb, display, keyboard
    ↓
fix Titan-specific hardware incrementally
```

The repository documents the evidence needed to start from this point.


## Active Tier 2 preflight

Tier 1 input/display/ownership research is complete. The active execution
sequence is documented in [TITAN2_TIER2_RUNBOOK.md](TITAN2_TIER2_RUNBOOK.md).

Before the first write, require saved evidence for:

```text
stock runtime baseline
stock restore verification
bootloader-fastboot preflight
fastbootd / LP preflight
Titan 2-specific Sable build target
exact Titan 2 Sable artifact SHA-256 + logical size
reviewed AVB action
reviewed userdata policy
```

The repository intentionally does not yet contain a write-capable N0 flash
script. The exact flash sequence will be created only after the actual Sable
artifact has been preflighted against the current Titan 2 LP/AVB state.

After first boot, use the saved stock-vs-Sable runtime comparison and
[TITAN2_N0_ACCEPTANCE_MATRIX.md](TITAN2_N0_ACCEPTANCE_MATRIX.md) to drive
device-specific fixes.


## Build-target boundary

The existing Pixel 7 / Panther Release 9 artifact is a reference build only. It
must not be flashed to Titan 2 or treated as the Titan 2 N0 candidate.

The current next step is [TITAN2_SABLE_BUILD_TARGET_PLAN.md](TITAN2_SABLE_BUILD_TARGET_PLAN.md):
create the Titan 2 Sable product/device target while preserving the stock MTK
kernel/vendor stack for N0. E3 artifact preflight remains blocked until that
build exists.
