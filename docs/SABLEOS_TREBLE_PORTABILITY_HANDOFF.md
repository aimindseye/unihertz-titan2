# SableOS Treble portability handoff

Status: **Titan 2 research closed for N0_A16 planning**

This handoff converts Titan 2 research into SableOS build-target strategy.

## Decision

```text
DEVICE=titan2
SABLE_RELEASE=R10 planning line
TITAN_RELEASE_ID=N0_A16
ANDROID_RELEASE=16
PLATFORM_SDK=36
ARTIFACT_KIND=gsi-system-image
FIRST_SUBSTRATE=AOSP16_CLEAN_GSI
RESTLESSOS_ROLE=REFERENCE_AND_FUTURE_FORK
FIRST_SABLE_ARTIFACT=ABSENT
FIRST_SABLE_BOOT=NOT_RUN
```

Titan 2 should not chase the latest Pixel Android release before stock vendor,
kernel, VNDK and HAL compatibility are proven. Vendor lag is treated as a
product constraint for Unihertz/MediaTek targets.

## RestlessOS role

RestlessOS is a reference and possible future Sable fork for common Treble work.
It is not the first Titan 2 boot dependency.

```text
FIRST_TITAN2_N0_SUBSTRATE=AOSP16_CLEAN_GSI
RESTLESSOS_COMPARISON_PHASE=AFTER_AOSP16_SYSTEM_IMG_EXISTS
PLANNED_FORK=sableos-project/treble_restlessos
```

Do not use prebuilt RestlessOS images as Sable release artifacts. Do not inherit
GrapheneOS or RestlessOS branding, endorsement, support or security claims.

## Handoff to SableOS repositories

```text
sableos-project/platform_manifest
  owns exact source/artifact composition and release-lane identity

sableos-project/build
  owns build/sign/verify/package/flash command gates

sableos-project/device_sable_titan2
  owns public Titan 2 device-adapter docs and deployment boundaries

aimindseye/sableos
  owns private integration work until provenance/licensing/privacy review

aimindseye/unihertz-titan2
  owns stock-device research evidence and redacted hardware facts
```

## First build sequence

```text
1. qualify AOSP android-16.0.0_r4 / gsi_arm64-userdebug;
2. build Sable-owned system.img from source;
3. record source, manifest, product, output path, size and SHA-256;
4. keep flashing disabled;
5. run E3 artifact preflight;
6. only then decide if first deployment is authorized.
```

## Gate reminders

A successful system image build does not authorize device mutation. Deployment
requires explicit proof of:

```text
RESTORE_PATH_VERIFIED=YES
AVB_STRATEGY_EXPLICIT=YES
LOGICAL_PARTITION_FIT_VALIDATED=YES
USERDATA_WIPE_POLICY_DECIDED=YES
DEVICE_SERIAL_BOUND=YES
FLASH_COMMANDS_REVIEWED=YES
```
