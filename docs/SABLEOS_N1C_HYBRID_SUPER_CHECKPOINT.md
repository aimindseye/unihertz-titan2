# SableOS N1C Hybrid-Super Checkpoint

Status: **PASS — no-flash artifact ready for review**

This document records the Titan 2 N1C Android 16 hybrid-super checkpoint. It is **not** a flash authorization.

```text
TRACK=N1C_ANDROID16_HYBRID_SUPER
FLASH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
SUPER_COMPOSITION_ALREADY_DONE=YES
PUBLIC_RELEASE=NO
PRODUCTION_READY_CLAIM=NO
```

## Final reviewed artifact

```text
SUPER_SPARSE=/srv/data/sable-build/evidence/titan2/n1c-no-flash-hybrid-super-composition-r1f-20260930_185012/titan2-n1c-hybrid-super-r1f.sparse.img
SUPER_SHA256=d97e53f5e4b3f23245b600b311c6071eb9ab7897be093ea21dea83bbde3f3711
SUPER_BYTES=5401222076
RAW_SUPER_BYTES=9663676416
SYSTEM_IMG=/srv/data/sable-build/workspaces/titan2-n1c-android16-hybrid-super-20260930_140947/out_n1c_aosp_arm64_systemimage_apns_source_filter/target/product/generic_arm64/system.img
SYSTEM_SHA256=ed9edad3c65e4908028bb6087bbb712efff81bd4fe6601cc6cc6f0273b545c5d
SYSTEM_BYTES=1972953088
```

## Partition contract

```text
SYSTEM_A_REPLACED_WITH_SABLE_AOSP_ARM64=YES
STOCK_DYNAMIC_PARTITIONS_PRESERVED=product_a system_ext_a vendor_a system_dlkm_a vendor_dlkm_a odm_dlkm_a
BOOT_PRESERVED_BY_THIS_ARTIFACT=YES_NO_BOOT_IMAGE_INCLUDED
INIT_BOOT_PRESERVED_BY_THIS_ARTIFACT=YES_NO_INIT_BOOT_IMAGE_INCLUDED
VENDOR_BOOT_PRESERVED_BY_THIS_ARTIFACT=YES_NO_VENDOR_BOOT_IMAGE_INCLUDED
DTBO_PRESERVED_BY_THIS_ARTIFACT=YES_NO_DTBO_IMAGE_INCLUDED
MODEM_AND_MTK_FIRMWARE_PRESERVED_BY_THIS_ARTIFACT=YES_NO_NON_SUPER_FIRMWARE_INCLUDED
```

## Evidence summary

The R1F no-flash composition used the qualified SableOS/AOSP `system.img` and stock V01.00.14 / TEE14 dynamic partitions from:

```text
/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference
```

The composition produced:

```text
TITAN2_N1C_NO_FLASH_HYBRID_SUPER_COMPOSITION=PASS
N1C_HYBRID_SUPER_SOURCE_HASH_SEAL=PASS
N1C_HYBRID_SUPER_PRESERVED_STOCK_PARTITIONS=PASS
N1C_HYBRID_SUPER_SYSTEM_REPLACED_WITH_SABLE_SYSTEMIMAGE=PASS
```

The closeout produced:

```text
N1C_CLOSEOUT_LPUNPACK=PASS
N1C_NO_FLASH_HYBRID_SUPER_CLOSEOUT=PASS
TITAN2_N1C_FLASH_BLOCKED_REVIEW_ARTIFACT=PASS
```

## Verified source map

```text
system_a=/srv/data/sable-build/workspaces/titan2-n1c-android16-hybrid-super-20260930_140947/out_n1c_aosp_arm64_systemimage_apns_source_filter/target/product/generic_arm64/system.img
product_a=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/product.img
system_ext_a=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/system_ext.img
vendor_a=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/vendor.img
system_dlkm_a=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/system_dlkm.img
vendor_dlkm_a=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/vendor_dlkm.img
odm_dlkm_a=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/odm_dlkm.img
```

## Source hashes

```text
ed9edad3c65e4908028bb6087bbb712efff81bd4fe6601cc6cc6f0273b545c5d  system_a
_de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37  product_a
1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170  system_ext_a
cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada  vendor_a
2752d357dc698db0967a3bbc9de2204127eab69fa28f7d3471d3e039e4a2946f  system_dlkm_a
1fc51fb7a2f089b3d9255d00944bda711e64b297daf2ecf687abeae17e0a4936  vendor_dlkm_a
ebe714d1ed41742eeb87fa06674900703af97f90f729420fe37555bd02338723  odm_dlkm_a
```

Note: the leading underscore on the `product_a` hash line is not part of the hash. It is used only to prevent some renderers from treating the line as a link-like token. The actual hash is:

```text
de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37
```

## Known caveat

```text
ABI_DUMP_CHECKS_DISABLED_FOR_SYSTEMIMAGE_PROBE=YES
PRODUCTION_READY_CLAIM=NO
```

The N1C `system.img` build passed with ABI dump/check generation disabled after the Android header ABI dumper failed on `pthread.h`. This is acceptable for the no-flash checkpoint, but must be resolved or explicitly waived before any production-ready claim.

## Flash-blocked status

```text
FLASH_BLOCKED_READINESS_LEDGER=/srv/data/sable-build/evidence/titan2/n1c-no-flash-hybrid-super-closeout-r1b-20260930_185710/N1C_FLASH_BLOCKED_READINESS_LEDGER.md
FLASH_COMMAND_REVIEW_REQUIRED=YES
RESTORE_PATH_VERIFIED_REQUIRED=YES
BOOTLOADER_PREFLIGHT_REQUIRED=YES
FASTBOOTD_PREFLIGHT_REQUIRED=YES
SNAPSHOT_UPDATE_STATUS_NONE_REQUIRED=YES
EXPLICIT_TITAN_SERIAL_REQUIRED=YES
ACTIVE_SLOT_REQUIRED=YES
AVB_ACTION_REQUIRED=YES
USERDATA_POLICY_REQUIRED=preserve|explicit-wipe-approved
```

No write-capable command is authorized by this checkpoint.
