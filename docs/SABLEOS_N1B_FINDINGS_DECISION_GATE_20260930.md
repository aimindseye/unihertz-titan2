# SableOS N1B Titan 2 findings and decision gate

Status: **stop N1B trial loop; benchmark before next build or flash**
Date: 2026-09-30

```text
DEVICE=titan2
SABLEOS_TRACK=N1B
NEW_SABLE_BUILD_AUTHORIZED=NO
NEW_FLASH_AUTHORIZED=NO
RUNTIME_TRIAL_LOOP=STOPPED
BENCHMARK_FIRST_DECISION_GATE=REQUIRED
```

## Why this document exists

The Titan 2 research repo is the durable place to record why SableOS N1B work is
paused before more builds/flashes. This is not a failure to build a GSI. The
issue is runtime compatibility between a generic system image and Titan 2's
MediaTek vendor/modem/device-specific stack.

## What SableOS N1B proved

### System-image build and artifact sealing

```text
SABLE_GSI_IMAGE_BUILD=PROVEN
TARGET_FILES_BUILD=PROVEN
ARTIFACT_HASH_SEAL=PROVEN
TARGET_FILES_VERIFICATION=PROVEN
```

The Sable/Restless-derived GSI image can be built. The blocker is not the image
compiler or packaging layer.

### Flashing model

```text
FASTBOOTD=SUPPORTED
ACTIVE_SLOT=a
SYSTEM_A_RESIZE=PROVEN
SYSTEM_A_FLASH=PROVEN
USERDATA_PRESERVED=YES
BOOT_VENDOR_VBMETA_FLASHED=NO
FULL_SUPER_FLASHED=NO
```

This proves a bounded `system_a` flash path. It does **not** prove that a
system-only GSI is the right architecture for Titan 2.

## What N1B3/N1B4 changed

N1B3 added product-level radio compatibility markers and explicitly kept stock
MTK telephony payloads out of the Sable image.

N1B4 removed the Treble MTK IMS overlay path that pointed AOSP IMS resolution at
`com.mediatek.ims`, which is absent in SableOS.

```text
MTK_IMS_OVERLAY_REMOVED=YES
COM_MEDIATEK_IMS_BINDING_REMOVED=YES
STOCK_MTK_APK_JAR_SO_IMPORT=NO
```

That was a valid fix for one defect, but cellular still disconnects.

## Cellular runtime findings

Observed pattern across N1B runs:

```text
LTE_RETURNS_BRIEFLY=YES
NR_NSA_OR_5G_DISPLAY_ANCHOR_APPEARS=YES
WWAN_DATA_CONNECTS_OR_ATTEMPTS=YES
WWAN_PACKET_SERVICE_DROPS=YES
DATA_CALL_FAIL_CAUSE=ERROR_UNSPECIFIED_0xffff
POST_DROP_STATE=OUT_OF_SERVICE_OR_EMERGENCY_OR_UNKNOWN
REJECT_CAUSES_SEEN=11,13,15,114
```

Important interpretation:

- The old `com.mediatek.ims` overlay/binding problem is corrected by N1B4.
- The remaining problem is cellular stability on the MediaTek vendor/modem path.
- A displayed `NR_NSA`/5G state is not enough to prove a stable physical NR data
  session.
- The system can briefly see LTE registration and then lose WWAN packet service.

## Experiments that should not be repeated blindly

### IWLAN disable

```text
COM_GOOGLE_ANDROID_IWLAN_DISABLE_STABILIZED_CELLULAR=NO
```

IWLAN/QNS may still be noise, but disabling the IWLAN package alone did not fix
cellular.

### APN force attempt

```text
FORCE_310260_APN_SELECTION=NOT_APPLIED
APN_OVERLAY_FIX_READY=NO
```

The attempted APN row switch did not stick. Do not ship an APN overlay until the
baseline comparison proves it is needed.

### LTE-only ADB masks

```text
CMD_PHONE_SET_ALLOWED_NETWORK_TYPES_FOR_USERS=FAILED_NO_VALID_NETWORK_TYPES_BITMASK
ADB_LTE_ONLY_TEST_RAN=NO
```

The getter worked, but the setter rejected tested masks. Do not continue guessed
mask attempts.

### UI LTE-only direction

Manual LTE-only direction still produced a cellular disconnect. The evidence did
not prove that simply disabling NR solves the issue.

```text
UI_LTE_ONLY_STABLE=NO
NR_DISABLE_FIX_PROVEN=NO
```

## Why Titan 2 needs a decision gate

Titan 2 is a MediaTek device with keyboard, rear-screen, DSDS, modem and
carrier/IMS behavior that does not behave like a Pixel-style AOSP target. The
current Sable path is system-image oriented. Existing community work appears to
use Titan-specific GSI customization and may rebuild a `super` image using stock
partitions.

That difference matters. A system-only flash that boots is not necessarily the
right product architecture.

## External references to benchmark

### Downloaded image on Mac mini

```text
Titan2-LineageOS-23.0-20251027-GAPPS-EXT4-GSI-v0.0.2.img.gz
```

This should be inspected before flashing:

```text
INSPECT_ONLY_FIRST=YES
DECOMPRESS=YES
IDENTIFY_IMAGE_TYPE=YES
MOUNT_OR_EXTRACT_READONLY=YES
FLASH=NO_UNTIL_REPORT
```

### GitHub reference

```text
agreenbhm/Unihertz-Titan-2-LineageOS
```

Initial review shows a Titan 2 GSI customization repo, not a complete traditional
device tree. It includes runtime hooks and a tool for building a Titan 2 super
image from stock dynamic partitions plus a Lineage GSI system image.

### PeterGSI reference

```text
PeterGSI/android_device_peter_gsi
```

This should be reviewed for Titan 2 device hooks, input/keyboard behavior,
Treble/PeterGSI boot scripts, telephony properties and any MediaTek-specific
handling.

## Options under review

### Option A — Pause Titan 2 as immediate SableOS release target

Keep Titan 2 as a research target while main SableOS development continues on the
better-controlled Pixel/R9 path.

### Option B — Use LineageOS 23 Titan 2 as reference baseline

If the LineageOS 23 Titan 2 image has stable cellular, compare and port only the
minimum understood changes.

### Option C — Stock-super plus Sable-system architecture

If Lineage/PeterGSI stability depends on rebuilding `super` and preserving stock
`vendor`, `system_ext`, `system_dlkm`, `vendor_dlkm` and `odm_dlkm`, Sable Titan 2
should move away from system-only flash assumptions.

### Option D — Stock firmware plus hardening/debloat

If GSI paths remain unstable and daily-driver cellular is required, a stock-based
privacy hardening path may be more practical than a full SableOS replacement.

## Decision gate plan

```text
TITAN2_DECISION_GATE_R1=REQUIRED
NO_NEW_SABLE_BUILD_UNTIL_GATE=YES
NO_FLASH_UNTIL_GATE=YES
NO_RELEASE_CLAIM_UNTIL_GATE=YES
```

The report should answer:

1. What exactly is the downloaded LineageOS 23 artifact: sparse system image,
   raw system image, super image or another format?
2. Which stock partitions does the Lineage flow preserve or rebuild?
3. What does Lineage/PeterGSI do in `phh-on-boot.sh` or equivalent runtime hooks?
4. How do Lineage/PeterGSI handle MTK IMS, EPDG, IWLAN, QNS and carrier config?
5. Does LineageOS 23 cellular remain stable on the same SIM/location?
6. If stable, is the reason system image content, super packaging, stock vendor
   preservation, runtime hooks or carrier/modem configuration?
7. Should Sable choose Option A, B, C or D?

## Current hold

```text
N1B4_VALID_PREREQUISITE=YES
N1B4_CELLULAR_FIX=NO
N1B5_PATCH_LOOP=STOPPED
NEXT_WORK=TITAN2_DECISION_GATE_R1_REPORT
```
