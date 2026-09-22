# T2-R2 Bootloader and AVB

**Status:** CLOSED  
**Tested stock build:** V01.00.13  
**Reference AVB comparison:** V01.00.13 vs V01.00.14

## Bootloader fastboot

The US retail device reports:

```text
product:            g71v78c2k_dfl_tee
current-slot:       a
slot-count:         2
unlocked:           no        # before unlock
secure:             yes       # before unlock
is-userspace:       no        # bootloader fastboot
version-bootloader: g71v78c2k_dfl_tee_d3bd746_202602101339
unlock_ability:     true
```

The `anti` variable was present but blank.

## Unlock behavior

The normal Android command works:

```bash
fastboot flashing unlock
```

However, the Titan 2 confirmation UI is unusually easy to miss:

- the fastboot/unlock text is rendered extremely small on the display;
- the prompt automatically rejects the unlock after roughly five seconds if no key is pressed;
- the host-side `fastboot flashing unlock` command can still return `OKAY` after that rejection;
- therefore `OKAY` does **not** prove the bootloader was unlocked;
- on the tested US/non-EEA handset, **Volume Up** during the short confirmation window accepted the unlock.

Always verify the result explicitly:

```bash
fastboot getvar unlocked
fastboot getvar secure
```

Successful result:

```text
unlocked: yes
secure: no
```

After the factory reset and stock reboot:

```text
ro.boot.verifiedbootstate  = orange
ro.boot.flash.locked       = 0
ro.boot.vbmeta.device_state = unlocked
```

Relocking has not been tested and should not be attempted until a fully stock, internally consistent firmware state is restored and verified.

## Temporary boot is unsupported

The bootloader accepts the download stage of `fastboot boot` but does not implement the boot command:

```text
Sending 'boot.img' ... OKAY
Booting ... FAILED (remote: 'unknown command')
```

This test did not write a partition.

Practical consequence: Titan 2 bring-up must use a controlled **flash -> boot -> recover** workflow rather than a RAM-only `fastboot boot` loop.

## Controlled boot-critical write

After unlocking, the exact stock V01.00.13 `init_boot.img` was flashed back to the active `init_boot_a` partition:

```text
partition size: 0x800000
image size:     8388608 bytes
image SHA-256:  aa2d07bfb03b87401cedef7c318c59cb286b02eb47a1309ee0f2561a6141b223
send:           OK
write:          OK
post-flash boot: OK
```

The phone returned to V01.00.13 with the expected orange/unlocked AVB state.

This proves boot-critical partition write access through the unlocked bootloader.

## Boot image layout

Verified stock V01.00.14 images show:

```text
boot:
  Android boot header v4
  kernel present
  ramdisk size 0

init_boot:
  Android boot header v4
  kernel size 0
  generic ramdisk present

vendor_boot:
  vendor boot header v4
  DTB present
  vendor ramdisk fragment 0: type 0x1
  vendor ramdisk fragment 1: type 0x2, name "recovery"
```

No standalone recovery partition/image was observed in the 34-partition OTA payload. The evidence supports recovery being carried as the recovery vendor-ramdisk fragment in `vendor_boot`.

## AVB topology

The V01.00.14 top-level `vbmeta` image uses:

```text
algorithm: SHA256_RSA2048
rollback index: 0
flags: 0
release string: avbtool 1.3.0
```

Top-level chain descriptors:

```text
vbmeta
├── boot
│   rollback index location 3
│   key SHA-1 9d808b0995768d0677fccb1efcddb7cf9e153d99
├── vbmeta_system
│   rollback index location 2
│   key SHA-1 fa41159a5d696abdef93176a07d0b0d001263f01
└── vbmeta_vendor
    rollback index location 4
    key SHA-1 9577bc6c0772975ecce93c4d8a178662c728dadf
```

Top-level `vbmeta` directly carries hash descriptors for:

```text
dtbo
init_boot
vendor_boot
```

and dm-verity hashtree descriptors for:

```text
odm_dlkm
product
system_dlkm
system_ext
vendor_dlkm
```

`vbmeta_system` carries the hashtree descriptor for `system`.

`vbmeta_vendor` carries the hashtree descriptor for `vendor`.

## Root signing-key rotation

The top-level `vbmeta` public key changed across the tested update:

```text
V01.00.13 root vbmeta key SHA-1:
cdbb77177f731920bbe0a0f94f84d9038ae0617d

V01.00.14 root vbmeta key SHA-1:
aef4d92dd0750a9bbc37757435773c9087ed3d66
```

The compared chain descriptors for `boot`, `vbmeta_system`, and `vbmeta_vendor` did not change.

The partition digests/root digests changed as expected with the update. Rollback indices observed in the inspected vbmeta images were zero.

Do not assume a single immutable top-level Unihertz AVB key across firmware releases.

## AVB property-string quirk

The V01.00.14 top-level vbmeta includes some informational `com.android.build.*` properties whose embedded fingerprints still reference V01.00.13 and/or Android 14-era vendor components.

Examples include `dtbo`, `init_boot`, `vendor_boot`, `product`, and `system_ext` property strings.

The signed hash/hashtree descriptors are the relevant integrity data. The mixed/stale property strings are recorded as a build-system metadata quirk and should not be used alone to identify partition contents.
