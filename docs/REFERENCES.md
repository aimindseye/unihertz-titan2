# References

## Lichtmetzger Titan 2 rooting / firmware notes

Lichtmetzger, **"Rooting the Unihertz Titan 2 and installing Magisk"**, 2025-10-28:

https://lichtmetzger.de/en/2025/10/28/rooting-the-unihertz-titan-2-and-installing-magisk/

Relevant points used as leads during this research:

- the guide links Titan 2 firmware hosted on Google Drive;
- it extracts `init_boot.img` for Magisk rooting;
- its worked example uses an EEA build;
- it links local OTA packages;
- it describes the standard `fastboot flashing unlock` flow.

The guide was treated as a lead, not as proof of US firmware identity. US behavior was verified directly on the handset.

One device-specific difference observed in this project: the tested US/non-EEA Titan 2 required **Volume Up** to accept the unlock confirmation.

Retrieved/reviewed: 2026-09-22.

## Public Titan 2 Google Drive firmware folder

Public folder supplied during research:

https://drive.google.com/drive/folders/1MnVTW1EI-G86PRBUIDD0QAXuE3lqtnTP

Observed organization:

```text
Titan 2/
├── Android 15/
│   ├── EuropeanUnion_EEA/
│   └── None_EEA/
└── Android 16/
    ├── EuropeanUnion_EEA/
    └── None_EEA/
```

Observed Android 16 full-firmware archives:

```text
EuropeanUnion_EEA/
  2026020617_g71v78c2k_dfl_eea.zip  3693740474 bytes
  2026041315_g71v78c2k_dfl_eea.zip  3743600619 bytes

None_EEA/
  2026021022_g71v78c2k_dfl_tee.zip  3693402149 bytes
  2026042212_g71v78c2k_dfl_tee.zip  3743249119 bytes
```

These names and byte sizes match the corresponding full-firmware archives already preserved in the private firmware corpus.

The public folder's ownership was not independently established from Drive metadata during this research, so this repository does **not** label it "official" solely on that basis.

The tested US handset itself reports fastboot product `g71v78c2k_dfl_tee`, and the project subsequently established cryptographic equivalence between the tested US V01.00.13 -> V01.00.14 OTA lineage and the `None_EEA`/`_tee` full images. See [FIRMWARE_EQUIVALENCE.md](FIRMWARE_EQUIVALENCE.md).

Reviewed: 2026-09-22.

## Camera / physical-keyboard community references

### Titan 2 Elite GCam square-screen work

Reddit thread supplied by the project owner:

https://www.reddit.com/r/unihertz/comments/1vzxax6/gcam_port_for_the_unihertz_titan_2_elite_square/?sort=new

Useful reported lessons for camera-app design include:

- near-square viewport assumptions breaking normal GCam layout;
- missing/overlapping controls and cutout conflicts;
- tap-to-focus coordinate offsets;
- low-resolution preview scaling;
- mode crashes caused by resolution/layout assumptions;
- stabilization behavior that produced motion smearing;
- device-specific color-processing choices.

These are treated as Titan 2 Elite/community observations, not direct Titan 2 evidence.

### Titan 2 Elite Telephoto Fix

https://github.com/Flux-Sniffer-Mods/Titan-2-Elite-Telephoto-Fix

This project documents a stock Titan 2 Elite camera stack where additional cameras are hidden with `SYSTEM_CAMERA`, and uses a Magisk/runtime `cameraserver` patch plus application hooks to make the telephoto usable by a GCam port.

The project is a valuable reverse-engineering reference for:

- system-camera access restrictions;
- logical multi-camera routing;
- active physical-camera switching;
- firmware-specific cameraserver patch fragility;
- separation of app behavior from camera-service/HAL behavior.

Its implementation and sensor capabilities must not be assumed to match Titan 2.

License observed in repository: MIT.

### Commander

https://github.com/astroboii47/Commander

Keyboard-first Android command bar / notification hub.

The project states that most development/testing has been done on Titan 2 and Zinwa Q25. It is useful as a keyboard-first UX reference rather than as an IME implementation.

License observed in repository: MIT.

### q25toolbox

https://github.com/nozerorma/q25toolbox

Useful Q25 reference for physical-key remapping, accessibility-service handling, keylayout/root integration and other device-level input behavior.

A root-level `LICENSE` file was not found during the 2026-09-23 review, so direct code reuse should be treated as license-unresolved until the applicable terms are established.

### Pastiera

https://github.com/palsoftware/pastiera

Physical-keyboard IME explicitly designed for devices such as Titan 2.

Relevant project features include:

- dedicated Titan 2 Alt maps;
- JSON-configurable keyboard layouts;
- modifier/navigation shortcuts;
- device/firmware behavior archives;
- Titan 2 and Titan 2 Elite reference material;
- compact physical-keyboard-first UI.

License observed in repository: GPLv3.

### Unihertz Discord

Community message supplied by the project owner:

https://discord.com/channels/722458117266210887/1376817225629044746/1458129187368992970

The project owner also identified the `kernel-studies` and `rooting-and-custom-stuff` channels as useful research sources.

Discord is used as a discovery/community reference. Claims taken from chat should be reproduced independently or clearly attributed before being promoted to repository findings.

## Titan 2 mainline Linux and recovery references (2026-11-15)

**Status: source-only research reference, not a deployment or build authorization.** These links were inspected on 2026-11-15 for the potential SableOS Native / Marathon compatibility study. Source revisions are fixed below for reproducible review; branch heads may move. The [2026-11-03 SableOS device portfolio stop](https://github.com/sableos-project/platform_sable/blob/main/docs/DEVICE_PORTFOLIO_STATUS_2026-11-03.md) remains in force for Titan 2/Elite ROM and device work. The [2026-11-15 editions decision](https://github.com/sableos-project/platform_sable/blob/main/docs/SABLEOS_EDITIONS_2026-11-15.md) permits **source-only** Titan 2 Native comparison, not a build, flash, runtime campaign, or release.

| Source (immutable snapshot) | Verified scope | Reuse boundary |
| --- | --- | --- |
| [aimindseye/unihertz-titan2](https://github.com/aimindseye/unihertz-titan2/tree/966c04585fb34f916c0d72d4d4aa425b26c6504c) | SableOS historical Titan 2 firmware, input, camera, recovery and acceptance research; this repository is the local reference index. | Historical findings, not evidence of a present working SableOS ROM or authorization to resume its old roadmap. |
| [Serlk/titan2-twrp](https://github.com/Serlk/titan2-twrp/tree/1d1c3ce6958ea9f4eef8194d3aada88a6ae28313) | TWRP 3.7.1 Android-14-based recovery for stock V01.00.14: recovery-ramdisk replacement in device-matched `vendor_boot`, FBE metadata decryption, adb and fastbootd. | Recovery/TEE/boot-layout **reference only**. PIN verification accesses protected TEE storage; wrong labels may break Android unlock. Slot switching is unsupported; installation is invasive. |
| [Serlk/titan2-tools](https://github.com/Serlk/titan2-tools/tree/c60ce4f33a7def74e16cdc2424f82438d3cda6ce) | Linux build tools, Alpine initramfs, GPT/boot-menu tests, modem CCCI userspace, `mtk-ccci` ModemManager plugin, IMS/APN control, `t2-speechd` call audio and host tests. | **Highest-value telephony source.** Its plugin is tied to a specific ModemManager build, needs single-owner AT/MIPC access and is **not** an Android `ImsService` drop-in. Do not run its scripts against a phone as part of a read-only review. |
| [Serlk/titan2-boot](https://github.com/Serlk/titan2-boot/tree/a638b5b545aaf9d2e7673a152bf3394748ca741d) | Second-stage dual-boot menu placed in `boot_a`, after unchanged factory LK; Android/Linux entries, read-only UFS/GPT/ext4 loader, bootloader memory/FDT contracts and QEMU/host tests. | Boot-architecture reference only; modifying `boot_a` and integrating a Linux partition introduce boot/recovery risk. Never infer compatibility with Titan 2 Elite or other firmware. |
| [Serlk/titan2-docs](https://github.com/Serlk/titan2-docs/tree/73b6c0ec7e8858fd6e4f2cab9039d46e24650c95) | [Status](https://github.com/Serlk/titan2-docs/blob/73b6c0ec7e8858fd6e4f2cab9039d46e24650c95/docs/STATUS.md), build, install, dual-boot rollback, LK and hardware reference documents. | Reports developer-tested Linux VoLTE calls in both directions, SMS and LTE data on **one** Titan 2. Not a SableOS acceptance result or an independent US-carrier qualification. |

Related upstream projects discovered through these references, **not additional user-supplied reference targets**: [Serlk/titan2-linux](https://github.com/Serlk/titan2-linux/tree/50a22e5003dd4a71f27f241069064799bf2a6a3c) (Linux 7.2 kernel/device tree, branch `titan2`) and [Serlk/titan2-android](https://github.com/Serlk/titan2-android/tree/dcfc7cf0996b22ef96334eaa6108b2845ce704ae) (crDroid 16 GSI; **its README says VoLTE is not working on Android**). Do not conflate the Linux VoLTE result with Android GSI IMS functionality.

**Source-only SableOS Native relevance:** Marathon already consumes ModemManager voice and SMS APIs. A future comparison may assess its Qt/QML shell and Rust services against Serlk's Titan 2 plugin, while preserving the vendor-specific ModemManager package/version, OpenRC startup ordering, `t2-speechd` audio ownership and Titan 2 keyboard/display device profile. Source compatibility is **not** qualified image compatibility.

**Release and security gaps:** Serlk documents approximately 80 mA suspend current, unverified end-to-end incoming-call wake, untested emergency calls and SIM2 incoming calls, incomplete SIM2 SMS, missing MMS/fingerprint/rear display and unproven stock-Android dual boot. Dual boot involves disabling AVB verification, changing `boot_a`, repartitioning/wiping userdata and protecting sensitive per-device modem calibration/NVRAM copies. Never publish raw IMEI, SIM IDs, calibration partitions or device keys. Respect each project's per-file licence and retain attribution before reusing code.

Reviewed: 2026-11-15. **No build, signing, flash, device operation, or active Titan 2 project status change is implied.**

## Android platform references

These were used to interpret observed platform behavior:

- Android Verified Boot / libavb:  
  https://android.googlesource.com/platform/external/avb/
- Update Engine payload metadata schema:  
  https://android.googlesource.com/platform/system/update_engine/+/refs/heads/main/update_metadata.proto
- Android Dynamic Partitions / Virtual A/B:  
  https://source.android.com/docs/core/ota/virtual_ab
- fastbootd:  
  https://source.android.com/docs/core/architecture/bootloader/fastbootd
- Android system cameras:  
  https://source.android.com/docs/core/camera/system-cameras
- Camera2 API:  
  https://developer.android.com/reference/android/hardware/camera2/package-summary

The device conclusions in this repository are based on direct Titan 2 observations; these references provide terminology and platform context.
