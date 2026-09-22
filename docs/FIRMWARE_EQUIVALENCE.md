# Firmware Equivalence: US vs Non-EEA / `_tee`

**Status:** CLOSED  
**Build pair:** `V01.00.13 -> V01.00.14`

## Why this mattered

The US handset's live FOTA transaction provided only an incremental OTA. Separately sourced Titan 2 firmware archives used filenames ending in `_tee`, and a public Google Drive grouped those files under `None_EEA`.

The question was whether those non-EEA full payloads could be used as exact source/target images for the US handset rather than merely similar regional builds.

## Naming / product evidence

The US retail handset itself reports:

```text
fastboot product: g71v78c2k_dfl_tee
```

The public firmware folder groups the corresponding `*_tee.zip` files under `None_EEA`.

For Android 16 the relevant full packages are:

```text
2026021022_g71v78c2k_dfl_tee.zip
2026042212_g71v78c2k_dfl_tee.zip
```

## Build identity

The full non-EEA V01.00.13 OTA reports:

```text
post-build=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.13:user/release-keys
post-build-incremental=V01.00.13
post-security-patch-level=2025-12-05
```

The US incremental OTA requires exactly:

```text
pre-build=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.13:user/release-keys
```

The full non-EEA V01.00.14 OTA reports:

```text
post-build=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
post-timestamp=1776829107
```

The US incremental OTA targets the same post-build fingerprint and the same post-build timestamp.

The EEA build is distinct and uses:

```text
Unihertz/Titan_2_EEA/Titan_2:...
```

## OTA-managed partition set

All compared V01.00.14 payloads contain the same 34 partition names:

```text
apusys
boot
ccu
connsys_bt
connsys_gnss
connsys_wifi
dpm
dtbo
gpueb
gz
init_boot
lk
logo
mcf_ota
mcupm
modem
odm_dlkm
pi_img
preloader_raw
product
scp
spmfw
sspm
system
system_dlkm
system_ext
tee
vbmeta
vbmeta_system
vbmeta_vendor
vcp
vendor
vendor_boot
vendor_dlkm
```

## Bit-equivalence method

The proof was split into two methods because the installed `payload-dumper-go` cannot reconstruct FEC data for some filesystem partitions.

### 27 partitions: direct delta reconstruction

For 27 partitions:

1. the partition image was extracted from the full non-EEA V01.00.13 payload;
2. that image was supplied as the old/source image to the observed US V01.00.13 -> V01.00.14 delta;
3. the reconstructed target image was compared byte-for-byte with the corresponding image extracted from the full non-EEA V01.00.14 payload.

Every tested image matched exactly.

This includes the boot/AVB-critical set:

```text
boot
init_boot
vendor_boot
dtbo
vbmeta
vbmeta_system
vbmeta_vendor
preloader_raw
lk
tee
```

and the remaining smaller firmware partitions:

```text
apusys
ccu
connsys_bt
connsys_gnss
connsys_wifi
dpm
gpueb
gz
logo
mcf_ota
mcupm
modem
pi_img
scp
spmfw
sspm
vcp
```

### 7 FEC-bearing partitions: payload-manifest hashes

Direct reconstruction stopped on the remaining filesystem/DLKM group because `payload-dumper-go` reported unsupported FEC reconstruction.

Those seven partitions were instead checked against the US delta manifest's whole-partition source and target hashes:

```text
odm_dlkm
product
system
system_dlkm
system_ext
vendor
vendor_dlkm
```

For every partition:

```text
SHA256(non-EEA V01.00.13 image)
    == US delta old_partition_info.hash

SHA256(non-EEA V01.00.14 image)
    == US delta new_partition_info.hash
```

All seven source and target checks matched.

## Conclusion

For **all 34 OTA-managed partitions** in the observed V01.00.13 -> V01.00.14 lineage:

- the non-EEA/`_tee` V01.00.13 full payload provides the exact source partition images expected by the US delta;
- the non-EEA/`_tee` V01.00.14 full payload provides the exact target partition images produced/expected by that US delta.

For bring-up and recovery work on these builds, the non-EEA/`_tee` full payloads are therefore valid full-image representatives of the observed US/global firmware lineage.

## Scope limit

This does **not** prove equivalence for:

- partitions absent from the OTA payload;
- device-unique partitions or calibration data;
- userdata;
- radio/NVRAM state unique to a handset;
- other firmware versions not tested here;
- EEA firmware, which is a distinct build family.

Do not generalize the result beyond the tested builds and OTA-managed partition set.

## Artifact policy

Firmware archives, OTAs, payloads, extracted images, and raw manifests remain on `ai-g732` outside this repository. Only hashes, metadata, methods, and conclusions are recorded here.
