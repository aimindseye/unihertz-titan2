# SableOS N1C first-write postmortem — 2026-09-30

Status: **device recovered / N1C retry blocked**

This document records the first write-capable SableOS N1C Titan 2 test, the recovery path, and the corrective actions before any further Titan 2 write-capable work.

```text
TRACK=N1C_ANDROID16_HYBRID_SUPER
DEVICE=titan2
FIRST_WRITE_SCOPE=super_only
N1C_FIRST_WRITE_RESULT=FLASHED_BUT_BOOT_FAILED
STOCK_SUPER_RESTORE=PASS
TEE14_BOOT_AVB_RESTORE=PASS
FACTORY_RESET=REQUIRED_AND_PERFORMED_FROM_RECOVERY
DEVICE_RECOVERED=YES
N1C_RETRY_AUTHORIZED=NO
FLASH_AUTHORIZED_BY_THIS_DOC=NO
```

## Summary

The N1C hybrid-super image was accepted by fastbootd and written to `super`, but the device did not return to Android/ADB after reboot. The recovery path required:

1. restoring the verified stock V01.00.14 / TEE14 stock `super` image;
2. restoring the matching TEE14 `boot`, `init_boot`, `vendor_boot`, `dtbo`, `vbmeta`, `vbmeta_system`, and `vbmeta_vendor` images for slot `a`;
3. performing a recovery factory reset after Android Recovery reported that Android could not be loaded and data might be corrupt.

After the factory reset, the device recovered to the Unihertz setup screen and booted stock V01.00.14.

## Evidence paths from ai-g732

```text
N1C_WRITE_EVID=/srv/data/sable-build/evidence/titan2/n1c-first-write-super-test-r1-20260930_200458
STOCK_SUPER_ARTIFACT_EVID=/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124
STOCK_SUPER_LIVE_EVID=/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-live-20260930_202932
TEE14_BOOT_AVB_EVID=/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335
STOCK_RECOVERY_AFTER_FACTORY_RESET_EVID=/srv/data/sable-build/evidence/titan2/n1c-stock-recovery-after-factory-reset-20260930_205351
FAILURE_ANALYSIS_LEDGER_EVID=/srv/data/sable-build/evidence/titan2/n1c-first-write-failure-analysis-ledger-r1-20260930_205520
```

## What passed

```text
N1C_SUPER_ARTIFACT_HASH_GATE=PASS
N1C_SUPER_FASTBOOTD_PREFLIGHT=PASS
FLASH_SUPER_N1C=PASS
POST_FLASH_FASTBOOTD_STATE=PASS
FASTBOOT_REBOOT_AFTER_N1C=PASS
STOCK_SUPER_RESTORE_ARTIFACT=PASS
STOCK_SUPER_LIVE_RESTORE=PASS
TEE14_BOOT_AVB_RESTORE=PASS
STOCK_BOOT_AFTER_FACTORY_RESET=PASS
DEVICE_RECOVERED=YES
```

## What failed

```text
N1C_FIRST_BOOT_ADB=FAIL_TIMEOUT
STOCK_RESTORE_WITHOUT_FACTORY_RESET=FAILED_TO_BOOT_TO_ANDROID
RECOVERY_SCREEN=CAN_NOT_LOAD_ANDROID_SYSTEM_DATA_MAY_BE_CORRUPT
FACTORY_RESET_REQUIRED_FOR_STOCK_RECOVERY=YES
```

The current evidence does **not** prove a single root cause. It does prove that retrying the same N1C artifact is unsafe and unproductive.

## Recovered stock state

After recovery and factory reset:

```text
sys.boot_completed=1
ro.product.device=Titan_2
ro.product.model=Titan 2
ro.product.manufacturer=Unihertz
ro.build.fingerprint=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
ro.vendor.build.fingerprint=Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.14:user/release-keys
ro.boot.slot_suffix=_a
ro.boot.dynamic_partitions=true
ro.virtual_ab.enabled=true
ro.treble.enabled=true
ro.boot.verifiedbootstate=orange
ro.boot.flash.locked=0
ro.build.version.release=16
ro.build.version.incremental=V01.00.14
```

## Process failures

The bring-up process had avoidable defects:

```text
SCRIPT_ERROR_HARDCODED_LPUNPACK_PATH=YES
SCRIPT_ERROR_STDOUT_POLLUTION_IN_COMMAND_SUBSTITUTION=YES
SCRIPT_ERROR_REPEATED_HELPER_CAPTURE_BUGS=YES
SCRIPT_ERROR_MANUAL_MODE_ASSUMPTIONS=YES
SCRIPT_QUALITY_BELOW_REQUIRED_BAR=YES
RESTLESSOS_BOOT_SUCCESS_NOT_USED_AS_STRONG_ENOUGH_CONTROL_CASE=YES
TOO_MUCH_FIX_FORWARD=YES
```

The most important process error was continuing to build confidence around a clean AOSP `aosp_arm64` hybrid-super path without first proving, by offline diff, why the known-booting RestlessOS/GSI path worked on Titan 2.

## Stop rule

```text
RETRY_SAME_N1C_ARTIFACT=NO
FLASH_NEW_N1C_ARTIFACT=NO_UNTIL_OFFLINE_ROOT_CAUSE_ANALYSIS
USERDATA_PRESERVE_ASSUMPTION_FOR_NEXT_FIRST_BOOT=INVALIDATED
FACTORY_RESET_REQUIREMENT_FOR_ANY_FUTURE_N1C_TEST=REVIEW_REQUIRED
PRODUCTION_READY_CLAIM=NO
CELLULAR_CLAIM=NO
HARDWARE_PARITY_CLAIM=NO
```

## Corrective actions before N1D

```text
NO_AD_HOC_DEVICE_SCRIPT_WITHOUT_REVIEW_PACKET=YES
NO_SET_EUO_PIPEFAIL_IN_DEVICE_OR_RECOVERY_SCRIPTS=YES
NO_STDOUT_LOGGING_FROM_FUNCTIONS_USED_IN_COMMAND_SUBSTITUTION=YES
NO_HARDCODED_HOST_TOOL_WITHOUT_RESOLVER_FALLBACK=YES
NO_WRITE_CAPABLE_SCRIPT_WITHOUT_VERIFIED_RESTORE_PATH=YES
NO_RETRY_WITHOUT_KNOWN_BOOTING_GSI_DIFF=YES
```

## Required offline analysis

```text
COMPARE_RESTLESSOS_BOOTABLE_GSI_TO_N1C_SYSTEM=REQUIRED
COMPARE_LINEAGE23_OR_OTHER_TITAN2_GSI_GUIDANCE=REQUIRED
CHECK_INIT_AND_FIRST_STAGE_MOUNT_PATHS=REQUIRED
CHECK_FSTAB_AND_METADATA_ENCRYPTION_FLAGS=REQUIRED
CHECK_DYNAMIC_PARTITION_LAYOUT_AND_LP_METADATA=REQUIRED
CHECK_SYSTEM_PROPERTIES_IDENTITY_AND_API_LEVELS=REQUIRED
CHECK_VINTF_COMPATIBILITY=REQUIRED
CHECK_SEPOLICY_AND_TREBLE_PHRASES=REQUIRED
CHECK_DATA_FORMAT_AND_ENCRYPTION_EXPECTATIONS=REQUIRED
CHECK_AVB_CHAIN_IMPLICATIONS=REQUIRED
```

## Option C status

Option C, the hybrid-super strategy, is **not rejected** by this failure. It still solved the structural problem of preserving stock `product`, `system_ext`, `vendor`, and DLKMs while replacing `system_a`.

However, Option C is no longer allowed to proceed as “clean AOSP system in a hybrid super.” It must be re-evaluated against the known-booting RestlessOS/GSI path and Titan 2 community references before another flash attempt.

```text
OPTION_C_STATUS=OPEN_BUT_BLOCKED_PENDING_OFFLINE_DIFF
RESTLESSOS_GSI_BASELINE=REQUIRED_CONTROL_CASE
NEXT_FLASH_AUTHORIZED=NO
```