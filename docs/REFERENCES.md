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
