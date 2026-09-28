# SableOS N0/N1 flash plan ledger

Status: **research-to-SableOS deployment handoff / no write-capable executor**

This document makes the Titan 2 flashing model explicit for SableOS N0 and N1.
It is a handoff record from the Titan 2 research repo into SableOS execution so
future deployment work does not accidentally use Pixel/Panther assumptions.

```text
SABLEOS_N0_N1_FLASH_PLAN_LEDGER=YES
DEVICE=titan2
LANE=TREBLE_PORTABILITY
PIXEL_FASTBOOT_ASSUMPTIONS_ALLOWED=NO
PANTHER_ARTIFACT_FLASH_TO_TITAN2_ALLOWED=NO
WRITE_CAPABLE_SCRIPT_PRESENT=NO
FLASH_AUTHORIZED_BY_THIS_DOC=NO
DEVICE_CONTACT_AUTHORIZED_BY_THIS_DOC=NO
PUBLIC_RELEASE=NO
```

## Titan 2 constraints that govern N0/N1

```text
FASTBOOT_BOOT=UNSUPPORTED
DSU=UNAVAILABLE_ON_TESTED_STOCK_BUILD
FASTBOOTD=SUPPORTED
FASTBOOTD_MUST_BE_VERIFIED_BY_GETVAR_IS_USERSPACE_YES=YES
DYNAMIC_PARTITIONS=true
VIRTUAL_AB=true
SUPER_BYTES=9663676416
RECOVERY_PATH=vendor_boot_recovery_vendor_ramdisk
NO_STANDALONE_RECOVERY_PARTITION_OBSERVED=YES
FIRST_SABLE_BOOT=NOT_RUN
```

Practical consequence:

```text
BRINGUP_LOOP=flash_boot_recover
RAM_ONLY_FASTBOOT_BOOT_LOOP=UNAVAILABLE
```

## Preserve stock kernel/vendor/firmware stack

N0/N1 work should preserve the stock MediaTek kernel/vendor/firmware stack unless
new bring-up evidence forces a reviewed exception.

```text
PRESERVE_BOOT=YES
PRESERVE_INIT_BOOT=YES
PRESERVE_VENDOR_BOOT=YES
PRESERVE_DTBO=YES
PRESERVE_VENDOR=YES
PRESERVE_VENDOR_DLKM=YES
PRESERVE_ODM_DLKM=YES
PRESERVE_VBMETA_VENDOR=YES
PRESERVE_MODEM_AND_MTK_FIRMWARE=YES
```

## Required ledger before any first write

Do not create or run a write-capable command sequence until these fields are
known from current evidence and reviewed:

```text
RESTORE_REPORT=REQUIRED
BOOTLOADER_PREFLIGHT=REQUIRED
FASTBOOTD_PREFLIGHT=REQUIRED
SNAPSHOT_UPDATE_STATUS=none
ARTIFACT_SHA256=REQUIRED
ARTIFACT_LOGICAL_BYTES=REQUIRED
SYSTEM_CURRENT_BYTES=REQUIRED
LP_ACTION=direct-flash|reviewed-resize
AVB_ACTION=REQUIRED
USERDATA_POLICY=preserve|explicit-wipe-approved
EXPLICIT_TITAN_SERIAL=REQUIRED
ACTIVE_SLOT=REQUIRED
STOCK_BASELINE=REQUIRED
RESTORE_PATH_VERIFIED=REQUIRED
```

A userdata wipe must never be implicit.

```text
USERDATA_WIPE_IMPLICIT_ALLOWED=NO
USERDATA_WIPE_REQUIRES_EXPLICIT_APPROVAL=YES
```

## Stop conditions

Stop and recover or re-plan instead of stacking more changes if any of these is
true:

```text
TARGET_IDENTITY_AMBIGUOUS=STOP
RESTORE_VERIFICATION_FAILS=STOP
FASTBOOT_MODE_NOT_REQUESTED_MODE=STOP
BOOTLOADER_LOCKED_UNEXPECTEDLY=STOP
SNAPSHOT_UPDATE_STATUS_NOT_NONE=STOP
ARTIFACT_HASH_DIFFERS_FROM_REVIEWED_PLAN=STOP
ARTIFACT_SIZE_DIFFERS_FROM_REVIEWED_PLAN=STOP
LP_RESIZE_OR_DELETE_UNREVIEWED=STOP
RECOVERY_PATH_NOT_VERIFIED=STOP
```

## N0 minimum success gate

The first Sable N0 milestone is successful enough to continue only if it proves:

```text
N0_SYS_BOOT_COMPLETED=REQUIRED
N0_ADB_EXPLICIT_TITAN_SERIAL=REQUIRED
N0_PRIMARY_DISPLAY_USABLE=REQUIRED
N0_PRIMARY_TOUCH_USABLE=REQUIRED
N0_TITANKEY_ENUMERATED=REQUIRED
N0_TITANKEY_BASIC_EVENTS=REQUIRED
N0_TOUCHPAD_ENUMERATED=REQUIRED
N0_BOUNDED_RECOVERY_PATH=REQUIRED
```

This does not imply full parity for rear SubScreen, fingerprint, camera, audio,
modem/IMS, sensors or charging/thermal behavior. Those become follow-up N0
parity rows.

## N1 rule

N1 must reuse the Titan-specific flash gates and must not skip AVB, logical
partition, userdata, active-slot, restore or serial-targeting review just because
N0 has booted once.

```text
N1_REQUIRES_N0_EVIDENCE=YES
N1_REUSES_TITAN_FLASH_GATES=YES
N1_SKIP_AVB_LP_USERDATA_REVIEW_ALLOWED=NO
```
