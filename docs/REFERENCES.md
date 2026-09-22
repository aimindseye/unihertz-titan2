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

The device conclusions in this repository are based on direct Titan 2 observations; these references provide terminology and platform context.
